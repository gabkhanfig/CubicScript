#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"

struct StackVariablesArray;

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

/// If `hasDestination` is false, this expression does not "store"
/// the resulting value anywhere.
/// If `hasDestination` is true, this expression stores the resulting
/// value at `destinationVariableIndex`.
/// Returns `false` if no expression could be found, such as immediate semicolon.
/// Returns `true` if the expression is parsed successfully.
/// The `iter` after calling will have the current token be a semicolon always.
bool cubs_parse_expression(
    ExprValue* out,
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
