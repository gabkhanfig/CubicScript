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

void cubs_bytecode_encode_immediate_long_int(Bytecode* dualBytecodeStart, int64_t num)
{
    dualBytecodeStart[0].value = *(const uint32_t*)&num;
    dualBytecodeStart[1].value = ((const uint32_t*)&num)[1];
}

void cubs_bytecode_encode_immediate_long_float(Bytecode* dualBytecodeStart, double num)
{    
    dualBytecodeStart[0].value = *(const uint32_t*)&num;
    dualBytecodeStart[1].value = ((const uint32_t*)&num)[1];
}

void cubs_bytecode_encode_immediate_long_ptr(Bytecode *dualBytecodeStart, const void *ptr)
{
    const size_t ptrAsNum = (size_t)ptr;
    dualBytecodeStart[0].value = *(const uint32_t*)&ptrAsNum;
    dualBytecodeStart[1].value = ((const uint32_t*)&ptrAsNum)[1];
}

Bytecode operands_make_load_immediate(int immediateType, uint32_t dst, int32_t immediate)
{
    assert(dst < REGISTER_COUNT);
    const OperandsLoadImmediate operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_IMMEDIATE, .immediateType = immediateType, .dst = dst, .immediate = immediate};
    return *(const Bytecode*)&operands;
}

void operands_make_load_immediate_long(Bytecode *tripleBytecode, CubsValueTag tag, uint32_t dst, size_t immediate)
{
    assert(dst < REGISTER_COUNT);
    const OperandsLoadImmediateLong operands = {.reserveOpcode = OpCodeLoad, .reserveLoadType = LOAD_TYPE_IMMEDIATE_LONG, .immediateValueTag = tag, .dst = dst};
    tripleBytecode[0] = *(const Bytecode*)&operands;
    tripleBytecode[1].value = ((const uint32_t*)&immediate)[0];
    tripleBytecode[2].value = ((const uint32_t*)&immediate)[1];
}
