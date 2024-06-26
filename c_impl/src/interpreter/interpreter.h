#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include "../primitives/value_tag.h"

typedef struct Bytecode Bytecode;
typedef struct CubsProgram CubsProgram;

#ifndef CUBS_STACK_SLOTS
/// 1 MB default (slots * 8 bytes per slot)
#define CUBS_STACK_SLOTS (1 << 17)
#endif

#define BITS_PER_STACK_OPERAND 13
#define MAX_FRAME_LENGTH ((size_t)0b1111111111111)

typedef struct {
    size_t basePointerOffset;
    size_t frameLength;
    /// Determines if `returnValueDst` and `returnTagDst` are pointers, or stack offsets
    void* returnValueDst;
    uint8_t* returnTagDst;
} InterpreterStackFrame;

void cubs_interpreter_push_frame(size_t frameLength, const struct Bytecode* oldInstructionPointer, void* returnValueDst, uint8_t* returnTagDst);

/// Operates on the calling thread's interpreter stack.
void cubs_interpreter_pop_frame();

InterpreterStackFrame cubs_interpreter_current_stack_frame();
 
/// `offset` is an offset from the start of the current stack frame (excluding reserved slots) from as intervals of 8 bytes
void* cubs_interpreter_stack_value_at(size_t offset);

/// `offset` is an offset from the start of the current stack frame (excluding reserved slots) from as intervals of 8 bytes
CubsValueTag cubs_interpreter_stack_tag_at(size_t offset);

void cubs_interpreter_stack_set_tag_at(size_t offset, CubsValueTag tag);

typedef enum CubsFatalScriptError {
    cubsFatalScriptErrorNone = 0,

    _CUBS_FATAL_SCRIPT_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsFatalScriptError;

void cubs_interpreter_set_instruction_pointer(const struct Bytecode* newIp);

/// Executes the operation at this thread's instruction pointer
CubsFatalScriptError cubs_interpreter_execute_operation(const struct CubsProgram* program);