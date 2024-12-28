#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"

union ExprValueMetadata {
    /// Index within the stack variables to find the name of the variable
    size_t variableIndex;
    int64_t intLiteral;
    double floatLiteral;
    AstNode expression;
    // TODO
    void* functionCall;
};

/// Corresponds with `MathValueMetadata`
enum ExprValueType {
    Variable,
    IntLit,
    FloatLit,
    Expression,
    // TODO
    FunctionCall,
};

/// Tagged union
typedef struct ExprValue {
    enum ExprValueType tag;
    union ExprValueMetadata value;
} ExprValue;
