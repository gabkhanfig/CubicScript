#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"
#include "expression_value.h"

struct StackVariablesArray;

typedef enum BinaryExprOp {
    Add,
} BinaryExprOp;

/// Can have nested binary expression nodes, 
typedef struct BinaryExprNode {
    size_t outputVariableIndex;
    BinaryExprOp operation;
    ExprValue lhs;
    ExprValue rhs;
} BinaryExprNode;

/// `optionalOutputName` can be an empty string, indicating a temporary output variable must be used.
AstNode cubs_binary_expr_node_init(
    struct StackVariablesArray* variables,
    CubsStringSlice optionalOutputName,
    BinaryExprOp operation,
    ExprValue lhs,
    ExprValue rhs
);
