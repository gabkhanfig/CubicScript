#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"

struct StackVariablesArray;

union BinaryExprValueMetadata {
    /// Index within the stack variables to find the name of the variable
    size_t variableIndex;
    int64_t intLiteral;
    double floatLiteral;
    AstNode expression;
    // TODO
    void* functionCall;
};

/// Corresponds with `MathValueMetadata`
enum BinaryExprValueType {
    Variable,
    IntLit,
    FloatLit,
    Expression,
    // TODO
    FunctionCall,
};

/// Tagged union
typedef struct BinaryExprValue {
    enum BinaryExprValueType tag;
    union BinaryExprValueMetadata value;
} BinaryExprValue;

typedef enum BinaryExprOp {
    Add,
} BinaryExprOp;

/// Can have nested binary expression nodes, 
typedef struct BinaryExprNode {
    size_t outputVariableIndex;
    BinaryExprOp operation;
    BinaryExprValue lhs;
    BinaryExprValue rhs;
} BinaryExprNode;

/// `optionalOutputName` can be an empty string, indicating a temporary output variable must be used.
AstNode cubs_binary_expr_node_init(
    struct StackVariablesArray* variables,
    CubsStringSlice optionalOutputName,
    BinaryExprOp operation,
    BinaryExprValue lhs,
    BinaryExprValue rhs
);
