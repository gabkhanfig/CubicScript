#include "stack_variables.h"
#include "../platform/mem.h"
#include <assert.h>
#include <stdio.h>

void cubs_stack_variable_info_deinit(StackVariableInfo *self)
{
    cubs_string_deinit(&self->name);
    *self = (StackVariableInfo){0};
}

void cubs_stack_variables_array_deinit(StackVariablesArray *self)
{    
    for(size_t i = 0; i < self->len; i++) {
        cubs_stack_variable_info_deinit(&self->variables[i]);
    }

     if(self->capacity > 0) {
        assert(self->variables != NULL);
        cubs_free((void*)self->variables, self->capacity * sizeof(StackVariableInfo), _Alignof(StackVariableInfo));
    }

    *self = (StackVariablesArray){0};
}

static bool is_variable_in_array(const StackVariablesArray* self, const StackVariableInfo* variable) {
    for(size_t i = 0; i < self->len; i++) {
        if(cubs_string_eql(&self->variables[i].name, &variable->name)) {
            return true;
        }
    }
    return false;
}

/// Ensure array has capacity for one more
static void ensure_array_capacity_add_one(StackVariablesArray *self) {
    if(self->len < self->capacity) {
        return;
    }

    const size_t newCapacity = self->capacity == 0 ? 2 : self->capacity << 1;

    StackVariableInfo* newVariables = (StackVariableInfo*)cubs_malloc(sizeof(StackVariableInfo) * newCapacity, _Alignof(StackVariableInfo));
    if(self->variables != NULL) {
        for(size_t i = 0; i < self->len; i++) {
            newVariables[i] = self->variables[i];
        }
        cubs_free((void*)self->variables, sizeof(StackVariableInfo) * self->capacity, _Alignof(StackVariableInfo));
    }
    self->variables = newVariables;
    self->capacity = newCapacity;
}

bool cubs_stack_variables_array_push(StackVariablesArray *self, StackVariableInfo variable)
{
    assert(!variable.isTemporary);

    // TODO mutate temporary if duplicate of temporary

    if(is_variable_in_array(self, &variable)) {
        cubs_stack_variable_info_deinit(&variable);
        return false;
    }

    ensure_array_capacity_add_one(self);
    
    self->variables[self->len] = variable;
    self->len += 1;
    return true;
}

void cubs_stack_variables_array_push_temporary(StackVariablesArray *self, StackVariableInfo variable)
{
    assert(variable.isTemporary);

    while(is_variable_in_array(self, &variable)) {
        // Come up with smarter method other than appending underscores
        const CubsStringSlice appending = {.str = "_", .len = 1};
        const CubsString temp = cubs_string_concat_slice_unchecked(&variable.name, appending);
        cubs_string_deinit(&variable.name);
        variable.name = temp;
    }

    ensure_array_capacity_add_one(self);
    
    self->variables[self->len] = variable;
    self->len += 1;
}

StackVariablesAssignment cubs_stack_assignment_init(const StackVariablesArray *variables)
{
    StackVariablesAssignment self = {0};
    for(size_t i = 0; i < variables->len; i++) {
        const StackVariableInfo* info = &variables->variables[i];
        assert(info->context != NULL);
        const CubsStringSlice slice = cubs_string_as_slice(&info->name);
        const bool success = cubs_stack_assignment_push(&self, slice, info->context->sizeOfType);
        assert(success);
    }
    return self;
}

void cubs_stack_assignment_deinit(StackVariablesAssignment *self)
{
    if(self->capacity > 0) {
        assert(self->names != NULL);
        assert(self->positions != NULL);

        cubs_free((void*)self->names, self->capacity * sizeof(CubsStringSlice), _Alignof(CubsStringSlice));
        cubs_free((void*)self->positions, self->capacity * sizeof(uint16_t), _Alignof(uint16_t));
    }

    *self = (StackVariablesAssignment){0};
}

static bool slices_eql(CubsStringSlice lhs, CubsStringSlice rhs) {
    if(lhs.len != rhs.len) {
        return false;
    }

    for(size_t i = 0; i < lhs.len; i++) {
        if(lhs.str[i] != rhs.str[i]) {
            return false;
        }
    }

    return true;
}

bool cubs_stack_assignment_push(StackVariablesAssignment *self, CubsStringSlice name, size_t sizeOfType)
{
    for(size_t i = 0; i < self->len; i++) {
        if(slices_eql(self->names[i], name)) {
            return false;
        }
    }

    if(self->requiredFrameSize >= UINT16_MAX) { //TODO fix to actual maximum size
        return false;
    }

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

        CubsStringSlice* newNames = (CubsStringSlice*)cubs_malloc(newCapacity * sizeof(CubsStringSlice), _Alignof(CubsStringSlice));
        uint16_t* newPositions = (uint16_t*)cubs_malloc(newCapacity * sizeof(uint16_t), _Alignof(uint16_t));

        if(self->names != NULL) {
            assert(self->positions != NULL);

            for(uint32_t i = 0; i < self->len; i++) {
                newNames[i] = self->names[i];
                newPositions[i] = self->positions[i];
            }

            cubs_free((void*)self->names, self->capacity * sizeof(CubsStringSlice), _Alignof(CubsStringSlice));
            cubs_free((void*)self->positions, self->capacity * sizeof(uint16_t), _Alignof(uint16_t));
        } else {
            // Validation
            assert(self->positions == NULL);
        }

        self->names = newNames;
        self->positions = newPositions;
        self->capacity = newCapacity;
    }

    self->names[self->len] = name;
    self->positions[self->len] = position;
    self->len += 1;

    return true;
}

uint16_t cubs_stack_assignment_find(const StackVariablesAssignment *self, CubsStringSlice name)
{
    // TODO does this need optimization?

    for(size_t i = 0; i < self->len; i++) {
        if(slices_eql(self->names[i], name)) {
            return self->positions[i];
        }
    }

    assert(false && "Failed to find variable in stack assignment");
    return 0;
}
