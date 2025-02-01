#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"
#include "expression_value.h"

struct StackVariablesArray;

typedef enum BinaryExprOp {
    Add,
    Equal,
} BinaryExprOp;

/// Can have nested binary expression nodes, 
typedef struct BinaryExprNode {
    size_t outputVariableIndex;
    BinaryExprOp operation;
    ExprValue lhs;
    ExprValue rhs;
} BinaryExprNode;

/// A binary expression will already have a pre-known destination
AstNode cubs_binary_expr_node_init(
    struct StackVariablesArray* variables,
    size_t outputVariableIndex,
    BinaryExprOp operation,
    ExprValue lhs,
    ExprValue rhs
);
