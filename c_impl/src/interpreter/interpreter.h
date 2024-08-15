#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include "value_tag.h"
#include "../program/program_runtime_error.h"

typedef struct Bytecode Bytecode;
typedef struct CubsProgram CubsProgram;
typedef struct CubsTypeContext CubsTypeContext;

#ifndef CUBS_STACK_SLOTS
/// 1 MB default (slots * 8 bytes per slot)
#define CUBS_STACK_SLOTS (1 << 17)
#endif

#define BITS_PER_STACK_OPERAND 13
#define MAX_FRAME_LENGTH ((1 << BITS_PER_STACK_OPERAND) - 1)

typedef struct {
    size_t basePointerOffset;
    size_t frameLength;
    /// Determines if `returnValueDst` and `returnTagDst` are pointers, or stack offsets
    void* returnValueDst;
    const CubsTypeContext** returnContextDst;
} InterpreterStackFrame;

void cubs_interpreter_push_frame(size_t frameLength, const struct Bytecode* oldInstructionPointer, void* returnValueDst, const CubsTypeContext** returnContextDst);

/// Operates on the calling thread's interpreter stack.
void cubs_interpreter_pop_frame();

/// Unwinds the current stack frame, deinitializing all objects.
/// Does not pop the frame.
void cubs_interpreter_stack_unwind_frame();

InterpreterStackFrame cubs_interpreter_current_stack_frame();
 
/// `offset` is an offset from the start of the current stack frame (excluding reserved slots) from as intervals of 8 bytes
void* cubs_interpreter_stack_value_at(size_t offset);

/// `offset` is an offset from the start of the current stack frame (excluding reserved slots) from as intervals of 8 bytes
const struct CubsTypeContext* cubs_interpreter_stack_context_at(size_t offset);

/// If `context->sizeOfType > sizeof(size_t)`, fills the following contexts to NULL.
void cubs_interpreter_stack_set_context_at(size_t offset, const struct CubsTypeContext* context);

/// Sets the context at a given stack offset, but flags it as non-owning. 
/// This is mostly for dereferencing temporaries, as when the stack unwinds, the value will not be deinitialized.
/// If `context->sizeOfType > sizeof(size_t)`, fills the following contexts to NULL.
void cubs_interpreter_stack_set_reference_context_at(size_t offset, const struct CubsTypeContext* context);

void cubs_interpreter_stack_set_null_context_at(size_t offset);

void cubs_interpreter_set_instruction_pointer(const struct Bytecode* newIp);

/// Assumes that the new stack frame hasn't been pushed yet.
/// Copies the memory at `arg`.
void cubs_interpreter_push_function_arg(const void* arg, const struct CubsTypeContext* context, size_t offset);

/// Executes the operation at this thread's instruction pointer
CubsProgramRuntimeError cubs_interpreter_execute_operation(const struct CubsProgram* program);