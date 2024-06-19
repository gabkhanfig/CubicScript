#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "../util/unreachable.h"
#include "../util/panic.h"
#include <assert.h>
#include "interpreter.h"

// ARM style load/store
// https://azeria-labs.com/memory-instructions-load-and-store-part-4/

typedef enum {
    OpCodeNop = 0,
    OpCodeLoad = 1,

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
    uint64_t value;
} Bytecode;


#define XSTRINGIFY(s) str(s)
#define STRINGIFY(s) #s
#define VALIDATE_SIZE_ALIGN_OPERANDS(OperandsT) \
_Static_assert(sizeof(OperandsT) == sizeof(Bytecode), "Size of " STRINGIFY(OperandsT) " must match that of InterpreterBytecode"); \
_Static_assert(_Alignof(OperandsT) == _Alignof(Bytecode), "Align of " STRINGIFY(OperandsT) " must match that of InterpreterBytecode");

OpCode cubs_bytecode_get_opcode(Bytecode b);

Bytecode cubs_bytecode_encode(OpCode opcode, const void* operands);

Bytecode cubs_bytecode_encode_data_as_bytecode(size_t sizeOfT, const void* data);

Bytecode cubs_bytecode_encode_immediate_long_int(int64_t num);

Bytecode cubs_bytecode_encode_immediate_long_float(double num);

Bytecode cubs_bytecode_encode_immediate_long_ptr(void *ptr);

#define LOAD_TYPE_IMMEDIATE 0
#define LOAD_TYPE_IMMEDIATE_LONG 1
#define LOAD_TYPE_DEFAULT 2
#define LOAD_TYPE_CLONE_FROM_PTR 3
typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t loadType: 2;
} OperandsLoadUnknown;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadUnknown);

#define LOAD_IMMEDIATE_BOOL 0
#define LOAD_IMMEDIATE_INT 1
typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: 2;
    uint64_t immediateType: 1;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    int64_t immediate: 40;
} OperandsLoadImmediate;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadImmediate);
/// For a floating point immediate, must be a whole number
Bytecode operands_make_load_immediate(int immediateType, uint16_t dst, int64_t immediate);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: 2;
    uint64_t immediateValueTag: 6; // CubsValueTag
    uint64_t dst: BITS_PER_STACK_OPERAND;
} OperandsLoadImmediateLong;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadImmediateLong);
/// @param doubleBytecode must be a pointer to at least 2 bytecodes
void operands_make_load_immediate_long(Bytecode* doubleBytecode, CubsValueTag tag, uint16_t dst, size_t immediate);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: 2;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t tag: 6;
    uint64_t keyTag: 6;
    uint64_t valueTag: 6;
} OperandsLoadDefault;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadDefault);
Bytecode operands_make_load_default(CubsValueTag tag, CubsValueTag optKeyTag, CubsValueTag optValueTag, uint16_t dst);