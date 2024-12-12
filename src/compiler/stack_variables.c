#include "stack_variables.h"
#include "../platform/mem.h"
#include <assert.h>

void cubs_stack_assignment_deinit(StackVariablesAssignment *self)
{
    for(size_t i = 0; i < self->len; i++) {
        cubs_string_deinit(&self->names[i]);
    }

    if(self->capacity > 0) {
        assert(self->names != NULL);
        assert(self->positions != NULL);

        cubs_free((void*)self->names, self->capacity * sizeof(CubsString), _Alignof(CubsString));
        cubs_free((void*)self->positions, self->capacity * sizeof(uint16_t), _Alignof(uint16_t));
    }

    *self = (StackVariablesAssignment){0};
}

uint16_t cubs_stack_assignment_push(StackVariablesAssignment *self, CubsString name, size_t sizeOfType)
{
    assert(self->requiredFrameSize < UINT16_MAX);
    const uint16_t position = (uint16_t)self->requiredFrameSize;

    size_t slotsForVariable = 1;
    if(sizeOfType > 8) {
        for(size_t i = 1; i < (sizeOfType / 8); i++) {
            slotsForVariable++; // TODO probably could do this in a one liner
        }
    }
    
    self->requiredFrameSize += slotsForVariable;
    assert(self->requiredFrameSize <= UINT16_MAX);

    if(self->len == self->capacity) {
        const size_t newCapacity = self->capacity == 0 ? 2 : self->capacity << 1;

        CubsString* newNames = (CubsString*)cubs_malloc(newCapacity * sizeof(CubsString), _Alignof(CubsString));
        uint16_t* newPositions = (uint16_t*)cubs_malloc(newCapacity * sizeof(uint16_t), _Alignof(uint16_t));

        if(self->names != NULL) {
            assert(self->positions != NULL);

            for(uint32_t i = 0; i < self->len; i++) {
                newNames[i] = self->names[i];
                newPositions[i] = self->positions[i];
            }

            cubs_free((void*)self->names, self->capacity * sizeof(CubsString), _Alignof(CubsString));
            cubs_free((void*)self->positions, self->capacity * sizeof(uint16_t), _Alignof(uint16_t));
        } else {
            // Validation
            assert(self->positions == NULL);
        }

        self->names = newNames;
        self->positions = newPositions;
    }

    self->names[self->len] = name;
    self->positions[self->len] = position;
    self->len += 1;

    return position;
}

uint16_t cubs_stack_assignment_find(const StackVariablesAssignment *self, const CubsString *name)
{
    // TODO does this need optimization?

    for(size_t i = 0; i < self->len; i++) {
        if(cubs_string_eql(&self->names[i], name)) {
            return self->positions[i];
        }
    }

    assert(false && "Failed to find variable in stack assignment");
    return 0;
}
