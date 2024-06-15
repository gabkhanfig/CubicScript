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
