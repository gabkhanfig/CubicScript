#include "stack.h"
#include "../program/program.h"
#include <stdint.h>

extern void* _cubs_os_aligned_malloc(size_t len, size_t align);
extern void* _cubs_os_aligned_free(void *buf, size_t len, size_t align);

typedef struct {
    const CubsProgram* program;
    /// For `stack` the memory is valid for `stackSlots * 8`.
    /// For `tags`, the memory is valid for `stackSlots * 1`.
    size_t stackSlots;
    void* stack;
    uint8_t* tags;
    size_t nextBasePointer;
    InterpreterStackFrame frame;
} InterpreterStackState;

static _Thread_local InterpreterStackState threadLocalStack;

void cubs_interpreter_push_frame(size_t frameLength, const uint32_t *newInstructionPointer, void *returnValueDst, uint8_t *returnTagDst)
{
}
