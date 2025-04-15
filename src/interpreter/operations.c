#include "operations.h"

#define BYTECODE_ALIGN _Alignas(_Alignof(Bytecode))

Bytecode operands_make_load_immediate(int immediateType, uint16_t dst, int64_t immediate)
{
    assert(dst <= MAX_FRAME_LENGTH);
    BYTECODE_ALIGN const OperandsLoadImmediate operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_IMMEDIATE, .immediateType = immediateType, .dst = dst, .immediate = immediate};
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

void operands_make_load_immediate_long(Bytecode* doubleBytecode, CubsValueTag tag, uint16_t dst, size_t immediate)
{
    assert(dst <= MAX_FRAME_LENGTH);
    BYTECODE_ALIGN const OperandsLoadImmediateLong operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_IMMEDIATE_LONG, .immediateValueTag = tag, .dst = dst};
    doubleBytecode[0] = *(const Bytecode*)&operands;
    doubleBytecode[1].value = (size_t)immediate;
}

void operands_make_load_default(Bytecode* multiBytecode, CubsValueTag tag, uint16_t dst, const CubsTypeContext* optKeyContext, const CubsTypeContext* optValueContext)
{
    assert(dst <= MAX_FRAME_LENGTH);
    BYTECODE_ALIGN const OperandsLoadDefault operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_DEFAULT, .dst = dst, .tag = tag};
    multiBytecode[0] = *(const Bytecode*)&operands;
    if(optKeyContext != NULL) {
        multiBytecode[1] = *(const Bytecode*)optKeyContext;
    }
    if(optValueContext != NULL) {
        assert(optKeyContext != NULL && "If value context isn't NULL, the key context mustn't be NULL for hashmaps");
        multiBytecode[2] = *(const Bytecode*)optValueContext;
    }
}

void operands_make_load_clone_from_ptr(Bytecode *tripleBytecode, uint16_t dst, const void *immediatePtr, const CubsTypeContext *context)
{
    assert(dst <= MAX_FRAME_LENGTH);
    BYTECODE_ALIGN const OperandsLoadCloneFromPtr operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_CLONE_FROM_PTR, .dst = dst};
    tripleBytecode[0] = *(const Bytecode*)&operands;
    tripleBytecode[1].value = (size_t)immediatePtr;
    tripleBytecode[2].value = (size_t)context;
}

Bytecode operands_make_return(bool hasReturn, uint16_t returnSrc)
{
    BYTECODE_ALIGN const OperandsReturn ret = {.reserveOpcode = OpCodeReturn, .hasReturn = hasReturn, .returnSrc = returnSrc};
    return *(const Bytecode*)&ret;
}

#include <stdio.h>

size_t cubs_operands_make_call_immediate(Bytecode *bytecodeArr, size_t availableBytecode, uint16_t argCount, const uint16_t *args, bool hasReturn, uint16_t returnSrc, CubsFunction func)
{
    /// Initial bytecode + immediate function
    size_t requiredBytecode = 1 + 1;
    { // validation
        if(hasReturn) {
            assert(returnSrc <= MAX_FRAME_LENGTH);
        }
        for(uint16_t i = 0; i < argCount; i++) {
            assert(args[i] <= MAX_FRAME_LENGTH);
        }

        
        if((argCount % 4) == 0) {
            requiredBytecode += (argCount / 4);
        } else {
            requiredBytecode += (argCount / 4) + 1;
        }
        assert(availableBytecode >= requiredBytecode);
    }

    BYTECODE_ALIGN const OperandsCallImmediate operands = {
        .reserveOpcode = OpCodeCall, 
        .opType = CALL_TYPE_IMMEDIATE, 
        .argCount = argCount,
        .hasReturn = hasReturn,
        .returnDst = returnSrc,
        .funcType = (uint64_t)func.funcType,
    };

    bytecodeArr[0] = *(const Bytecode*)&operands;
    bytecodeArr[1].value = (uint64_t)func.func.externC;
    uint16_t* bytecodeArgs = (uint16_t*)&bytecodeArr[2];
    for(uint16_t i = 0; i < argCount; i++) {
        bytecodeArgs[i] = args[i];
    }

    return requiredBytecode;
}

size_t cubs_operands_make_call_src(Bytecode *bytecodeArr, size_t availableBytecode, uint16_t argCount, const uint16_t *args, bool hasReturn, uint16_t returnSrc, uint16_t funcSrc)
{  
    /// Initial bytecode
    size_t requiredBytecode = 1;
    { // validation
        assert(funcSrc <= MAX_FRAME_LENGTH);
        if(hasReturn) {
            assert(returnSrc <= MAX_FRAME_LENGTH);
        }
        for(uint16_t i = 0; i < argCount; i++) {
            assert(args[i] <= MAX_FRAME_LENGTH);
        }

        if((argCount % 4) == 0) {
            requiredBytecode += (argCount / 4);
        } else {
            requiredBytecode += (argCount / 4) + 1;
        }
        assert(availableBytecode >= requiredBytecode);
    }

    BYTECODE_ALIGN const OperandsCallSrc operands = {
        .reserveOpcode = OpCodeCall, 
        .opType = CALL_TYPE_IMMEDIATE, 
        .argCount = argCount,
        .hasReturn = hasReturn,
        .returnDst = returnSrc,
        .funcSrc = funcSrc,
    };

    bytecodeArr[0] = *(const Bytecode*)&operands;
    uint16_t* bytecodeArgs = (uint16_t*)&bytecodeArr[1];
    for(uint16_t i = 0; i < argCount; i++) {
        bytecodeArgs[i] = args[i];
    }

    return requiredBytecode;
}

Bytecode cubs_operands_make_jump(enum JumpType jumpType, int32_t jumpAmount, uint16_t jumpSrc)
{
    assert(jumpSrc <= MAX_FRAME_LENGTH);
    BYTECODE_ALIGN const OperandsJump operands = {
        .reserveOpcode = OpCodeJump, .opType = jumpType, .optSrc = jumpSrc, .jumpAmount = jumpAmount};
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

size_t cubs_operands_sync_bytecode_required(uint16_t numSources) {
    /// Initial bytecode
    if(numSources > 2) {
        size_t requiredBytecode = 1;
        const size_t extendedRequired = numSources - 2; // 2 sources are stored inline the bytecode
        if((extendedRequired % 4) == 0) {
            requiredBytecode += (extendedRequired / 4);
        } else {
            requiredBytecode += (extendedRequired / 4) + 1;
        }
        return requiredBytecode;
    } else {
        return 1;
    }
}

size_t cubs_operands_make_sync(Bytecode *bytecodeArr, size_t availableBytecode, enum SyncType syncType, uint16_t num, const SyncLockSource *sources)
{
    assert(availableBytecode >= 1);
    if(syncType == SYNC_TYPE_UNSYNC) {
        BYTECODE_ALIGN const OperandsSync operands = {.reserveOpcode = OpCodeSync, .opType = SYNC_TYPE_UNSYNC};
        const Bytecode b = *(const Bytecode*)&operands;
        bytecodeArr[0] = b;
        return 1;
    } else {
        size_t usedBytecode = cubs_operands_sync_bytecode_required(num);

        { // validation
            assert(num != 0);
            for(uint16_t i = 0; i < num; i++) {
                assert(sources[i].src <= MAX_FRAME_LENGTH);
            }
            assert(availableBytecode >= usedBytecode);
        }

        if(num == 1) {
            const OperandsSyncLockSource src1 = {.src = sources[0].src, .lock = (uint16_t)sources[0].lock};
            BYTECODE_ALIGN const OperandsSync operands = {
                .reserveOpcode = OpCodeSync, 
                .opType = SYNC_TYPE_SYNC,
                .num = num,
                .src1 = src1,
                .src2 = {0}
            };
            const Bytecode b = *(const Bytecode*)&operands;
            bytecodeArr[0] = b;
        } else {
            const OperandsSyncLockSource src1 = {.src = sources[0].src, .lock = (uint16_t)sources[0].lock};
            const OperandsSyncLockSource src2 = {.src = sources[1].src, .lock = (uint16_t)sources[1].lock};
            BYTECODE_ALIGN const OperandsSync operands = {
                .reserveOpcode = OpCodeSync, 
                .opType = SYNC_TYPE_SYNC,
                .num = num,
                .src1 = src1,
                .src2 = src2
            };
            const Bytecode b = *(const Bytecode*)&operands;
            bytecodeArr[0] = b;
            if(num > 2) {
                const size_t ignoreFirstTwo = num - 2;
                OperandsSyncLockSource* bytecodeSyncSources = (OperandsSyncLockSource*)&bytecodeArr[1];
                for(uint16_t i = 0; i < ignoreFirstTwo; i++) {
                    const OperandsSyncLockSource src = {.src = sources[2 + i].src, .lock = (uint16_t)sources[2 + i].lock};
                    bytecodeSyncSources[i] = src;
                }
            }
        }

        return usedBytecode;
    }
}

Bytecode cubs_operands_make_deinit(uint16_t src)
{
    assert(src <= MAX_FRAME_LENGTH);
    BYTECODE_ALIGN const OperandsDeinit operands = {.reserveOpcode = OpCodeDeinit, .src = src};
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode cubs_operands_make_move(uint16_t dst, uint16_t src)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);
    assert(dst != src);
    BYTECODE_ALIGN const OperandsMove operands = {.reserveOpcode = OpCodeMove, .dst = dst, .src = src};
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode cubs_operands_make_clone(uint16_t dst, uint16_t src)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);
    assert(dst != src);
    BYTECODE_ALIGN const OperandsClone operands = {.reserveOpcode = OpCodeClone, .dst = dst, .src = src};
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode cubs_operands_make_compare(enum CompareOperationType compareType, uint16_t dst, uint16_t src1, uint16_t src2)
{    
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src1 <= MAX_FRAME_LENGTH);
    assert(src2 <= MAX_FRAME_LENGTH);
    Bytecode b;
    switch(compareType) {
        case COMPARE_OP_EQUAL: {
            BYTECODE_ALIGN const OperandsEqual operands = {.reserveOpcode = OpCodeEqual, .dst = dst, .src1 = src1, .src2 = src2};
            b = *(const Bytecode*)&operands;
        } break;
        case COMPARE_OP_NOT_EQUAL: {
            BYTECODE_ALIGN const OperandsNotEqual operands = {.reserveOpcode = OpCodeNotEqual, .dst = dst, .src1 = src1, .src2 = src2};
            b = *(const Bytecode*)&operands;
        } break;
        case COMPARE_OP_LESS: {
            BYTECODE_ALIGN const OperandsLess operands = {.reserveOpcode = OpCodeLess, .dst = dst, .src1 = src1, .src2 = src2};
            b = *(const Bytecode*)&operands;
        } break;
        case COMPARE_OP_LESS_OR_EQUAL: {
            BYTECODE_ALIGN const OperandsLessOrEqual operands = {.reserveOpcode = OpCodeLessOrEqual, .dst = dst, .src1 = src1, .src2 = src2};
            b = *(const Bytecode*)&operands;
        } break;
        case COMPARE_OP_GREATER: {
            BYTECODE_ALIGN const OperandsGreater operands = {.reserveOpcode = OpCodeGreater, .dst = dst, .src1 = src1, .src2 = src2};
            b = *(const Bytecode*)&operands;
        } break;
        case COMPARE_OP_GREATER_OR_EQUAL: {
            BYTECODE_ALIGN const OperandsGreaterOrEqual operands = {.reserveOpcode = OpCodeGreaterOrEqual, .dst = dst, .src1 = src1, .src2 = src2};
            b = *(const Bytecode*)&operands;
        } break;
        default: {
            unreachable();
        };
    }
    return b;
}

Bytecode cubs_operands_make_dereference(uint16_t dst, uint16_t src)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);

    BYTECODE_ALIGN const OperandsDereference operands = {
        .reserveOpcode = OpCodeDereference, .dst = dst, .src = src
    };
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode cubs_operands_make_set_reference(uint16_t dst, uint16_t src)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);

    BYTECODE_ALIGN const OperandsDereference operands = {
        .reserveOpcode = OpCodeSetReference, .dst = dst, .src = src
    };
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode cubs_operands_make_reference(uint16_t dst, uint16_t src, bool mutable)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);

    BYTECODE_ALIGN const OperandsMakeReference operands = {
        .reserveOpcode = OpCodeMakeReference, .dst = dst, .src = src, .mutable = mutable
    };
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode cubs_operands_make_get_member(uint16_t dst, uint16_t src, uint16_t memberIndex)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);

    BYTECODE_ALIGN const OperandsGetMember operands = {
        .reserveOpcode = OpCodeGetMember, .dst = dst, .src = src, .memberIndex = memberIndex
    };
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode cubs_operands_make_set_member(uint16_t dst, uint16_t src, uint16_t memberIndex)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);

    BYTECODE_ALIGN const OperandsSetMember operands = {
        .reserveOpcode = OpCodeSetMember, .dst = dst, .src = src, .memberIndex = memberIndex
    };
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode operands_make_increment_dst(bool canOverflow, uint16_t dst, uint16_t src)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);

    BYTECODE_ALIGN const OperandsIncrementDst operands = {.reserveOpcode = OpCodeAdd, .opType = MATH_TYPE_DST, .canOverflow = canOverflow, .dst = dst, .src = src};    
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode operands_make_increment_assign(bool canOverflow, uint16_t src)
{
    assert(src <= MAX_FRAME_LENGTH);    
    
    BYTECODE_ALIGN const OperandsIncrementAssign operands = {.reserveOpcode = OpCodeAdd, .opType = MATH_TYPE_DST, .canOverflow = canOverflow, .src = src};    
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode operands_make_add_dst(bool canOverflow, uint16_t dst, uint16_t src1, uint16_t src2)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src1 <= MAX_FRAME_LENGTH);
    assert(src2 <= MAX_FRAME_LENGTH);

    BYTECODE_ALIGN const OperandsAddDst operands = {.reserveOpcode = OpCodeAdd, .opType = MATH_TYPE_DST, .canOverflow = canOverflow, .dst = dst, .src1 = src1, .src2 = src2};    
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode operands_make_add_assign(bool canOverflow, uint16_t src1, uint16_t src2)
{
    assert(src1 <= MAX_FRAME_LENGTH);
    assert(src2 <= MAX_FRAME_LENGTH);

    BYTECODE_ALIGN const OperandsAddAssign operands = {.reserveOpcode = OpCodeAdd, .opType = MATH_TYPE_SRC_ASSIGN, .canOverflow = canOverflow, .src1 = src1, .src2 = src2};    
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}
