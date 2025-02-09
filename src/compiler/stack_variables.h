#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "../primitives/string/string.h"
#include "../primitives/context.h"
#include "ast_nodes/type_resolution_info.h"

typedef struct StackVariableInfo {
    /// Use string instead of slice because this variable name
    /// may need to be generated, such as with a temporary value.
    /// The name may also change with temporary values, depending on
    /// `isTemporary`.
    CubsString name;
    /// If this is a temporary variable, `name` is allowed to be mutated freely
    bool isTemporary;
    bool isMutable;
    TypeResolutionInfo typeInfo;
} StackVariableInfo;

void cubs_stack_variable_info_deinit(StackVariableInfo* self);

typedef struct StackVariablesArray {
    StackVariableInfo* variables;
    size_t len;
    size_t capacity;
} StackVariablesArray;

void cubs_stack_variables_array_deinit(StackVariablesArray* self);

/// Takes ownership of `variable`. 
/// Expects `variable` to have a unique name. Returns true if a variable with 
/// the name of `variable.name` does not already exist in the array, otherwise
/// returns false.
/// Will mutate any existing temporary variables if the name already exists.
/// # Debug Asserts
/// `variable.isTemporary == false`
bool cubs_stack_variables_array_push(StackVariablesArray* self, StackVariableInfo variable);

/// Takes ownership of `variable`.
/// If a variable with the name `variable.name` already exists, `variable.name`
/// will be mutated until it doesn't exist already.
/// # Debug Asserts
/// `variable.isTemporary == true`
void cubs_stack_variables_array_push_temporary(StackVariablesArray* self, StackVariableInfo variable);

bool cubs_stack_variables_array_find(const StackVariablesArray* self, size_t* outIndex, CubsStringSlice name);

/// Zero initialize.
/// Stores stack positions of all variables within a stack frame
typedef struct StackVariablesAssignment {
    /// Store strings instead of slices because it's possible that dynamically
    /// generated variable names will need to be used. For example, for
    /// temporary values.
    CubsStringSlice* names;
    uint16_t* positions;
    size_t len;
    /// How many slots is required to store all of the variables
    /// for this stack frame
    size_t requiredFrameSize;
    size_t capacity;
} StackVariablesAssignment;

StackVariablesAssignment cubs_stack_assignment_init(const StackVariablesArray* variables);

void cubs_stack_assignment_deinit(StackVariablesAssignment* self);

/// Takes ownership of `name`. Determines the position of the variable within
/// the stack frame given the size of the type. Expect `name` to be unique.
/// Returns true if a variable within the stack assignments does not already
/// exist, otherwise returns false.
bool cubs_stack_assignment_push(StackVariablesAssignment* self, CubsStringSlice name, size_t sizeOfType);

uint16_t cubs_stack_assignment_find(const StackVariablesAssignment* self, CubsStringSlice name);
