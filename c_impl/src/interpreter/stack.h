#pragma once

#include <stddef.h>
#include "../primitives/value_tag.h"

typedef struct InterpreterStackState;

typedef struct {
    void* basePointer;
    uint8_t* tagsBasePointer;
    size_t frameLength;    
    void* returnValueDst;
    uint8_t* returnTagDst;
} InterpreterStackFrame;

void cubs_interpreter_push_frame(size_t frameLength, const uint32_t* newInstructionPointer, void* returnValueDst, uint8_t* returnTagDst);
