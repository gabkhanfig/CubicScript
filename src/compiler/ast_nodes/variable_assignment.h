#ifndef VARIABLE_ASSIGNMENT_H
#define VARIABLE_ASSIGNMENT_H

#include "../../c_basic_types.h"
#include "expression_value.h"

struct AstNode;
struct TokenIter;
struct StackVariablesArray;

typedef struct VariableAssignmentNode {
    /// Index within the stack variables to find the name of the return value.
    size_t variableIndex;
    ExprValue newValue;
} VariableAssignmentNode;

struct AstNode cubs_variable_assignment_node_init(struct TokenIter* iter, struct StackVariablesArray* variables);

#endif