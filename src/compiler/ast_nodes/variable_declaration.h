#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"
#include "expression_value.h"

struct StackVariablesArray;
struct FunctionDependencies;
struct Scope;

typedef struct VariableDeclarationNode {
    /// Index within the stack variables to find the name of the return value.
    size_t variableNameIndex;
    // If `false`, variable is `const`. If `true`, variable is `mut`.
    bool isMutable;
    ExprValue initialValue;
} VariableDeclarationNode;

AstNode cubs_variable_declaration_node_init(
    TokenIter* iter,
    struct StackVariablesArray* variables,
    struct FunctionDependencies* dependencies,
    struct Scope* outerScope
);
