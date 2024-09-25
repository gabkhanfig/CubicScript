#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "../util/unreachable.h"
#include "../util/panic.h"
#include <assert.h>
#include "interpreter.h"

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
    OpCodeReturn = 2,
    /// 
    OpCodeCall = 3,
    /// Increments an integer or iterator
    OpCodeIncrement,
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


