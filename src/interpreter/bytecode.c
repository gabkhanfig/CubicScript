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
