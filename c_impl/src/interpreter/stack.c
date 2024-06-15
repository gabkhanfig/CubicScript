#include "stack.h"
#include "../program/program.h"
#include <assert.h>
#include "bytecode.h"
#include <string.h>

extern void* _cubs_os_aligned_malloc(size_t len, size_t align);
extern void* _cubs_os_aligned_free(void *buf, size_t len, size_t align);


static const size_t OLD_INSTRUCTION_POINTER = 0;
static const size_t OLD_FRAME_LENGTH = 1;
static const size_t OLD_RETURN_IS_PTR = 2;
static const size_t OLD_RETURN_VALUE_DST = 3;
static const size_t OLD_RETURN_TAG_DST = 4;
static const size_t RESERVED_SLOTS = 5;

typedef struct InterpreterStackState {
    /// Is always a power of 2.
    /// For `tags`, the memory is valid for `stackSlots * 1`.
    _Alignas(64) size_t stackSlots;
    /// The memory is valid for `stackSlots * sizeof(size_t)`.
    void* stack;
    /// The memory is valid for `stackSlots * 1`.
    uint8_t* tags;
    /// Offset from `stack` and `tags` indicated where the next frame should start
    size_t nextBaseOffset;
    InterpreterStackFrame frame;
} InterpreterStackState;

static _Thread_local InterpreterStackState threadLocalStack = {0};

static bool should_reallocate(size_t* outReallocSlots, size_t frameLength) {   
    if(threadLocalStack.stackSlots == 0) {
        // 64 kibibytes/kilobytes idk which one
        const size_t DEFAULT_STACK_SLOTS = 1 << 13;
        if(frameLength > DEFAULT_STACK_SLOTS) {
            *outReallocSlots = frameLength + (DEFAULT_STACK_SLOTS - (frameLength % DEFAULT_STACK_SLOTS));
        }
        else {
            *outReallocSlots = DEFAULT_STACK_SLOTS;
        }
        return true;
    }
    else {
        const size_t lengthAndOffset = frameLength + threadLocalStack.nextBaseOffset;
        if(lengthAndOffset <= threadLocalStack.stackSlots) {
            return false;
        }

        const size_t newStackSlots = threadLocalStack.stackSlots << 1;
        if(lengthAndOffset > newStackSlots) {
            *outReallocSlots = lengthAndOffset + (newStackSlots - (lengthAndOffset % newStackSlots));
        } else {
            *outReallocSlots = newStackSlots;
        }
        return true;
    }
}

static void reallocate_stack(const size_t newCapacity) {
    void* newStackMem = _cubs_os_aligned_malloc(newCapacity * sizeof(size_t), 64);
    uint8_t* newStackTagsMem = _cubs_os_aligned_malloc(newCapacity, 64);

    if(threadLocalStack.stackSlots != 0) {
        memcpy(newStackMem, threadLocalStack.stack, threadLocalStack.stackSlots * sizeof(size_t));
        memcpy((void*)newStackTagsMem, (const void*)threadLocalStack.tags, threadLocalStack.stackSlots);

        _cubs_os_aligned_free((void*)threadLocalStack.stack, threadLocalStack.stackSlots * sizeof(size_t), 64);
        _cubs_os_aligned_free((void*)threadLocalStack.tags, threadLocalStack.stackSlots, 64);
    }

    threadLocalStack.stack = newStackMem;
    threadLocalStack.tags = newStackTagsMem;
}

static void cubs_interpreter_push_frame_impl(size_t frameLength, const Bytecode* oldInstructionPointer, bool returnToPtr, size_t returnValueDst, size_t returnTagDst) {
    size_t reallocateSlots;
    const bool shouldReallocate = should_reallocate(&reallocateSlots, frameLength);
    if(shouldReallocate) {
        reallocate_stack(reallocateSlots);
    }

    { // store previous instruction pointer, frame length, return dst, and return tag dst
        size_t* basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.nextBaseOffset];
        if(threadLocalStack.nextBaseOffset == 0) {
            basePointer[OLD_INSTRUCTION_POINTER]    = 0;
            basePointer[OLD_FRAME_LENGTH]           = 0;
            basePointer[OLD_RETURN_IS_PTR]          = 0;
            basePointer[OLD_RETURN_VALUE_DST]       = 0;
            basePointer[OLD_RETURN_TAG_DST]         = 0;
        } else {
            basePointer[OLD_INSTRUCTION_POINTER]    = (size_t)((const void*)oldInstructionPointer); // cast ptr to size_t
            basePointer[OLD_FRAME_LENGTH]           = threadLocalStack.frame.frameLength;
            basePointer[OLD_FRAME_LENGTH]           = (size_t)threadLocalStack.frame.returnToPtr; // cast bool to size_t
            basePointer[OLD_RETURN_VALUE_DST]       = threadLocalStack.frame.returnValueDst;
            basePointer[OLD_RETURN_TAG_DST]         = threadLocalStack.frame.returnTagDst;
        }
    }

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = frameLength,
        .returnToPtr = returnToPtr,
        .returnValueDst = returnValueDst,
        .returnTagDst = returnTagDst
    };
    threadLocalStack.frame = newFrame;
    threadLocalStack.nextBaseOffset += frameLength + RESERVED_SLOTS;  
}

void cubs_interpreter_push_frame_non_stack_return(size_t frameLength, const Bytecode* oldInstructionPointer, void *returnValueDst, uint8_t *returnTagDst)
{
    cubs_interpreter_push_frame_impl(frameLength, oldInstructionPointer, true, (size_t)returnValueDst, (size_t)returnTagDst);
}

void cubs_interpreter_push_frame_in_stack_return(size_t frameLength, const Bytecode *oldInstructionPointer, size_t returnValueOffset, size_t returnTagOffset)
{  
    cubs_interpreter_push_frame_impl(frameLength, oldInstructionPointer, false, returnValueOffset, returnTagOffset);
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
    const size_t oldReturnIsPtr = basePointer[OLD_RETURN_IS_PTR];
    const size_t oldReturnValueDst = basePointer[OLD_RETURN_VALUE_DST];
    const size_t oldReturnTagDst = basePointer[OLD_RETURN_TAG_DST];

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = oldFrameLength,
        .returnToPtr = oldReturnIsPtr,
        .returnValueDst = oldReturnValueDst,
        .returnTagDst = oldReturnTagDst
    };   
    threadLocalStack.frame = newFrame;
}

InterpreterStackFrame cubs_interpreter_current_stack_frame()
{
    return threadLocalStack.frame;
}
