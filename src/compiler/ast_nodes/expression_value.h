#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"

struct StackVariablesArray;

struct ExprValueIntLiteral {
    int64_t literal;
    size_t variableIndex;
};

union ExprValueMetadata {
    /// Index within the stack variables to find the name of the variable
    size_t variableIndex;
    struct ExprValueIntLiteral intLiteral;
    //double floatLiteral;
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
    /// 
    size_t variableIndex;
} ExprValue;

/// If `hasDestination` is false, this expression does not "store"
/// the resulting value anywhere.
/// If `hasDestination` is true, this expression stores the resulting
/// value at `destinationVariableIndex`.
ExprValue cubs_parse_expression(
    TokenIter* iter, 
    struct StackVariablesArray* variables, 
    bool hasDestination, 
    size_t destinationVariableIndex
);

inline static void expr_value_deinit(ExprValue* self) {
    switch(self->tag) {
        case Expression: {
            ast_node_deinit(&self->value.expression);
        } break;
        default: break;
    }
}
