#pragma once

#include <stdint.h>
#include <stddef.h>
#include "../primitives/string/string.h"
#include "../primitives/context.h"

typedef struct StackVariableInfo {
    /// Use string instead of slice because this variable name
    /// may need to be generated, such as with a temporary value.
    CubsString name;
    /// May be NULL, indicating that the type info for this variable
    /// has not been fully resolved.
    const CubsTypeContext* context;
    /// The type name found within the source code. For example
    /// `const a: int = ...`, which `taggedName` will hold the slice
    /// `"int"`. If this string is empty, there is no tag.
    CubsStringSlice taggedName;
} StackVariableInfo;

void cubs_stack_variable_info_deinit(StackVariableInfo* self);

typedef struct StackVariablesArray {
    StackVariableInfo* variables;
    size_t len;
    size_t capacity;
} StackVariablesArray;

void cubs_stack_variables_array_deinit(StackVariablesArray* self);

/// Expects `variable` to have a unique name. Returns true if a variable with 
/// the name of `variable.name` does not already exist in the array, otherwise
/// returns false.
bool cubs_stack_variables_array_push(StackVariablesArray* self, StackVariableInfo variable);

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
