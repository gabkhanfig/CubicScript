#pragma once

//! ALL Operands have a size and alignment of 4 bytes, but must have the opcode occupy the first
//! `OPCODE_USED_BITS`, so it can be reinterpret casted as the correct operands

#include <stdint.h>
#include <stdbool.h>
#include "../util/unreachable.h"
#include "../util/panic.h"
#include "interpreter.h"

// ARM style load/store
// https://azeria-labs.com/memory-instructions-load-and-store-part-4/

typedef enum {
    OpCodeNop = 0,
    OpCodeLoad,
    OpCodeStore,
    OPCODE_USED_BITS = 8,
    OPCODE_USED_BITMASK = 0b11111111,
} OpCode;

/// To decode a bytecode into an operands `T`, simply cast the bytecode to it.
/// For example:
/// ```
/// const Bytecode b = ...;
/// SomeOperands operands = *(const SomeOperands*)&b;
/// ```
typedef struct Bytecode {
    uint32_t value;
} Bytecode;

OpCode cubs_bytecode_get_opcode(Bytecode b);

Bytecode cubs_bytecode_encode(OpCode opcode, const void* operands);

Bytecode cubs_bytecode_encode_data_as_bytecode(size_t sizeOfT, const void* data);

/// @param dualBytecodeStart Must be a pointer to two bytecodes, where `num` is copied into
void cubs_bytecode_encode_immediate_long_int(Bytecode* dualBytecodeStart, int64_t num);

/// @param dualBytecodeStart Must be a pointer to two bytecodes, where `num` is copied into
void cubs_bytecode_encode_immediate_long_float(Bytecode* dualBytecodeStart, double num);

/// @param dualBytecodeStart Must be a pointer to two bytecodes, where `num` is copied into
void cubs_bytecode_encode_immediate_long_ptr(Bytecode* dualBytecodeStart, const void* ptr);


