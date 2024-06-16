#include "stack.h"
#include "../program/program.h"
#include <assert.h>
#include "bytecode.h"
#include <string.h>

extern void* _cubs_os_aligned_malloc(size_t len, size_t align);
extern void* _cubs_os_aligned_free(void *buf, size_t len, size_t align);


static const size_t OLD_INSTRUCTION_POINTER = 0;
static const size_t OLD_FRAME_LENGTH = 1;
static const size_t OLD_RETURN_VALUE_DST = 2;
static const size_t OLD_RETURN_TAG_DST = 3;
static const size_t RESERVED_SLOTS = 4;

typedef struct InterpreterStackState {
    /// Offset from `stack` and `tags` indicated where the next frame should start
    size_t nextBaseOffset;
    InterpreterStackFrame frame;
    size_t stack[CUBS_STACK_SLOTS];
    uint8_t tags[CUBS_STACK_SLOTS];
} InterpreterStackState;

static _Thread_local InterpreterStackState threadLocalStack = {0};

void cubs_interpreter_push_frame(size_t frameLength, const struct Bytecode* oldInstructionPointer, void* returnValueDst, uint8_t* returnTagDst) {
    { // store previous instruction pointer, frame length, return dst, and return tag dst
        size_t* basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.nextBaseOffset];
        if(threadLocalStack.nextBaseOffset == 0) {
            basePointer[OLD_INSTRUCTION_POINTER]    = 0;
            basePointer[OLD_FRAME_LENGTH]           = 0;
            basePointer[OLD_RETURN_VALUE_DST]       = 0;
            basePointer[OLD_RETURN_TAG_DST]         = 0;
        } else {
            basePointer[OLD_INSTRUCTION_POINTER]    = (size_t)((const void*)oldInstructionPointer); // cast ptr to size_t
            basePointer[OLD_FRAME_LENGTH]           = threadLocalStack.frame.frameLength;
            basePointer[OLD_RETURN_VALUE_DST]       = (size_t)threadLocalStack.frame.returnValueDst;
            basePointer[OLD_RETURN_TAG_DST]         = (size_t)threadLocalStack.frame.returnTagDst;
        }
    }

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = frameLength,
        .returnValueDst = returnValueDst,
        .returnTagDst = returnTagDst
    };
    threadLocalStack.frame = newFrame;
    threadLocalStack.nextBaseOffset += frameLength + RESERVED_SLOTS;  
}

void cubs_interpreter_pop_frame()
{
    assert(threadLocalStack.nextBaseOffset != 0 && "No more frames to pop!");

    const size_t offset = threadLocalStack.frame.frameLength + RESERVED_SLOTS;

    threadLocalStack.nextBaseOffset -= offset;
    if(threadLocalStack.nextBaseOffset == 0) {
        return;
    }

    size_t* basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.frame.basePointerOffset];
    const size_t oldInstructionPointer = basePointer[OLD_INSTRUCTION_POINTER];
    const size_t oldFrameLength = basePointer[OLD_FRAME_LENGTH];
    void* const oldReturnValueDst = (void*)basePointer[OLD_RETURN_VALUE_DST];
    uint8_t* const oldReturnTagDst = (uint8_t*)basePointer[OLD_RETURN_TAG_DST];

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = oldFrameLength,
        .returnValueDst = oldReturnValueDst,
        .returnTagDst = oldReturnTagDst
    };   
    threadLocalStack.frame = newFrame;
}

InterpreterStackFrame cubs_interpreter_current_stack_frame()
{
    return threadLocalStack.frame;
}

void *cubs_interpreter_stack_value_at(size_t offset)
{
    assert(offset < threadLocalStack.frame.frameLength);
    return (void*)(&threadLocalStack.stack[threadLocalStack.frame.basePointerOffset + offset]);
}

CubsValueTag cubs_interpreter_stack_tag_at(size_t offset)
{
    assert(offset < threadLocalStack.frame.frameLength);
    const uint8_t tag = threadLocalStack.tags[threadLocalStack.frame.basePointerOffset + offset];
    return (CubsValueTag)tag;
}

void cubs_interpreter_stack_set_tag_at(size_t offset, CubsValueTag tag)
{
    assert(offset < threadLocalStack.frame.frameLength);
    const uint8_t tagAs8 = (uint8_t)tag;
    threadLocalStack.tags[threadLocalStack.frame.basePointerOffset + offset] = tagAs8;
}


