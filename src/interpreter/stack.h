#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include "value_tag.h"

struct Bytecode;
struct CubsProgram;
struct CubsTypeContext;
struct CubsScriptFunctionPtr;

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

enum InterpreterFrameReservedSlots {
    OLD_INSTRUCTION_POINTER = 0,
    OLD_FRAME_LENGTH = 1,
    OLD_RETURN_VALUE_DST = 2,
    OLD_RETURN_CONTEXT_DST = 3,
    RESERVED_SLOTS = 4,
};

void cubs_interpreter_push_frame(size_t frameLength, void* returnValueDst, const struct CubsTypeContext** returnContextDst);

/// Operates on the calling thread's interpreter stack.
void cubs_interpreter_pop_frame();

/// Unwinds the current stack frame, deinitializing all objects.
/// Does not pop the frame.
void cubs_interpreter_stack_unwind_frame();

InterpreterStackFrame cubs_interpreter_current_stack_frame();
 
/// `offset` is an offset from the start of the current stack frame (excluding reserved slots) from as intervals of 8 bytes
void* cubs_interpreter_stack_value_at(size_t offset);

/// `offset` is an offset from the start of the current stack frame 
/// (excluding reserved slots) from as intervals of 8 bytes. Masks away the 
/// bit flag for if this is a non-owning context (reference).
const struct CubsTypeContext* cubs_interpreter_stack_context_at(size_t offset);

/// Gets the pointer to the actual place in the interpreter stack where the context at `offset` should be.
/// It is up to the programmer to correct set the ref tag bit if necessary, or mask it away. The bit specifically is `0b01`.
/// `offset` is an offset from the start of the current stack frame (excluding reserved slots) from as intervals of 8 bytes
const struct CubsTypeContext** cubs_interpreter_stack_context_ptr_at(size_t offset);

/// Gets if the context at `offset` is an owned value, meaning not a 
/// TEMPORARY reference. Value instances of `CubsConstRef` and related for
/// example will return true, as they are owned. However, when performing the
/// dereference bytecode, a non-owning value will be put onto the stack. For
/// those values, this function returns false.
bool cubs_is_owning_context_at(size_t offset);

/// If `context->sizeOfType > sizeof(size_t)`, fills the following contexts to NULL.
void cubs_interpreter_stack_set_context_at(size_t offset, const struct CubsTypeContext* context);

/// Sets the context at a given stack offset, but flags it as non-owning. 
/// This is mostly for dereferencing temporaries, as when the stack unwinds, the value will not be deinitialized.
/// If `context->sizeOfType > sizeof(size_t)`, fills the following contexts to NULL.
void cubs_interpreter_stack_set_reference_context_at(size_t offset, const struct CubsTypeContext* context);

void cubs_interpreter_stack_set_null_context_at(size_t offset);

const struct Bytecode* cubs_interpreter_get_instruction_pointer();

void cubs_interpreter_set_instruction_pointer(const struct Bytecode* newIp);

/// Assumes that the new stack frame hasn't been pushed yet.
/// Copies the memory at `arg`.
void cubs_interpreter_push_script_function_arg(const void* arg, const struct CubsTypeContext* context, size_t offset);

/// Assumes that the new stack frame hasn't been pushed yet.
/// Copies the memory at `arg`.
void cubs_interpreter_push_c_function_arg(const void* arg, const struct CubsTypeContext* context, size_t offset, size_t currentArgCount, size_t argTrackOffset);

CubsFunctionReturn cubs_interpreter_return_dst();
