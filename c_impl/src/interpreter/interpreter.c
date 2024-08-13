#include "interpreter.h"
#include "bytecode.h"
#include <stdio.h>
#include "../util/unreachable.h"
#include <assert.h>
#include "../program/program.h"
#include "value_tag.h"
#include <string.h>
#include "../primitives/script_value.h"
#include "../primitives/primitives_context.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"
#include "../primitives/set/set.h"
#include "../primitives/map/map.h"
#include "../primitives/option/option.h"
#include "../primitives/error/error.h"
#include "../primitives/result/result.h"
#include "../util/math.h"

extern const CubsTypeContext* cubs_primitive_context_for_tag(CubsValueTag tag);
extern void _cubs_internal_program_runtime_error(const CubsProgram* self, CubsProgramRuntimeError err, const char* message, size_t messageLength);

static bool ptr_is_aligned(const void* p, size_t alignment) {
    return (((uintptr_t)p) % alignment) == 0;
}

static const size_t OLD_INSTRUCTION_POINTER = 0;
static const size_t OLD_FRAME_LENGTH = 1;
static const size_t OLD_RETURN_VALUE_DST = 2;
static const size_t OLD_RETURN_CONTEXT_DST = 3;
static const size_t RESERVED_SLOTS = 4;

typedef struct InterpreterStackState {
    const Bytecode* instructionPointer;
    /// Offset from `stack` and `tags` indicated where the next frame should start
    size_t nextBaseOffset;
    InterpreterStackFrame frame;
    size_t stack[CUBS_STACK_SLOTS];
    uintptr_t contexts[CUBS_STACK_SLOTS];
} InterpreterStackState;

static _Thread_local InterpreterStackState threadLocalStack = {0};

void cubs_interpreter_push_frame(size_t frameLength, const struct Bytecode* oldInstructionPointer, void* returnValueDst, const CubsTypeContext** returnContextDst) {
    assert(frameLength <= MAX_FRAME_LENGTH);
    { // store previous instruction pointer, frame length, return dst, and return tag dst
        size_t* basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.nextBaseOffset];
        if(threadLocalStack.nextBaseOffset == 0) {
            basePointer[OLD_INSTRUCTION_POINTER]    = 0;
            basePointer[OLD_FRAME_LENGTH]           = 0;
            basePointer[OLD_RETURN_VALUE_DST]       = 0;
            basePointer[OLD_RETURN_CONTEXT_DST]     = 0;
        } else {
            basePointer[OLD_INSTRUCTION_POINTER]    = (size_t)((const void*)oldInstructionPointer); // cast ptr to size_t
            basePointer[OLD_FRAME_LENGTH]           = threadLocalStack.frame.frameLength;
            basePointer[OLD_RETURN_VALUE_DST]       = (size_t)threadLocalStack.frame.returnValueDst;
            basePointer[OLD_RETURN_CONTEXT_DST]     = (size_t)threadLocalStack.frame.returnContextDst;
        }
    }

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = frameLength,
        .returnValueDst = returnValueDst,
        .returnContextDst = returnContextDst
    };
    threadLocalStack.frame = newFrame;
    threadLocalStack.nextBaseOffset += frameLength + RESERVED_SLOTS;  
}

void cubs_interpreter_pop_frame()
{
    assert(threadLocalStack.nextBaseOffset != 0 && "No more frames to pop!");

    const size_t offset = threadLocalStack.frame.frameLength + RESERVED_SLOTS;

    threadLocalStack.nextBaseOffset -= offset;
    if(threadLocalStack.nextBaseOffset == 0) {
        return;
    }

    size_t* const basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.frame.basePointerOffset];
    const size_t oldInstructionPointer = basePointer[OLD_INSTRUCTION_POINTER];
    const size_t oldFrameLength = basePointer[OLD_FRAME_LENGTH];
    void* const oldReturnValueDst = (void*)basePointer[OLD_RETURN_VALUE_DST];
    const CubsTypeContext** const oldReturnTagDst = (const CubsTypeContext**)basePointer[OLD_RETURN_CONTEXT_DST];

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = oldFrameLength,
        .returnValueDst = oldReturnValueDst,
        .returnContextDst = oldReturnTagDst
    };   
    threadLocalStack.frame = newFrame;
}

InterpreterStackFrame cubs_interpreter_current_stack_frame()
{
    return threadLocalStack.frame;
}

void *cubs_interpreter_stack_value_at(size_t offset)
{
    assert(offset < threadLocalStack.frame.frameLength);
    return (void*)(&threadLocalStack.stack[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS]);
}

const CubsTypeContext* cubs_interpreter_stack_context_at(size_t offset)
{
    assert(offset < threadLocalStack.frame.frameLength);
    uintptr_t contextPtr = threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS];
    // Mask away the ref tag bit
    const CubsTypeContext* context = (const CubsTypeContext*)(contextPtr & ~(1ULL));
    return context;
}

static bool is_owning_context_at(size_t offset) {
    assert(offset < threadLocalStack.frame.frameLength);
    uintptr_t contextPtr = threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS];

    return (contextPtr & 1ULL) == 0;
}

static void stack_set_context_at(size_t offset, const CubsTypeContext* context, bool isReference) {
    _Static_assert(_Alignof(CubsTypeContext) > 1, "Bottom bit needs to be free for internal use");
    assert(ptr_is_aligned(context, _Alignof(CubsTypeContext)));
    assert(offset < threadLocalStack.frame.frameLength);
    assert((offset + context->sizeOfType) < ((threadLocalStack.frame.frameLength + 1) * sizeof(size_t)));

    uintptr_t contextPtr = (uintptr_t)context;
    uintptr_t refTag = (uintptr_t)isReference;
    
    threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS] = contextPtr | refTag;
    if(context->sizeOfType > 8) {
        for(size_t i = 1; i < (context->sizeOfType / 8); i++) {
            threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset  + RESERVED_SLOTS + i] = 0; // (uintptr_t)NULL
        }
    }
}

void cubs_interpreter_stack_unwind_frame() {
    uintptr_t* start = &threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + RESERVED_SLOTS];
    for(size_t i = 0; i < threadLocalStack.frame.frameLength; i++) {
        const CubsTypeContext* context = cubs_interpreter_stack_context_at(i);
        const bool isOwningContext = is_owning_context_at(i);
        if(context == NULL || !isOwningContext) {
            continue;
        }
        if(context->destructor == NULL) {
            continue;
        }
        context->destructor(cubs_interpreter_stack_value_at(i));
        // While technically it makes the most sense to set to NULL earlier, since nothing gets executed if the type has no destructor,
        // leaving a previous context for a "dumb" type, such as an integer, is fine.
        cubs_interpreter_stack_set_null_context_at(i); // set context to NULL
    }
}

void cubs_interpreter_stack_set_context_at(size_t offset, const CubsTypeContext* context)
{
    stack_set_context_at(offset, context, false);
}

void cubs_interpreter_stack_set_reference_context_at(size_t offset, const CubsTypeContext *context)
{
    stack_set_context_at(offset, context, true);
}

void cubs_interpreter_stack_set_null_context_at(size_t offset)
{
    threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS] = 0;
}

void cubs_interpreter_set_instruction_pointer(const Bytecode *newIp)
{
    assert(newIp != NULL);
    threadLocalStack.instructionPointer = newIp;
}

static void execute_load(size_t* ipIncrement, const Bytecode* bytecode) {
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

            const uint64_t immediate = threadLocalStack.instructionPointer[1].value;
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
                    const CubsTypeContext* context = (const CubsTypeContext*)threadLocalStack.instructionPointer[1].value;
                    *(CubsArray*)dst = cubs_array_init(context);
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_ARRAY_CONTEXT);
                    (*ipIncrement) += 1; // move instruction pointer further into the bytecode
                } break;
                case cubsValueTagSet: {
                    const CubsTypeContext* context = (const CubsTypeContext*)threadLocalStack.instructionPointer[1].value;
                    *(CubsSet*)dst = cubs_set_init(context);
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_SET_CONTEXT);
                    (*ipIncrement) += 1; // move instruction pointer further into the bytecode
                } break;
                case cubsValueTagMap: {
                    const CubsTypeContext* keyContext = (const CubsTypeContext*)threadLocalStack.instructionPointer[1].value;
                    const CubsTypeContext* valueContext = (const CubsTypeContext*)threadLocalStack.instructionPointer[2].value;
                    *(CubsMap*)dst = cubs_map_init(keyContext, valueContext);
                    cubs_interpreter_stack_set_context_at(operands.dst, &CUBS_MAP_CONTEXT);
                    (*ipIncrement) += 2; // move instruction pointer further into the bytecode
                } break;
                case cubsValueTagOption: {
                    const CubsTypeContext* context = (const CubsTypeContext*)threadLocalStack.instructionPointer[1].value;
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
                case cubsValueTagVec2i: {
                    cubs_panic("TODO vec2i");
                    // const CubsVec2i zeroVec = {0};
                    // *(CubsVec2i*)dst = zeroVec;
                    // _Static_assert(sizeof(CubsVec2i) == (2 * sizeof(size_t)), "");
                    // // Must make sure the slots that the array uses are unused
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec3i: {
                    cubs_panic("TODO vec3i");
                    // const CubsVec3i zeroVec = {0};
                    // *(CubsVec3i*)dst = zeroVec;
                    // _Static_assert(sizeof(CubsVec3i) == (3 * sizeof(size_t)), "");
                    // // Must make sure the slots that the array uses are unused
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec4i: {
                    cubs_panic("TODO vec4i");
                    // const CubsVec4i zeroVec = {0};
                    // *(CubsVec4i*)dst = zeroVec;
                    // _Static_assert(sizeof(CubsVec4i) == (4 * sizeof(size_t)), "");
                    // // Must make sure the slots that the array uses are unused
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 4, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec2f: {
                    cubs_panic("TODO vec2f");
                    // const CubsVec2f zeroVec = {0};
                    // *(CubsVec2f*)dst = zeroVec;
                    // _Static_assert(sizeof(CubsVec2f) == (2 * sizeof(size_t)), "");
                    // // Must make sure the slots that the array uses are unused
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec3f: {
                    cubs_panic("TODO vec3f");
                    // const CubsVec3f zeroVec = {0};
                    // *(CubsVec3f*)dst = zeroVec;
                    // _Static_assert(sizeof(CubsVec3f) == (3 * sizeof(size_t)), "");
                    // // Must make sure the slots that the array uses are unused
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec4f: {
                    cubs_panic("TODO vec4f");
                    // const CubsVec4f zeroVec = {0};
                    // *(CubsVec4f*)dst = zeroVec;
                    // _Static_assert(sizeof(CubsVec4f) == (4 * sizeof(size_t)), "");
                    // // Must make sure the slots that the array uses are unused
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                    // cubs_interpreter_stack_set_tag_at(operands.dst + 4, _CUBS_VALUE_TAG_NONE);
                } break;
                default: {
                    cubs_panic("unimplemented default initialization for type");
                } break;
            }
        } break;
        case LOAD_TYPE_CLONE_FROM_PTR: {
            const OperandsLoadCloneFromPtr operands = *(const OperandsLoadCloneFromPtr*)bytecode;

            const void* immediate = (const void*)(uintptr_t)threadLocalStack.instructionPointer[1].value;
            const CubsTypeContext* context = (const CubsTypeContext*)threadLocalStack.instructionPointer[2].value;

            assert(immediate != NULL);
            assert(context != NULL);

            void* dst = cubs_interpreter_stack_value_at(operands.dst);

            assert(context->clone != NULL);
            context->clone(dst, immediate);

            cubs_interpreter_stack_set_context_at(operands.dst, context);      
            (*ipIncrement) += 2; // move instruction pointer further into the bytecode
        } break;
        default: {
            unreachable();
        } break;
    }
}

static CubsProgramRuntimeError execute_add(const CubsProgram *program, const Bytecode* bytecode) {
    const OperandsAddUnknown unknownOperands = *(const OperandsAddUnknown*)bytecode;
    const CubsTypeContext* context = cubs_interpreter_stack_context_at(unknownOperands.src1);
    assert(cubs_interpreter_stack_context_at(unknownOperands.src2) == context);

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
                const int len = sprintf(errBuf, "Integer overflow detected -> %ld + %ld\n", a, b);
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
            const OperandsAddDst dstOperands = *(const OperandsAddDst*)bytecode;
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
            const OperandsAddDst dstOperands = *(const OperandsAddDst*)bytecode;
            *(double*)(cubs_interpreter_stack_value_at(dstOperands.dst)) = result;
            cubs_interpreter_stack_set_context_at(dstOperands.dst, &CUBS_FLOAT_CONTEXT);
        } else if(unknownOperands.opType == MATH_TYPE_SRC_ASSIGN) {
            *(double*)src1 = result;
        }
    } else {
        unreachable();
    }
    return cubsProgramRuntimeErrorNone;
}

CubsProgramRuntimeError cubs_interpreter_execute_operation(const CubsProgram *program)
{
    size_t ipIncrement = 1;
    const Bytecode bytecode = *threadLocalStack.instructionPointer;
    const OpCode opcode = cubs_bytecode_get_opcode(bytecode);

    CubsProgramRuntimeError potentialErr = cubsProgramRuntimeErrorNone;
    switch(opcode) {
        case OpCodeNop: {
            fprintf(stderr, "nop :)\n");
        } break;
        case OpCodeLoad: {
            execute_load(&ipIncrement, &bytecode);
        } break;
        case OpCodeAdd: {
            potentialErr = execute_add(program, &bytecode);
        } break;
        default: {
            unreachable();
        } break;
    }
    threadLocalStack.instructionPointer = &threadLocalStack.instructionPointer[ipIncrement];
    return potentialErr;
}