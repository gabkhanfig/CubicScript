#include "interpreter.h"
#include "bytecode.h"
#include "operations.h"
#include "stack.h"
#include <stdio.h>
#include "../util/unreachable.h"
#include <assert.h>
#include "../program/program.h"
#include "value_tag.h"
#include <string.h>
#include "../primitives/context.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"
#include "../primitives/set/set.h"
#include "../primitives/map/map.h"
#include "../primitives/option/option.h"
#include "../primitives/error/error.h"
#include "../primitives/result/result.h"
#include "../primitives/reference/reference.h"
#include "../primitives/sync_ptr/sync_ptr.h"
#include "../util/math.h"
#include "function_definition.h"
#include "../program/function_call_args.h"
#include "../util/context_size_round.h"
#include "../sync/sync_queue.h"
#include "../program/program_internal.h"

static void execute_load(int64_t* const ipIncrement, const Bytecode* bytecode) {
    const OperandsLoadUnknown unknownOperands = *(const OperandsLoadUnknown*)bytecode;

    switch(unknownOperands.loadType) {
        case LOAD_TYPE_IMMEDIATE: {
            const OperandsLoadImmediate operands = *(const OperandsLoadImmediate*)bytecode;

            switch(operands.immediateType) {
                case LOAD_IMMEDIATE_BOOL: {
                    *((bool*)cubs_interpreter_stack_value_at(operands.dst)) = operands.immediate != 0;
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_BOOL_CONTEXT);
                } break;
                case LOAD_IMMEDIATE_INT: {
                    *((int64_t*)cubs_interpreter_stack_value_at(operands.dst)) = (int64_t)operands.immediate;
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_INT_CONTEXT);
                } break;
                default: {
                    unreachable();
                } break;
            }
        } break;
        case LOAD_TYPE_IMMEDIATE_LONG: {
            const OperandsLoadImmediateLong operands = *(const OperandsLoadImmediateLong*)bytecode;
            assert(operands.immediateValueTag != _CUBS_VALUE_TAG_NONE);
            assert(operands.immediateValueTag != cubsValueTagBool && "Don't use 64 bit immediate load for booleans");

            const uint64_t immediate = bytecode[1].value;
            *((uint64_t*)cubs_interpreter_stack_value_at(operands.dst)) = immediate; // will reinterpret cast
            cubs_interpreter_stack_set_context_at(operands.dst, cubs_primitive_context_for_tag(operands.immediateValueTag));      
            (*ipIncrement) += 1; // move instruction pointer further into the bytecode
        } break;
        case LOAD_TYPE_DEFAULT: {
            const OperandsLoadDefault operands = *(const OperandsLoadDefault*)bytecode;
            assert(operands.tag != _CUBS_VALUE_TAG_NONE);
            
            void* dst = cubs_interpreter_stack_value_at(operands.dst);

            switch(operands.tag) {
                case cubsValueTagBool: {
                    *(bool*)dst = false;
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_BOOL_CONTEXT);
                } break;
                case cubsValueTagInt: {
                    *(int64_t*)dst = 0;
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_INT_CONTEXT);
                } break;
                case cubsValueTagFloat: {
                    *(double*)dst = 0;
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_FLOAT_CONTEXT);
                } break;
                case cubsValueTagChar: {
                    cubs_panic("TODO char");
                } break;
                case cubsValueTagString: {
                    const CubsString defaultString = {0};
                    *(CubsString*)dst = defaultString;
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_STRING_CONTEXT);
                } break;
                case cubsValueTagArray: {
                    const CubsTypeContext* context = (const CubsTypeContext*)bytecode[1].value;
                    *(CubsArray*)dst = cubs_array_init(context);
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_ARRAY_CONTEXT);
                    (*ipIncrement) += 1; // move instruction pointer further into the bytecode
                } break;
                case cubsValueTagSet: {
                    const CubsTypeContext* context = (const CubsTypeContext*)bytecode[1].value;
                    *(CubsSet*)dst = cubs_set_init(context);
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_SET_CONTEXT);
                    (*ipIncrement) += 1; // move instruction pointer further into the bytecode
                } break;
                case cubsValueTagMap: {
                    const CubsTypeContext* keyContext = (const CubsTypeContext*)bytecode[1].value;
                    const CubsTypeContext* valueContext = (const CubsTypeContext*)bytecode[2].value;
                    *(CubsMap*)dst = cubs_map_init(keyContext, valueContext);
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_MAP_CONTEXT);
                    (*ipIncrement) += 2; // move instruction pointer further into the bytecode
                } break;
                case cubsValueTagOption: {
                    const CubsTypeContext* context = (const CubsTypeContext*)bytecode[1].value;
                    *(CubsOption*)dst = cubs_option_init(context, NULL);
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_SET_CONTEXT);
                    (*ipIncrement) += 1; // move instruction pointer further into the bytecode
                } break;
                case cubsValueTagError: {
                    cubs_panic("Errors do not have a default value");
                } break;
                case cubsValueTagResult: {
                    cubs_panic("Results do not have a default value");
                } break;
                default: {
                    cubs_panic("unimplemented default initialization for type");
                } break;
            }
        } break;
        case LOAD_TYPE_CLONE_FROM_PTR: {
            const OperandsLoadCloneFromPtr operands = *(const OperandsLoadCloneFromPtr*)bytecode;

            const void* immediate = (const void*)(uintptr_t)bytecode[1].value;
            const CubsTypeContext* context = (const CubsTypeContext*)bytecode[2].value;

            assert(immediate != NULL);
            assert(context != NULL);

            void* dst = cubs_interpreter_stack_value_at(operands.dst);

            assert(context->clone.func.externC != NULL);
            cubs_context_fast_clone(dst, immediate, context);

            cubs_interpreter_stack_set_context_at(operands.dst, context);      
            (*ipIncrement) += 2; // move instruction pointer further into the bytecode
        } break;
        default: {
            unreachable();
        } break;
    }
}

static void execute_return(int64_t* const ipIncrement, const Bytecode bytecode) {
    const OperandsReturn operands = *(const OperandsReturn*)&bytecode;

    if(operands.hasReturn) {
        const CubsFunctionReturn ret = cubs_interpreter_return_dst();
        assert(ret.value != NULL);
        assert(ret.context != NULL);

        void* src = cubs_interpreter_stack_value_at(operands.returnSrc);
        const CubsTypeContext* context = cubs_interpreter_stack_context_at(operands.returnSrc);
        cubs_interpreter_stack_set_null_context_at(operands.returnSrc);

        memcpy(ret.value, src, context->sizeOfType);
        *ret.context = context;
    }

    cubs_interpreter_stack_unwind_frame();
    cubs_interpreter_pop_frame();
}

static void execute_call(int64_t* const ipIncrement, const Bytecode* bytecode) {
    const OperandsCallUnknown operands = *(const OperandsCallUnknown*)&bytecode[0];
    const enum CallType opType = (enum CallType)operands.opType;
    const unsigned int argCount = (unsigned int)operands.argCount;
    void* returnSrc;

    const uint16_t* argsSrcs = NULL;
    CubsFunction func = {0};

    switch(opType) { 
        case CALL_TYPE_IMMEDIATE: {
            const OperandsCallImmediate immediateOperands = *(const OperandsCallImmediate*)&bytecode[0];
            const CubsFunction _func = {
                .func = {.externC = (CubsCFunctionPtr)bytecode[1].value},
                .funcType = (CubsFunctionType)immediateOperands.funcType,
            };
            func = _func;
            argsSrcs = (const uint16_t*)&bytecode[2];

            // See operands.c cubs_operands_make_call_immediate
            /// Initial bytecode + immediate function
            size_t requiredBytecode = 1 + 1;
            if((argCount % 4) == 0) {
                requiredBytecode += (argCount / 4);
            } else {
                requiredBytecode += (argCount / 4) + 1;
            }
            *ipIncrement = requiredBytecode;
        } break;
        case CALL_TYPE_SRC: {
            const OperandsCallSrc srcOperands = *(const OperandsCallSrc*)&bytecode[0];
            assert(cubs_interpreter_stack_context_at(srcOperands.funcSrc) == &CUBS_FUNCTION_CONTEXT);
            func = *(const CubsFunction*)cubs_interpreter_stack_value_at(srcOperands.funcSrc);
            argsSrcs = (const uint16_t*)&bytecode[1];
         
            // See operands.c cubs_operands_make_call_src
            /// Initial bytecode
            size_t requiredBytecode = 1;
            if((argCount % 4) == 0) {
                requiredBytecode += (argCount / 4);
            } else {
                requiredBytecode += (argCount / 4) + 1;
            }
            *ipIncrement = requiredBytecode;
        } break;
    }

    CubsFunctionCallArgs funcArgs = cubs_function_start_call(&func);
    for(unsigned int i = 0; i < argCount; i++) {
        const uint16_t argSrc = argsSrcs[i];
        assert(cubs_interpreter_stack_context_at(argSrc) != NULL);
        cubs_function_push_arg(&funcArgs, cubs_interpreter_stack_value_at(argSrc), cubs_interpreter_stack_context_at(argSrc));
    }

    if(operands.hasReturn) {
        void* retValue = cubs_interpreter_stack_value_at(operands.returnDst);
        const CubsTypeContext** retContext = cubs_interpreter_stack_context_ptr_at(operands.returnDst);
        const CubsFunctionReturn ret = {.value = retValue, .context = retContext};
        cubs_function_call(funcArgs, ret);
    } else {
        const CubsFunctionReturn nullRet = {0};
        cubs_function_call(funcArgs, nullRet);
    }
}

static void execute_jump(int64_t* const ipIncrement, const Bytecode bytecode) {
    const OperandsJump operands = *(const OperandsJump*)&bytecode;
    const int32_t jumpAmount = (int32_t)operands.jumpAmount;
    const enum JumpType jumpType = operands.opType;
    switch(jumpType) {
        case JUMP_TYPE_DEFAULT: {
            *ipIncrement = jumpAmount;
        } break;
        case JUMP_TYPE_IF_TRUE: {
            assert(cubs_interpreter_stack_context_at(operands.optSrc) == &CUBS_BOOL_CONTEXT);
            const bool value = *(const bool*)cubs_interpreter_stack_value_at(operands.optSrc);
            if(value) {
                *ipIncrement = jumpAmount;
            }
        } break;
        case JUMP_TYPE_IF_FALSE: {
            assert(cubs_interpreter_stack_context_at(operands.optSrc) == &CUBS_BOOL_CONTEXT);
            const bool value = *(const bool*)cubs_interpreter_stack_value_at(operands.optSrc);
            if(!value) {
                *ipIncrement = jumpAmount;
            }
        } break;
    }
}

static void execute_deinit(const Bytecode bytecode) {
    const OperandsDeinit operands = *(const OperandsDeinit*)&bytecode;
    const CubsTypeContext* context = cubs_interpreter_stack_context_at(operands.src);
    assert(context != NULL);
    // TODO should this be done at all?
    // It's a waste of processing power to do this, as if there is no destructor, the deinit operation shouldn't be used at all
    if(context->destructor.func.externC == NULL) {
        return;
    }
    cubs_context_fast_deinit(cubs_interpreter_stack_value_at(operands.src), context);
    cubs_interpreter_stack_set_null_context_at(operands.src);
}

static void sync_value_at(OperandsSyncLockSource src) {
    const CubsTypeContext* context = cubs_interpreter_stack_context_at(src.src);
    const enum SyncLockType lockType = (enum SyncLockType)src.lock;
    void* value = cubs_interpreter_stack_value_at(src.src);
    if(context == &CUBS_UNIQUE_CONTEXT) {
        if(src.lock == SYNC_LOCK_TYPE_READ) {
            cubs_sync_queue_unique_add_shared((const struct CubsUnique*)value);
        } else {
            cubs_sync_queue_unique_add_exclusive((struct CubsUnique*)value);
        }
    } else if(context == &CUBS_SHARED_CONTEXT) {
        if(src.lock == SYNC_LOCK_TYPE_READ) {
            cubs_sync_queue_shared_add_shared((const struct CubsShared*)value);
        } else {
            cubs_sync_queue_shared_add_exclusive((struct CubsShared*)value);
        }
    } else if(context == &CUBS_WEAK_CONTEXT) {
        if(src.lock == SYNC_LOCK_TYPE_READ) {
            cubs_sync_queue_weak_add_shared((const struct CubsWeak*)value);
        } else {
            cubs_sync_queue_weak_add_exclusive((struct CubsWeak*)value);
        }
    } else {
        cubs_panic("Cannot sync non-sync type");
    }
}

static void execute_sync(int64_t* const ipIncrement, const Bytecode* bytecode) {
    const OperandsSync operands = *(const OperandsSync*)&bytecode[0];
    const enum SyncType syncType = (enum SyncType)operands.opType;
    if(syncType == SYNC_TYPE_UNSYNC) {
        cubs_sync_queue_unlock();
    } else {
        // first is guaranteed to get sync'd
        sync_value_at(operands.src1);
    
        if(operands.num > 1) {
            sync_value_at(operands.src2);

            const OperandsSyncLockSource* sources = (const OperandsSyncLockSource*)&bytecode[1];

            const size_t extended = operands.num - 2;
            for(uint16_t i = 0; i < extended; i++) {
                sync_value_at(sources[i]);
            }

            if(extended > 0) { // increment
                /// Initial bytecode
                int64_t requiredBytecode = 1;
                if((extended % 4) == 0) {
                    requiredBytecode += (extended / 4);
                } else {
                    requiredBytecode += (extended / 4) + 1;
                }
                *ipIncrement = requiredBytecode;
            }
        }

        cubs_sync_queue_lock();
    }
}

static void execute_move(const Bytecode bytecode) {
    const OperandsMove operands = *(const OperandsMove*)&bytecode;

    const CubsTypeContext* context = cubs_interpreter_stack_context_at(operands.src);
    const void* src = cubs_interpreter_stack_value_at(operands.src);
    void* dst = cubs_interpreter_stack_value_at(operands.dst);
    memcpy(dst, src, context->sizeOfType);
    cubs_interpreter_stack_set_context_at(operands.dst, context);
    cubs_interpreter_stack_set_null_context_at(operands.src); // invalidate original location
}

static void execute_clone(const Bytecode bytecode) {
    const OperandsClone operands = *(const OperandsClone*)&bytecode;

    const CubsTypeContext* context = cubs_interpreter_stack_context_at(operands.src);
    assert(context->clone.func.externC != NULL);
    const void* src = cubs_interpreter_stack_value_at(operands.src);
    void* dst = cubs_interpreter_stack_value_at(operands.dst);
    cubs_context_fast_clone(dst, src, context);
    cubs_interpreter_stack_set_context_at(operands.dst, context);
}

static bool is_reference_type_context(const CubsTypeContext* context) {
    return context == &CUBS_CONST_REF_CONTEXT 
    || context == &CUBS_MUT_REF_CONTEXT
    || context == &CUBS_UNIQUE_CONTEXT
    || context == &CUBS_SHARED_CONTEXT
    || context == &CUBS_WEAK_CONTEXT;
}

static void execute_dereference(const Bytecode bytecode) {
    const OperandsDereference operands = *(const OperandsDereference*)&bytecode;

    const CubsTypeContext* refContext = cubs_interpreter_stack_context_at(operands.src);
    assert(is_reference_type_context(refContext) && "Expected reference type for dereference operation");

    const void* refSrc = cubs_interpreter_stack_value_at(operands.src);
    const CubsTypeContext* actualTypeContext = NULL;
    const void* actualSrc = NULL;
    if(refContext == &CUBS_CONST_REF_CONTEXT) {
        actualTypeContext = ((const CubsConstRef*)refSrc)->context;
        actualSrc = ((const CubsConstRef*)refSrc)->ref;
    }
    else if(refContext == &CUBS_MUT_REF_CONTEXT) {
        actualTypeContext = ((const CubsMutRef*)refSrc)->context;
        actualSrc = ((const CubsMutRef*)refSrc)->ref;
    }
    else if(refContext == &CUBS_UNIQUE_CONTEXT) {
        actualTypeContext = ((const CubsUnique*)refSrc)->context;
        actualSrc = cubs_unique_get((const CubsUnique*)refSrc);
    }
    else if(refContext == &CUBS_SHARED_CONTEXT) {
        actualTypeContext = ((const CubsShared*)refSrc)->context;
        actualSrc = cubs_shared_get((const CubsShared*)refSrc);
    }
    else if(refContext == &CUBS_WEAK_CONTEXT) {
        actualTypeContext = ((const CubsWeak*)refSrc)->context;
        actualSrc = cubs_weak_get((const CubsWeak*)refSrc);
    } else {
        unreachable();
    }

    cubs_interpreter_stack_set_reference_context_at(operands.dst, actualTypeContext);
    memcpy(cubs_interpreter_stack_value_at(operands.dst), actualSrc, actualTypeContext->sizeOfType);
}

static void execute_set_reference(const Bytecode bytecode) {
    const OperandsSetReference operands = *(const OperandsSetReference*)&bytecode;

    const CubsTypeContext* refContext = cubs_interpreter_stack_context_at(operands.dst);
    const CubsTypeContext* srcContext = cubs_interpreter_stack_context_at(operands.src);
    assert(is_reference_type_context(refContext) && "Expected reference type for dereference operation");

    void* refDst = cubs_interpreter_stack_value_at(operands.dst);
    void* actualDst = NULL;
    if(refContext == &CUBS_CONST_REF_CONTEXT) {
        assert(false && "Cannot set the value of a const reference");
        // assert(refContext == ((const CubsConstRef*)refDst)->context);
        // actualDst = ((const CubsConstRef*)refDst)->ref;
    }
    else if(refContext == &CUBS_MUT_REF_CONTEXT) {
        if(srcContext !=  ((const CubsMutRef*)refDst)->context) {
            fprintf(stderr, "%s, %s\n", refContext->name, ((const CubsMutRef*)refDst)->context->name);
        }
        assert(srcContext == ((const CubsMutRef*)refDst)->context);
        actualDst = ((CubsMutRef*)refDst)->ref;
    }
    else if(refContext == &CUBS_UNIQUE_CONTEXT) {
        assert(srcContext == ((const CubsUnique*)refDst)->context);
        actualDst = cubs_unique_get_mut((CubsUnique*)refDst);
    }
    else if(refContext == &CUBS_SHARED_CONTEXT) {
        assert(srcContext == ((const CubsShared*)refDst)->context);
        actualDst = cubs_shared_get_mut((CubsShared*)refDst);
    }
    else if(refContext == &CUBS_WEAK_CONTEXT) {
        assert(srcContext == ((const CubsWeak*)refDst)->context);
        actualDst = cubs_weak_get_mut((CubsWeak*)refDst);
    } else {
        unreachable();
    }

    memcpy(actualDst, cubs_interpreter_stack_value_at(operands.src), srcContext->sizeOfType);
}

static void execute_make_reference(const Bytecode bytecode) {
    const OperandsMakeReference operands = *(const OperandsMakeReference*)&bytecode;

    const CubsTypeContext* refContext = cubs_interpreter_stack_context_at(operands.src);

    void* src = cubs_interpreter_stack_value_at(operands.src);
    void* dst = cubs_interpreter_stack_value_at(operands.dst);

    if(operands.mutable) {
        CubsMutRef ref = {.ref = src, .context = refContext};
        *(CubsMutRef*)dst = ref;
        cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_MUT_REF_CONTEXT);
    } else {
        CubsConstRef ref = {.ref = src, .context = refContext};
        *(CubsConstRef*)dst = ref;
        cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_CONST_REF_CONTEXT);    
    }
}

static void execute_get_member(const Bytecode bytecode) {
    const OperandsGetMember operands = *(const OperandsGetMember*)&bytecode;

    const void* srcValue = NULL;
    const CubsTypeContext* srcContext = NULL;

    { // automatically dereference if necessary
        const CubsTypeContext* tempSrcContext = cubs_interpreter_stack_context_at(operands.src);
        const void* tempSrcValue = cubs_interpreter_stack_value_at(operands.src);
        if(!is_reference_type_context(tempSrcContext)) {
            srcValue = tempSrcValue;
            srcContext = tempSrcContext;
        } else {
            if(tempSrcContext == &CUBS_CONST_REF_CONTEXT) {
                srcContext = ((const CubsConstRef*)tempSrcValue)->context;
                srcValue = ((const CubsConstRef*)tempSrcValue)->ref;
            }
            else if(tempSrcContext == &CUBS_MUT_REF_CONTEXT) {
                srcContext = ((const CubsMutRef*)tempSrcValue)->context;
                srcValue = ((const CubsMutRef*)tempSrcValue)->ref;
            }
            else if(tempSrcContext == &CUBS_UNIQUE_CONTEXT) {
                srcContext = ((const CubsUnique*)tempSrcValue)->context;
                srcValue = cubs_unique_get((const CubsUnique*)tempSrcValue);
            }
            else if(tempSrcContext == &CUBS_SHARED_CONTEXT) {
                srcContext = ((const CubsShared*)tempSrcValue)->context;
                srcValue = cubs_shared_get((const CubsShared*)tempSrcValue);
            }
            else if(tempSrcContext == &CUBS_WEAK_CONTEXT) {
                srcContext = ((const CubsWeak*)tempSrcValue)->context;
                srcValue = cubs_weak_get((const CubsWeak*)tempSrcValue);
            } else {
                unreachable();
            }
        }
    }

    assert(srcContext->membersLen > operands.memberIndex);
    const size_t memberByteOffset = srcContext->members[operands.memberIndex].byteOffset;
    const CubsTypeContext* memberContext = srcContext->members[operands.memberIndex].context;
    
    const void* memberSrc = (const void*)&(((const uint8_t*)srcValue)[memberByteOffset]);

    void* dst = cubs_interpreter_stack_value_at(operands.dst);
    cubs_interpreter_stack_set_reference_context_at(operands.dst, memberContext);
    memcpy(dst, memberSrc, memberContext->sizeOfType);
}

static void execute_set_member(const Bytecode bytecode) {
    const OperandsSetMember operands = *(const OperandsSetMember*)&bytecode;

    const void* dstValue = NULL;
    const CubsTypeContext* dstContext = NULL;

    { // handle both reference and value types
        const CubsTypeContext* tempDstContext = cubs_interpreter_stack_context_at(operands.dst);
        const void* tempDstValue = cubs_interpreter_stack_value_at(operands.dst);
        if(!is_reference_type_context(tempDstContext)) {
            dstValue = tempDstValue;
            dstContext = tempDstContext;
        } else {
            if(tempDstContext == &CUBS_CONST_REF_CONTEXT) {
                dstContext = ((const CubsConstRef*)tempDstValue)->context;
                dstValue = ((const CubsConstRef*)tempDstValue)->ref;
            }
            else if(tempDstContext == &CUBS_MUT_REF_CONTEXT) {
                dstContext = ((const CubsMutRef*)tempDstValue)->context;
                dstValue = ((const CubsMutRef*)tempDstValue)->ref;
            }
            else if(tempDstContext == &CUBS_UNIQUE_CONTEXT) {
                dstContext = ((const CubsUnique*)tempDstValue)->context;
                dstValue = cubs_unique_get((const CubsUnique*)tempDstValue);
            }
            else if(tempDstContext == &CUBS_SHARED_CONTEXT) {
                dstContext = ((const CubsShared*)tempDstValue)->context;
                dstValue = cubs_shared_get((const CubsShared*)tempDstValue);
            }
            else if(tempDstContext == &CUBS_WEAK_CONTEXT) {
                dstContext = ((const CubsWeak*)tempDstValue)->context;
                dstValue = cubs_weak_get((const CubsWeak*)tempDstValue);
            } else {
                unreachable();
            }
        }
    }

    assert(dstContext->membersLen > operands.memberIndex);
    const size_t memberByteOffset = dstContext->members[operands.memberIndex].byteOffset;
    const CubsTypeContext* memberContext = dstContext->members[operands.memberIndex].context;
    
    const void* memberDst = (const void*)&(((const uint8_t*)dstValue)[memberByteOffset]);

    const void* src = cubs_interpreter_stack_value_at(operands.src);
    assert(memberContext == cubs_interpreter_stack_context_at(operands.src));
    memcpy(memberDst, src, memberContext->sizeOfType);
}

static void execute_equal(const Bytecode bytecode) {
    const OperandsEqual operands = *(const OperandsEqual*)&bytecode;
    const CubsTypeContext* context = cubs_interpreter_stack_context_at(operands.src1);
    assert(context == cubs_interpreter_stack_context_at(operands.src2));

    const void* src1 = cubs_interpreter_stack_value_at(operands.src1);
    const void* src2 = cubs_interpreter_stack_value_at(operands.src2);
    void* dst = cubs_interpreter_stack_value_at(operands.dst);

    const bool eq = cubs_context_fast_eql(src1, src2, context);

    *(bool*)dst = eq; // normal
    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_BOOL_CONTEXT);
}

static void execute_not_equal(const Bytecode bytecode) {
    const OperandsNotEqual operands = *(const OperandsNotEqual*)&bytecode;
    const CubsTypeContext* context = cubs_interpreter_stack_context_at(operands.src1);
    assert(context == cubs_interpreter_stack_context_at(operands.src2));

    const void* src1 = cubs_interpreter_stack_value_at(operands.src1);
    const void* src2 = cubs_interpreter_stack_value_at(operands.src2);
    void* dst = cubs_interpreter_stack_value_at(operands.dst);

    const bool eq = cubs_context_fast_eql(src1, src2, context);

    *(bool*)dst = !eq; // not
    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_BOOL_CONTEXT);
}

static CubsProgramRuntimeError execute_increment(const CubsProgram* program, const Bytecode bytecode) {
    const OperandsIncrementUnknown unknownOperands = *(const OperandsIncrementUnknown*)&bytecode;
    const CubsTypeContext* context = cubs_interpreter_stack_context_at(unknownOperands.src);

    void* src = cubs_interpreter_stack_value_at(unknownOperands.src);

    if(context == &CUBS_INT_CONTEXT) {
        const int64_t a = *(const int64_t*)src;
        int64_t result;
        if(!unknownOperands.canOverflow) {
            const bool wouldOverflow = cubs_math_would_add_overflow(a, 1);
            if(wouldOverflow) {
                assert(program != NULL);
                char errBuf[256];
                #if defined(_WIN32) || defined(WIN32)
                const int len = sprintf_s(errBuf, 256, "Increment integer overflow detected -> %lld + 1\n", a);
                #else
                const int len = sprintf(errBuf, "increment integer overflow detected -> %lld + 1\n", a);
                #endif
                assert(len >= 0);           
                _cubs_internal_program_runtime_error(program, cubsProgramRuntimeErrorIncrementIntegerOverflow, errBuf, len);             
                return cubsProgramRuntimeErrorIncrementIntegerOverflow;
            }
            result = a + 1;
        } else { // is allowed to overflow
            cubs_panic("overflow-abled increment not yet implemented");
        }              
        if(unknownOperands.opType == MATH_TYPE_DST) {
            const OperandsAddDst dstOperands = *(const OperandsAddDst*)&bytecode;
            *(int64_t*)(cubs_interpreter_stack_value_at(dstOperands.dst)) = result;
            cubs_interpreter_stack_set_context_at(dstOperands.dst, &CUBS_INT_CONTEXT);
        } else if(unknownOperands.opType == MATH_TYPE_SRC_ASSIGN) {
            *(int64_t*)src = result;
        }
    } else {
        unreachable();
    }
    return cubsProgramRuntimeErrorNone;
}

static CubsProgramRuntimeError execute_add(const CubsProgram *program, const Bytecode bytecode) {
    const OperandsAddUnknown unknownOperands = *(const OperandsAddUnknown*)&bytecode;
    const CubsTypeContext* context = cubs_interpreter_stack_context_at(unknownOperands.src1);
    #ifdef _DEBUG
    if(cubs_interpreter_stack_context_at(unknownOperands.src2) != context) {
        fprintf(stderr, "Mistmatched contexts found...\n\t%s\n\t%s\n", context->name, cubs_interpreter_stack_context_at(unknownOperands.src2)->name);
        fflush(stderr);
        cubs_panic("Mismatched contexts");
    }
    #endif

    void* src1 = cubs_interpreter_stack_value_at(unknownOperands.src1);
    const void* src2 = cubs_interpreter_stack_value_at(unknownOperands.src2);

    if(context == &CUBS_INT_CONTEXT) {
        const int64_t a = *(const int64_t*)src1;
        const int64_t b = *(const int64_t*)src2;
        int64_t result;
        if(!unknownOperands.canOverflow) {
            const bool wouldOverflow = cubs_math_would_add_overflow(a, b);
            if(wouldOverflow) {
                assert(program != NULL);
                char errBuf[256];
                #if defined(_WIN32) || defined(WIN32)
                const int len = sprintf_s(errBuf, 256, "Integer overflow detected -> %lld + %lld\n", a, b);
                #else
                const int len = sprintf(errBuf, "Integer overflow detected -> %lld + %lld\n", a, b);
                #endif
                assert(len >= 0);           
                _cubs_internal_program_runtime_error(program, cubsProgramRuntimeErrorAdditionIntegerOverflow, errBuf, len);             
                return cubsProgramRuntimeErrorAdditionIntegerOverflow;
            }
            result = a + b;
        } else { // is allowed to overflow
            cubs_panic("overflow-abled addition not yet implemented");
        }
        if(unknownOperands.opType == MATH_TYPE_DST) {
            const OperandsAddDst dstOperands = *(const OperandsAddDst*)&bytecode;
            *(int64_t*)(cubs_interpreter_stack_value_at(dstOperands.dst)) = result;
            cubs_interpreter_stack_set_context_at(dstOperands.dst, &CUBS_INT_CONTEXT);
        } else if(unknownOperands.opType == MATH_TYPE_SRC_ASSIGN) {
            *(int64_t*)src1 = result;
        }
    } else if (context == &CUBS_FLOAT_CONTEXT) {
        const double a = *(const double*)src1;
        const double b = *(const double*)src2;
        double result = a + b;
        if(unknownOperands.opType == MATH_TYPE_DST) {
            const OperandsAddDst dstOperands = *(const OperandsAddDst*)&bytecode;
            *(double*)(cubs_interpreter_stack_value_at(dstOperands.dst)) = result;
            cubs_interpreter_stack_set_context_at(dstOperands.dst, &CUBS_FLOAT_CONTEXT);
        } else if(unknownOperands.opType == MATH_TYPE_SRC_ASSIGN) {
            *(double*)src1 = result;
        }
    } else if(context == &CUBS_STRING_CONTEXT) {
        const CubsString result = cubs_string_concat((const CubsString*)src1, (const CubsString*)src2);
        if(unknownOperands.opType == MATH_TYPE_DST) {
            const OperandsAddDst dstOperands = *(const OperandsAddDst*)&bytecode;
            *(CubsString*)(cubs_interpreter_stack_value_at(dstOperands.dst)) = result;
            cubs_interpreter_stack_set_context_at(dstOperands.dst, &CUBS_STRING_CONTEXT);
        } else if(unknownOperands.opType == MATH_TYPE_SRC_ASSIGN) {
            cubs_string_deinit((CubsString*)src1); // deinitialize the string first, freeing any used resources
            *(CubsString*)src1 = result;
        }
    } else {
        unreachable();
    }
    return cubsProgramRuntimeErrorNone;
}

CubsProgramRuntimeError cubs_interpreter_execute_operation(const CubsProgram *program)
{
    int64_t ipIncrement = 1;
    const Bytecode* instructionPointer = cubs_interpreter_get_instruction_pointer();
    const OpCode opcode = cubs_bytecode_get_opcode(*instructionPointer);

    CubsProgramRuntimeError potentialErr = cubsProgramRuntimeErrorNone;
    switch(opcode) {
        case OpCodeNop: {
            fprintf(stderr, "nop :)\n");
        } break;
        case OpCodeLoad: {
            execute_load(&ipIncrement, instructionPointer);
        } break;
        case OpCodeReturn: {
            execute_return(&ipIncrement, *instructionPointer);
        } break;
        case OpCodeCall: {
            execute_call(&ipIncrement, instructionPointer);
        } break;
        case OpCodeJump: {
            execute_jump(&ipIncrement, *instructionPointer);
        } break;
        case OpCodeDeinit: {
            execute_deinit(*instructionPointer);
        } break;
        case OpCodeSync: {
            execute_sync(&ipIncrement, instructionPointer);
        } break;
        case OpCodeMove: {
            execute_move(*instructionPointer);
        } break;
        case OpCodeClone: {
            execute_clone(*instructionPointer);
        } break;
        case OpCodeDereference: {
            execute_dereference(*instructionPointer);
        } break;
        case OpCodeSetReference: {
            execute_set_reference(*instructionPointer);
        } break;
        case OpCodeMakeReference: {
            execute_make_reference(*instructionPointer);
        } break;
        case OpCodeGetMember: {
            execute_get_member(*instructionPointer);
        } break;
        case OpCodeSetMember: {
            execute_set_member(*instructionPointer);
        } break;
        case OpCodeEqual: {
            execute_equal(*instructionPointer);
        } break;
        case OpCodeNotEqual: {
            execute_not_equal(*instructionPointer);
        } break;
        case OpCodeIncrement: {
            potentialErr = execute_increment(program, *instructionPointer);
        } break;
        case OpCodeAdd: {
            potentialErr = execute_add(program, *instructionPointer);
        } break;
        default: {
            unreachable();
        } break;
    }
    cubs_interpreter_set_instruction_pointer(&instructionPointer[ipIncrement]);
    return potentialErr;
}

static CubsProgramRuntimeError interpreter_execute_continuous(const CubsProgram *program) {
    while(true) {
        const Bytecode bytecode = *cubs_interpreter_get_instruction_pointer();
        const OpCode opcode = cubs_bytecode_get_opcode(bytecode);
        const bool isReturn = opcode == OpCodeReturn;

        const CubsProgramRuntimeError err = cubs_interpreter_execute_operation(program);
        if(err != cubsProgramRuntimeErrorNone || isReturn) {
            return err;
        }
    }
}

CubsProgramRuntimeError cubs_interpreter_execute_function(const CubsScriptFunctionPtr *function, void *outReturnValue, const CubsTypeContext **outContext)
{
    cubs_interpreter_push_frame(function->_stackSpaceRequired, outReturnValue, outContext);
    cubs_interpreter_set_instruction_pointer(cubs_function_bytecode_start(function));

    const CubsProgramRuntimeError err = interpreter_execute_continuous(function->program);
    if(err != cubsProgramRuntimeErrorNone) {
        /// If some error occurred, the stack frame won't automatically unwind in a return operation
        cubs_interpreter_stack_unwind_frame();
        cubs_interpreter_pop_frame();
    }

    return err;
}
