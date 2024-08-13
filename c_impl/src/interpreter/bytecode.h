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
    /// No operation. Useful for debugging purposes.
    OpCodeNop = 0,
    /// Loads a value into the stack. There are 4 types of load operations.
    /// - Immediate -> `OperandsLoadImmediate` Loads some small immediate data 
    /// - Immediate long -> `OperandsLoadImmediateLong` Loads some large data. Is a multibyte instruction
    /// - Default -> `OperandsLoadDefault` loads the default representation of a type if it has one. May be a multibyte instruction
    /// - Clone from ptr -> `OperandsLoadCloneFromPtr` Clones some data held at a given immediate pointer, using an immediate context. Is a 3 bytecode wide multibyte instruction
    OpCodeLoad = 1,
    /// 
    OpCodeAdd,

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

typedef enum {
    LOAD_TYPE_IMMEDIATE = 0,
    LOAD_TYPE_IMMEDIATE_LONG = 1,
    LOAD_TYPE_DEFAULT = 2,
    LOAD_TYPE_CLONE_FROM_PTR = 3,

    RESERVE_LOAD_TYPE = 2,
} LoadOperationType;

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t loadType: RESERVE_LOAD_TYPE;
} OperandsLoadUnknown;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadUnknown);

#define LOAD_IMMEDIATE_BOOL 0
#define LOAD_IMMEDIATE_INT 1
typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: RESERVE_LOAD_TYPE;
    uint64_t immediateType: 1;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    int64_t immediate: 40;
} OperandsLoadImmediate;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadImmediate);
/// For a floating point immediate, must be a whole number
Bytecode operands_make_load_immediate(int immediateType, uint16_t dst, int64_t immediate);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: RESERVE_LOAD_TYPE;
    uint64_t immediateValueTag: 6; // CubsValueTag
    uint64_t dst: BITS_PER_STACK_OPERAND;
} OperandsLoadImmediateLong;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadImmediateLong);
/// @param doubleBytecode must be a pointer to at least 2 bytecodes
void operands_make_load_immediate_long(Bytecode* doubleBytecode, CubsValueTag tag, uint16_t dst, size_t immediate);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: RESERVE_LOAD_TYPE;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t tag: 6;
} OperandsLoadDefault;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadDefault);
/// If `tag` is a generic type that IS NOT `cubsValueTagMap`, `multiBytecode` must be a pointer to at least 2 bytecodes. 
/// If `tag == cubsValueTagMap`, `multiBytecode` must be a pointer to at least 3 bytecodes. 
/// Otherwise, `multiBytecode` is treated as a single pointer.
void operands_make_load_default(Bytecode* multiBytecode, CubsValueTag tag, uint16_t dst, const CubsTypeContext* optKeyContext, const CubsTypeContext* optValueContext);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: RESERVE_LOAD_TYPE;
    uint64_t dst: BITS_PER_STACK_OPERAND;
} OperandsLoadCloneFromPtr;
void operands_make_load_clone_from_ptr(Bytecode* tripleBytecode, uint16_t dst, const void* immediatePtr, const CubsTypeContext* context);

typedef enum  {
    MATH_TYPE_DST,
    MATH_TYPE_SRC_ASSIGN,
    
    RESERVE_MATH_OP_TYPE = 1,
} MathOperationType;

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    /// Only used for integer types (int, vec)
    uint64_t canOverflow: 1;
    uint64_t src1: BITS_PER_STACK_OPERAND;
    uint64_t src2: BITS_PER_STACK_OPERAND;
} OperandsAddUnknown;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsAddUnknown);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    /// Only used for integer types (int, vec)
    uint64_t canOverflow: 1;
    uint64_t src1: BITS_PER_STACK_OPERAND;
    uint64_t src2: BITS_PER_STACK_OPERAND;
    uint64_t dst: BITS_PER_STACK_OPERAND;
} OperandsAddDst;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsAddDst);
Bytecode operands_make_add_dst(bool canOverflow, uint16_t dst, uint16_t src1, uint16_t src2);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    /// Only used for integer types (int, vec)
    uint64_t canOverflow: 1;
    uint64_t src1: BITS_PER_STACK_OPERAND;
    uint64_t src2: BITS_PER_STACK_OPERAND;
} OperandsAddAssign;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsAddAssign);
Bytecode operands_make_add_assign(bool canOverflow, uint16_t src1, uint16_t src2);