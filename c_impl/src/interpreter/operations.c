#include "operations.h"

Bytecode operands_make_load_immediate(int immediateType, uint16_t dst, int64_t immediate)
{
    assert(dst <= MAX_FRAME_LENGTH);
    _Alignas(_Alignof(Bytecode)) const OperandsLoadImmediate operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_IMMEDIATE, .immediateType = immediateType, .dst = dst, .immediate = immediate};
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

void operands_make_load_immediate_long(Bytecode* doubleBytecode, CubsValueTag tag, uint16_t dst, size_t immediate)
{
    assert(dst <= MAX_FRAME_LENGTH);
    _Alignas(_Alignof(Bytecode)) const OperandsLoadImmediateLong operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_IMMEDIATE_LONG, .immediateValueTag = tag, .dst = dst};
    doubleBytecode[0] = *(const Bytecode*)&operands;
    doubleBytecode[1].value = (size_t)immediate;
}

void operands_make_load_default(Bytecode* multiBytecode, CubsValueTag tag, uint16_t dst, const CubsTypeContext* optKeyContext, const CubsTypeContext* optValueContext)
{
    assert(dst <= MAX_FRAME_LENGTH);
    _Alignas(_Alignof(Bytecode)) const OperandsLoadDefault operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_DEFAULT, .dst = dst, .tag = tag};
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
    _Alignas(_Alignof(Bytecode)) const OperandsLoadCloneFromPtr operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_CLONE_FROM_PTR, .dst = dst};
    tripleBytecode[0] = *(const Bytecode*)&operands;
    tripleBytecode[1].value = (size_t)immediatePtr;
    tripleBytecode[2].value = (size_t)context;
}

Bytecode operands_make_return(bool hasReturn, uint16_t returnSrc)
{
    _Alignas(_Alignof(Bytecode)) const OperandsReturn ret = {.reserveOpcode = OpCodeReturn, .hasReturn = hasReturn, .returnSrc = returnSrc};
    return *(const Bytecode*)&ret;
}

void cubs_operands_make_call_immediate(Bytecode *bytecodeArr, size_t availableBytecode, uint16_t argCount, const uint16_t *args, bool hasReturn, uint16_t returnSrc, CubsFunction func)
{
    { // validation
        if(hasReturn) {
            assert(returnSrc <= MAX_FRAME_LENGTH);
        }
        for(uint16_t i = 0; i < argCount; i++) {
            assert(args[i] <= MAX_FRAME_LENGTH);
        }

        /// Initial bytecode + immediate function
        size_t requiredBytecode = 1 + 1;
        if(argCount & 4 == 0) {
            requiredBytecode += (argCount / 4);
        } else {
            requiredBytecode += (argCount / 4) + 1;
        }
        assert(availableBytecode >= requiredBytecode);
    }

    _Alignas(_Alignof(Bytecode)) const OperandsCallImmediate operands = {
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
}

void cubs_operands_make_call_src(Bytecode *bytecodeArr, size_t availableBytecode, uint16_t argCount, const uint16_t *args, bool hasReturn, uint16_t returnSrc, uint16_t funcSrc)
{
    { // validation
        assert(funcSrc <= MAX_FRAME_LENGTH);
        if(hasReturn) {
            assert(returnSrc <= MAX_FRAME_LENGTH);
        }
        for(uint16_t i = 0; i < argCount; i++) {
            assert(args[i] <= MAX_FRAME_LENGTH);
        }

        /// Initial bytecode
        size_t requiredBytecode = 1;
        if(argCount & 4 == 0) {
            requiredBytecode += (argCount / 4);
        } else {
            requiredBytecode += (argCount / 4) + 1;
        }
        assert(availableBytecode >= requiredBytecode);
    }

    _Alignas(_Alignof(Bytecode)) const OperandsCallSrc operands = {
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
}

Bytecode operands_make_increment_dst(bool canOverflow, uint16_t dst, uint16_t src)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src <= MAX_FRAME_LENGTH);

    _Alignas(_Alignof(Bytecode)) const OperandsIncrementDst operands = {.reserveOpcode = OpCodeAdd, .opType = MATH_TYPE_DST, .canOverflow = canOverflow, .dst = dst, .src = src};    
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode operands_make_increment_assign(bool canOverflow, uint16_t src)
{
    assert(src <= MAX_FRAME_LENGTH);    
    
    _Alignas(_Alignof(Bytecode)) const OperandsIncrementAssign operands = {.reserveOpcode = OpCodeAdd, .opType = MATH_TYPE_DST, .canOverflow = canOverflow, .src = src};    
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode operands_make_add_dst(bool canOverflow, uint16_t dst, uint16_t src1, uint16_t src2)
{
    assert(dst <= MAX_FRAME_LENGTH);
    assert(src1 <= MAX_FRAME_LENGTH);
    assert(src2 <= MAX_FRAME_LENGTH);

    _Alignas(_Alignof(Bytecode)) const OperandsAddDst operands = {.reserveOpcode = OpCodeAdd, .opType = MATH_TYPE_DST, .canOverflow = canOverflow, .dst = dst, .src1 = src1, .src2 = src2};    
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}

Bytecode operands_make_add_assign(bool canOverflow, uint16_t src1, uint16_t src2)
{
    assert(src1 <= MAX_FRAME_LENGTH);
    assert(src2 <= MAX_FRAME_LENGTH);

    _Alignas(_Alignof(Bytecode)) const OperandsAddAssign operands = {.reserveOpcode = OpCodeAdd, .opType = MATH_TYPE_SRC_ASSIGN, .canOverflow = canOverflow, .src1 = src1, .src2 = src2};    
    const Bytecode b = *(const Bytecode*)&operands;
    return b;
}
