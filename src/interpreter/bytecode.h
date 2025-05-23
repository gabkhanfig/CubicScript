#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "../util/unreachable.h"
#include "../util/panic.h"
#include <assert.h>
#include "stack.h"

typedef enum OpCode {
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
    /// TODO should call be split into two different opcodes? theoretically is higher performance as takes 1 less branch
    OpCodeCall = 3,
    /// TODO should jump be split into different opcodes for normal jump, jump if true, and jump if false? theoretically higher performance with less branching
    /// TODO figure out switch
    OpCodeJump = 4,
    /// Most of the time, stack unwinding is good enough, however there may be specific cases where explicit 
    /// deinitialization is necessary, whether through variable reassignment, or whatever else.
    OpCodeDeinit = 5,
    /// Adds multiple values in the stack frame to the sync queue, and then queues them.
    /// This avoids deadlocks, and also can leverage read-only, OR read-write access.
    OpCodeSync,
    /// Moves some data from `src` to `dst`, making the `src` location invalid memory. Conceptually this is a destructive move.
    /// Does not validate that the memory being moved to is not in use.
    OpCodeMove,
    /// Makes a clone of `src`, storing it in `dst`. Both memory locations will be valid after the clone.
    /// Does not validate that the memory being moved to is not in use.
    OpCodeClone,
    /// Dereferences the type at `dst`, storing the value in `src`.
    /// This results in a non-owning value as a reference, in which 
    /// `OpCodeDeinit` will not  deinit the value. Works with 
    /// `CubsConstRef`, `CubsMutRef`, `CubsUnique`, `CubsShared`, and `CubsWeak`.
    OpCodeDereference,
    /// Sets the memory referenced by `dst` to the value in `src`, moving the value
    /// and setting the `src` context to NULL. Works with `CubsConstRef`, 
    /// `CubsMutRef`, `CubsUnique`, `CubsShared`, and `CubsWeak`.
    OpCodeSetReference,
    /// Creates a mutable or immutable reference to the stack value at `src`,
    /// storing the reference value in `dst`. Works for creating
    /// `CubsConstRef` and `CubsMutRef` instances.
    OpCodeMakeReference,
    // TODO maybe more efficient for OpCodeGetMember to be split into 2, one for values and one for references
    /// Gets a non-owning value as a reference to the member variable within a
    /// struct value or reference at `src` using the immediate member index of 
    /// `memberIndex`, storing the reference in `dst`.
    /// Can auto-dereference when necessary. Works with struct values, as well as
    /// `CubsConstRef`, `CubsMutRef`, `CubsUnique`, `CubsShared`, and `CubsWeak`. 
    OpCodeGetMember,
    // TODO maybe more efficient for OpCodeSetMember to be split into 2, one for values and one for references
    /// Sets the member of a struct value or reference at `dst` using the immediate
    /// member index of `memberIndex`, to the value at `src`, moving the value. Can
    /// auto-dereference when necessary. Works with struct values, as well as
    /// `CubsConstRef`, `CubsMutRef`, `CubsUnique`, `CubsShared`, and `CubsWeak`. 
    OpCodeSetMember,
    // TODO this operation
    OpCodeCast,
    /// Performs `src1 == src2`, storing the bool result in dst.
    OpCodeEqual,
    /// Performs `src1 != src2`, storing the bool result in dst.
    OpCodeNotEqual,
    /// Performs `src < src2`, storing the bool result in dst.
    OpCodeLess,
    /// Performs `src > src2`, storing the bool result in dst.
    OpCodeGreater,
    /// Performs `src <= src2`, storing the bool result in dst.
    OpCodeLessOrEqual,
    /// Performs `src >= src2`, storing the bool result in dst.
    OpCodeGreaterOrEqual,
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

OpCode cubs_bytecode_get_opcode(Bytecode b);

Bytecode cubs_bytecode_encode(OpCode opcode, const void* operands);

Bytecode cubs_bytecode_encode_data_as_bytecode(size_t sizeOfT, const void* data);

Bytecode cubs_bytecode_encode_immediate_long_int(int64_t num);

Bytecode cubs_bytecode_encode_immediate_long_float(double num);

Bytecode cubs_bytecode_encode_immediate_long_ptr(void *ptr);

