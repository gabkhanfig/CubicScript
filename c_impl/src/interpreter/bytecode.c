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
