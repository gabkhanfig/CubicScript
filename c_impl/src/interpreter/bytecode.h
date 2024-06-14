#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "../util/unreachable.h"
#include "../util/panic.h"

typedef enum {
    OPCODE_USED_BITS = 8,
    OPCODE_USED_BITMASK = 0b11111111,
} OpCode;

typedef struct Bytecode {
    uint32_t value;
} Bytecode;

OpCode cubs_bytecode_get_opcode(Bytecode b);

#define _encode_impl(out, opcode, operands) \
if(sizeof(operands) == 1) { \
    const uint32_t _operandsAsNum = *(const uint8_t*)&operands; \
    *out = (uint32_t)opcode | (_operandsAsNum << OPCODE_USED_BITS); \
} else if(sizeof(operands) == 2) { \
    const uint8_t* _operandsBytes = (const uint8_t)&operands; \
    const uint32_t _operandsAsNum = (uint32_t)_operandsBytes[0] | (((uint32_t)_operandsBytes[1]) << 8) \
    *out = (uint32_t)opcode | (_operandsAsNum << OPCODE_USED_BITS); \
} else if(sizeof(operands) == 3) { \
    const uint8_t* _operandsBytes = (const uint8_t)&operands; \
    const uint32_t _operandsAsNum = (uint32_t)_operandsBytes[0] | (((uint32_t)_operandsBytes[1]) << 8) | (((uint32_t)_operandsBytes[2]) << 16) \
    *out = (uint32_t)opcode | (_operandsAsNum << OPCODE_USED_BITS); \
} else { \
    unreachable(); \
}

#if _DEBUG
#define encode(out, opcode, operands) \
do { \
    if(sizeof(operands) == 3) { \
        const uint8_t* _operandsBytes = (const uint8_t)&operands; \
        const uint32_t _operandsAsNum = (uint32_t)_operandsBytes[0] | (((uint32_t)_operandsBytes[1]) << 8) | (((uint32_t)_operandsBytes[2]) << 16) \
        if((_operandsAsNum & (uint32_t)0x00FFFFFF) != 0) { \
            cubs_panic("operands uses too many bits"); \
        } \
    } \
    _encode_impl(out, opcode, operands)\
} while(false)
#else
#define encode(out opcode, operands) \ 
do { \
    _encode_impl(out, opcode, operands) \
} while(false)
#endif

// because no OperandsT can have an alignment greater than 4, this works
#define decode(out, bytecode, OperandsT) \
do { \
   const uint32_t _operandsMask = bytecode.value >> OPCODE_USED_BITS; \
   *out = *(const OperandsT*)&_operandsMask; \
} while(false) \
