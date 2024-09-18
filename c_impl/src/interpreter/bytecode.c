#include "bytecode.h"
#include <assert.h>
#include <string.h>

OpCode cubs_bytecode_get_opcode(Bytecode b)
{
    return (OpCode)(b.value & OPCODE_USED_BITMASK);
}

Bytecode cubs_bytecode_encode(OpCode opcode, const void *operands)
{
    if(operands == NULL) {
        const Bytecode b = {.value = opcode};
        return b;
    } else {
        Bytecode b = *(const Bytecode*)operands;
        assert(cubs_bytecode_get_opcode(b) == opcode);
        return b;
    }

}

Bytecode cubs_bytecode_encode_data_as_bytecode(size_t sizeOfT, const void *data)
{
    assert(sizeOfT <= sizeof(Bytecode));
    Bytecode b;
    memcpy((void*)&b, data, sizeOfT);
    return b;
}

Bytecode cubs_bytecode_encode_immediate_long_int(int64_t num)
{
    Bytecode out;
    out.value = *(const uint64_t*)&num;
    return out;
}

Bytecode cubs_bytecode_encode_immediate_long_float(double num)
{    
    Bytecode out;
    out.value = *(const uint64_t*)&num;
    return out;
}

Bytecode cubs_bytecode_encode_immediate_long_ptr(void *ptr)
{
    Bytecode out;
    out.value = *(const uint64_t*)&ptr;
    return out;
}

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
