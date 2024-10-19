#include "stack.h"
#include "../program/program.h"
#include "value_tag.h"
#include "bytecode.h"
#include "../util/unreachable.h"
#include <assert.h>
#include "../util/context_size_round.h"
#include <string.h>

static bool ptr_is_aligned(const void* p, size_t alignment) {
    return (((uintptr_t)p) % alignment) == 0;
}

typedef struct InterpreterStackState {
    const Bytecode* instructionPointer;
    /// Offset from `stack` and `tags` indicated where the next frame should start
    size_t nextBaseOffset;
    InterpreterStackFrame frame;
    size_t stack[CUBS_STACK_SLOTS];
    uintptr_t contexts[CUBS_STACK_SLOTS];
} InterpreterStackState;

static _Thread_local InterpreterStackState threadLocalStack = {0};

void cubs_interpreter_push_frame(size_t frameLength, void* returnValueDst, const CubsTypeContext** returnContextDst) {
    assert(frameLength <= MAX_FRAME_LENGTH);
    { // store previous instruction pointer, frame length, return dst, and return tag dst
        size_t* basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.nextBaseOffset];
        if(threadLocalStack.nextBaseOffset == 0) {
            basePointer[OLD_INSTRUCTION_POINTER]    = 0;
            basePointer[OLD_FRAME_LENGTH]           = 0;
            basePointer[OLD_RETURN_VALUE_DST]       = 0;
            basePointer[OLD_RETURN_CONTEXT_DST]     = 0;
        } else {
            basePointer[OLD_INSTRUCTION_POINTER]    = (size_t)((const void*)threadLocalStack.instructionPointer); // cast ptr to size_t
            basePointer[OLD_FRAME_LENGTH]           = threadLocalStack.frame.frameLength;
            basePointer[OLD_RETURN_VALUE_DST]       = (size_t)threadLocalStack.frame.returnValueDst;
            basePointer[OLD_RETURN_CONTEXT_DST]     = (size_t)threadLocalStack.frame.returnContextDst;
        }
    }

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = frameLength,
        .returnValueDst = returnValueDst,
        .returnContextDst = returnContextDst
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

    size_t* const basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.frame.basePointerOffset];
    const size_t oldInstructionPointer = basePointer[OLD_INSTRUCTION_POINTER];
    const size_t oldFrameLength = basePointer[OLD_FRAME_LENGTH];
    void* const oldReturnValueDst = (void*)basePointer[OLD_RETURN_VALUE_DST];
    const CubsTypeContext** const oldReturnTagDst = (const CubsTypeContext**)basePointer[OLD_RETURN_CONTEXT_DST];

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset - oldFrameLength - RESERVED_SLOTS,
        .frameLength = oldFrameLength,
        .returnValueDst = oldReturnValueDst,
        .returnContextDst = oldReturnTagDst
    };   
    threadLocalStack.frame = newFrame;
}

InterpreterStackFrame cubs_interpreter_current_stack_frame()
{
    return threadLocalStack.frame;
}

const Bytecode *cubs_interpreter_get_instruction_pointer()
{
    return threadLocalStack.instructionPointer;
}

void *cubs_interpreter_stack_value_at(size_t offset)
{
    assert(offset < threadLocalStack.frame.frameLength);
    return (void*)(&threadLocalStack.stack[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS]);
}

const CubsTypeContext* cubs_interpreter_stack_context_at(size_t offset)
{
    assert(offset < threadLocalStack.frame.frameLength);
    uintptr_t contextPtr = threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS];
    // Mask away the ref tag bit
    const CubsTypeContext* context = (const CubsTypeContext*)(contextPtr & ~(1ULL));
    return context;
}

const CubsTypeContext** cubs_interpreter_stack_context_ptr_at(size_t offset) 
{
    assert(offset < threadLocalStack.frame.frameLength);
    return (const CubsTypeContext**)&threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS];
}

static bool is_owning_context_at(size_t offset) {
    assert(offset < threadLocalStack.frame.frameLength);
    uintptr_t contextPtr = threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS];

    return (contextPtr & 1ULL) == 0;
}

static void stack_set_context_at(size_t offset, const CubsTypeContext* context, bool isReference) {
    _Static_assert(_Alignof(CubsTypeContext) > 1, "Bottom bit needs to be free for internal use");
    assert(ptr_is_aligned(context, _Alignof(CubsTypeContext)));
    assert(offset < threadLocalStack.frame.frameLength);
    assert((offset + context->sizeOfType) < ((threadLocalStack.frame.frameLength + 1) * sizeof(size_t)));

    uintptr_t contextPtr = (uintptr_t)context;
    uintptr_t refTag = (uintptr_t)isReference;
    
    threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS] = contextPtr | refTag;
    if(context->sizeOfType > 8) {
        for(size_t i = 1; i < (context->sizeOfType / 8); i++) {
            threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset  + RESERVED_SLOTS + i] = (uintptr_t)NULL;
        }
    }
}

void cubs_interpreter_stack_unwind_frame() {
    uintptr_t* start = &threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + RESERVED_SLOTS];
    for(size_t i = 0; i < threadLocalStack.frame.frameLength; i++) {
        const CubsTypeContext* context = cubs_interpreter_stack_context_at(i);
        const bool isOwningContext = is_owning_context_at(i);        
        if(context == NULL || !isOwningContext) {
            continue;
        }

        cubs_context_fast_deinit(cubs_interpreter_stack_value_at(i), context);

        // While technically it makes the most sense to set to NULL earlier, since nothing gets executed if the type has no destructor,
        // leaving a previous context for a "dumb" type, such as an integer, is fine.
        cubs_interpreter_stack_set_null_context_at(i); // set context to NULL
    }
}

void cubs_interpreter_stack_set_context_at(size_t offset, const CubsTypeContext* context)
{
    stack_set_context_at(offset, context, false);
}

void cubs_interpreter_stack_set_reference_context_at(size_t offset, const CubsTypeContext *context)
{
    stack_set_context_at(offset, context, true);
}

void cubs_interpreter_stack_set_null_context_at(size_t offset)
{
    threadLocalStack.contexts[threadLocalStack.frame.basePointerOffset + offset + RESERVED_SLOTS] = 0;
}

void cubs_interpreter_set_instruction_pointer(const Bytecode *newIp)
{
    assert(newIp != NULL);
    threadLocalStack.instructionPointer = newIp;
}

void cubs_interpreter_push_script_function_arg(const void *arg, const CubsTypeContext *context, size_t offset)
{
    const size_t actualOffset = threadLocalStack.nextBaseOffset + RESERVED_SLOTS + offset;

    memcpy((void*)&threadLocalStack.stack[actualOffset], arg, context->sizeOfType);
    threadLocalStack.contexts[actualOffset] = (uintptr_t)context;
    if(context->sizeOfType > 8) {
        for(size_t i = 1; i < (context->sizeOfType / 8); i++) {
            threadLocalStack.contexts[actualOffset + i] = (uintptr_t)NULL;
        }
    }
}

void cubs_interpreter_push_c_function_arg(const void* arg, const struct CubsTypeContext* context, size_t offset, size_t currentArgCount, size_t argTrackOffset)
{
    const size_t actualOffset = threadLocalStack.nextBaseOffset + RESERVED_SLOTS + offset;
    // integer division.
    // structs with a size less than or equal to 8 will have the track offset set to +1,
    // otherwise it will be pushed further
    const size_t newArgTrackOffset = actualOffset + 
    (ROUND_SIZE_TO_MULTIPLE_OF_8(context->sizeOfType) / 8);
    if(argTrackOffset > 0) { // with an offset other than 0, it means args have already been pushed.
        const size_t bytesToMove = sizeof(size_t) + (sizeof(size_t) * (1 + (currentArgCount / 4)));
        memmove((void*)&threadLocalStack.stack[newArgTrackOffset], (const void*)&threadLocalStack.stack[threadLocalStack.nextBaseOffset + RESERVED_SLOTS + argTrackOffset], bytesToMove); // `offset`
    }
    
    memcpy((void*)&threadLocalStack.stack[actualOffset], arg, context->sizeOfType);

    threadLocalStack.stack[newArgTrackOffset] = currentArgCount + 1;
    uint16_t* offsetsArrayStart = (uint16_t*)&threadLocalStack.stack[newArgTrackOffset + 1]; // one after the argument count tracker
    offsetsArrayStart[currentArgCount] = offset;

    threadLocalStack.contexts[actualOffset] = (uintptr_t)context;
    if(context->sizeOfType > 8) {
        for(size_t i = 1; i < (context->sizeOfType / 8); i++) {
            threadLocalStack.contexts[actualOffset + i] = (uintptr_t)NULL;
        }
    }
}

CubsFunctionReturn cubs_interpreter_return_dst()
{
    const CubsFunctionReturn ret = {.value = threadLocalStack.frame.returnValueDst, .context = threadLocalStack.frame.returnContextDst};
    return ret;
}

void cubs_function_take_arg(const CubsCFunctionHandler *self, size_t argIndex, void *outArg, const CubsTypeContext **outContext)
{
    assert(outArg != NULL);
    assert(self->argCount > argIndex);

    const size_t startOfArgPositions = self->_frameBaseOffset + RESERVED_SLOTS + (size_t)self->_offsetForArgs + 1; // add one to make room for arg count
    const uint16_t* argPositions = (const uint16_t*)&threadLocalStack.stack[startOfArgPositions];
    const size_t actualArgPosition = argPositions[argIndex];

    const CubsTypeContext* context = cubs_interpreter_stack_context_at(actualArgPosition);
    assert(context != NULL);

    memcpy(outArg, cubs_interpreter_stack_value_at(actualArgPosition), context->sizeOfType);
    cubs_interpreter_stack_set_null_context_at(actualArgPosition);

    if(outContext != NULL) {
        *outContext = context;
    }
}