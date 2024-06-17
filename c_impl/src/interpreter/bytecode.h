#pragma once

//! ALL Operands have a size and alignment of 4 bytes, but must have the opcode occupy the first
//! `OPCODE_USED_BITS`, so it can be reinterpret casted as the correct operands

#include <stdint.h>
#include <stdbool.h>
#include "../util/unreachable.h"
#include "../util/panic.h"
#include "interpreter.h"
#include <assert.h>

// ARM style load/store
// https://azeria-labs.com/memory-instructions-load-and-store-part-4/

typedef enum {
    OpCodeNop = 0,
    OpCodeLoad = 1,
    OpCodeStore = 2,

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


#define XSTRINGIFY(s) str(s)
#define STRINGIFY(s) #s
#define VALIDATE_SIZE_ALIGN_OPERANDS(OperandsT) \
_Static_assert(sizeof(OperandsT) == sizeof(Bytecode), "Size of " STRINGIFY(OperandsT) " must match that of InterpreterBytecode"); \
_Static_assert(_Alignof(OperandsT) == _Alignof(Bytecode), "Align of " STRINGIFY(OperandsT) " must match that of InterpreterBytecode");

OpCode cubs_bytecode_get_opcode(Bytecode b);

Bytecode cubs_bytecode_encode(OpCode opcode, const void* operands);

Bytecode cubs_bytecode_encode_data_as_bytecode(size_t sizeOfT, const void* data);

/// @param dualBytecodeStart Must be a pointer to two bytecodes, where `num` is copied into
void cubs_bytecode_encode_immediate_long_int(Bytecode* dualBytecodeStart, int64_t num);

/// @param dualBytecodeStart Must be a pointer to two bytecodes, where `num` is copied into
void cubs_bytecode_encode_immediate_long_float(Bytecode* dualBytecodeStart, double num);

/// @param dualBytecodeStart Must be a pointer to two bytecodes, where `num` is copied into
void cubs_bytecode_encode_immediate_long_ptr(Bytecode* dualBytecodeStart, const void* ptr);

#define LOAD_TYPE_IMMEDIATE 0
#define LOAD_TYPE_IMMEDIATE_LONG 1
#define LOAD_TYPE_FROM_STACK 2
typedef struct {
    uint32_t reserveOpcode: OPCODE_USED_BITS;
    uint32_t loadType: 2;
} OperandsLoadUnknown;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadUnknown);

#define LOAD_IMMEDIATE_BOOL 0
#define LOAD_IMMEDIATE_INT 1
#define LOAD_IMMEDIATE_FLOAT 2
typedef struct {
    uint32_t reserveOpcode: OPCODE_USED_BITS;
    uint32_t reserveLoadType: 2;
    uint32_t immediateType: 2;
    uint32_t dst: REGISTER_BITS_REQUIRED;
    int32_t immediate: 15;
} OperandsLoadImmediate;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadImmediate);
/// For a floating point immediate, must be a whole number
Bytecode operands_make_load_immediate(int immediateType, uint32_t dst, int32_t immediate);

typedef struct {
    uint32_t reserveOpcode: OPCODE_USED_BITS;
    uint32_t reserveLoadType: 2;
    uint32_t immediateValueTag: 6; // CubsValueTag
    uint32_t dst: REGISTER_BITS_REQUIRED;
} OperandsLoadImmediateLong;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadImmediateLong);

typedef struct {
    uint32_t reserveOpcode: OPCODE_USED_BITS;
    uint32_t reserveLoadType: 2;
    uint32_t dst: REGISTER_BITS_REQUIRED;
    uint32_t offsetFromFrameStart: 17; 
} OperandsLoadFromStack;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadFromStack);