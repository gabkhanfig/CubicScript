#pragma once

#include <stddef.h>
#include "../primitives/value_tag.h"
#include <stdbool.h>

typedef struct InterpreterStackState;

typedef struct {
    size_t basePointerOffset;
    size_t frameLength;
    /// Determines if `returnValueDst` and `returnTagDst` are pointers, or stack offsets
    bool returnToPtr;
    size_t returnValueDst;
    size_t returnTagDst;
} InterpreterStackFrame;

/// Pushes a stack frame where the optional return destination has a known address.
/// Potentially reallocates the entire stack, but speculative preallocation is done.
void cubs_interpreter_push_frame_non_stack_return(size_t frameLength, const uint32_t* oldInstructionPointer, void* returnValueDst, uint8_t* returnTagDst);

/// Pushes a stack frame where the optional return destination is an offset within the stack.
/// Potentially reallocates the entire stack, but speculative preallocation is done.
void cubs_interpreter_push_frame_in_stack_return(size_t frameLength, const uint32_t* oldInstructionPointer, size_t returnValueOffset, size_t returnTagOffset);
