#pragma once

#include <stdint.h>
#include <stddef.h>
#include "../primitives/string/string.h"

/// Zero initialize.
/// Stores stack positions of all variables within a stack frame
typedef struct StackVariablesAssignment {
    /// Store strings instead of slices because it's possible that dynamically
    /// generated variable names will need to be used. For example, for
    /// temporary values.
    CubsString* names;
    uint16_t* positions;
    size_t len;
    /// How many slots is required to store all of the variables
    /// for this stack frame
    size_t requiredFrameSize;
    size_t capacity;
} StackVariablesAssignment;

void cubs_stack_assignment_deinit(StackVariablesAssignment* self);

/// Takes ownership of `name`.
/// Determines the position of the variable within the stack frame given the size of the type.
/// Returns the position, but can be ignored.
uint16_t cubs_stack_assignment_push(StackVariablesAssignment* self, CubsString name, size_t sizeOfType);

uint16_t cubs_stack_assignment_find(const StackVariablesAssignment* self, const CubsString* name);
