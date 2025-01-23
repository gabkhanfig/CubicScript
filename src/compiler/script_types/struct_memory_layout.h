#ifndef STRUCT_MEMORY_LAYOUT_H
#define STRUCT_MEMORY_LAYOUT_H

#include <stddef.h>
#include <assert.h>
#include <stdio.h>
#include "../../primitives/context.h"

/// Zero initialize.
/// Works similar to an iterator, allowing you to get the next byte offset
/// of a new member variable within a struct. Script structs should use the 
/// same memory layout as C structs for simplicity.
typedef struct StructMemoryLayout {
    size_t currentMemberOffset;
    size_t currentMemberSize;
    size_t currentMemberAlign;
    size_t structAlign;
    size_t structSize;
} StructMemoryLayout;

static inline size_t struct_memory_layout_next(StructMemoryLayout* self, const CubsTypeContext* context) {
    const size_t MAX_TYPE_ALIGN = 8;
    
    assert(context->sizeOfType > 0);

    // TODO handle user defined alignment
    size_t align = context->sizeOfType;
    if(align > MAX_TYPE_ALIGN) align = MAX_TYPE_ALIGN;

    // First member
    if(self->currentMemberAlign == 0) {
        self->currentMemberOffset = 0;
        self->currentMemberSize = context->sizeOfType;
        self->currentMemberAlign = align;
        self->structAlign = align;
        self->structSize = context->sizeOfType;
        return 0;
    }

    // Update the alignment of the struct itself
    if(align > self->structAlign) {
        self->structAlign = align;
    }

    self->structSize += context->sizeOfType;
    if((self->structSize % self->structAlign) != 0) {
        self->structSize += self->structAlign - (self->structSize % self->structAlign);
    }

    self->currentMemberOffset += self->currentMemberSize;
    if((self->currentMemberOffset % align) != 0) {
        self->currentMemberOffset += align - (self->currentMemberOffset % align);
    }
    
    self->currentMemberSize = context->sizeOfType;
    self->currentMemberAlign = align;
    
    return self->currentMemberOffset;
}

#endif