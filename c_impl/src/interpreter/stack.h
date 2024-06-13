#pragma once

#include <stddef.h>
#include "../primitives/value_tag.h"
#include <stdbool.h>

typedef struct InterpreterStackState;
struct Bytecode;

typedef struct {
    size_t basePointerOffset;
    size_t frameLength;
    /// Determines if `returnValueDst` and `returnTagDst` are pointers, or stack offsets
    bool returnToPtr;
    size_t returnValueDst;
    size_t returnTagDst;
} InterpreterStackFrame;

/// Operates on the calling thread's interpreter stack
/// Pushes a stack frame where the optional return destination has a known address.
/// Potentially reallocates the entire stack, but speculative preallocation is done.
void cubs_interpreter_push_frame_non_stack_return(size_t frameLength, const struct Bytecode* oldInstructionPointer, void* returnValueDst, uint8_t* returnTagDst);

/// Operates on the calling thread's interpreter stack
/// Pushes a stack frame where the optional return destination is an offset within the stack.
/// Potentially reallocates the entire stack, but speculative preallocation is done.
void cubs_interpreter_push_frame_in_stack_return(size_t frameLength, const struct Bytecode* oldInstructionPointer, size_t returnValueOffset, size_t returnTagOffset);

/// Operates on the calling thread's interpreter stack. Never reallocates.
void cubs_interpreter_pop_frame();
 