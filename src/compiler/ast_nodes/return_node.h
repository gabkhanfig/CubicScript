#pragma once

#include "../ast.h"
#include "../../primitives/string/string.h"
#include "expression_value.h"

struct StackVariablesArray;

typedef struct ReturnNode {
    bool hasReturn;
    /// Should only be used if `hasReturn` is true
    ExprValue retValue;
    /// Index within the stack variables to find the name of the return value.
    //size_t variableNameIndex;
} ReturnNode;

AstNode cubs_return_node_init(TokenIter* iter, struct StackVariablesArray* variables);

AstNode cubs_return_node_init_empty();
