#include "bytecode.h"

OpCode cubs_bytecode_get_opcode(Bytecode b)
{
    return (OpCode)(b.value & OPCODE_USED_BITMASK);
}
