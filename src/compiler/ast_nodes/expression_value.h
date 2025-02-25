#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"

struct StackVariablesArray;
struct CubsTypeContext;
struct CubsProgram;
struct FunctionBuilder;
struct FunctionDependencies;
struct StackVariablesAssignment;

struct ExprValueBoolLiteral {
    bool literal;
    size_t variableIndex;
};

struct ExprValueIntLiteral {
    int64_t literal;
    size_t variableIndex;
};

struct ExprValueFloatLiteral {
    double literal;
    size_t variableIndex;
};

struct ExprValueReference {
    /// The index of the source variable, being a reference type.
    size_t sourceVariableIndex;
    /// The index of the temporary, non-owned, dereferenced value.
    size_t tempIndex;
};

union ExprValueMetadata {
    /// Index within the stack variables to find the name of the variable
    size_t variableIndex;
    struct ExprValueReference reference;
    struct ExprValueBoolLiteral boolLiteral;
    struct ExprValueIntLiteral intLiteral;
    struct ExprValueFloatLiteral floatLiteral;
    //double floatLiteral;
    AstNode expression;
    // TODO
    AstNode functionCall;
};

/// Corresponds with `MathValueMetadata`
enum ExprValueType {
    Variable,
    Reference,
    BoolLit,
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
ExprValue cubs_parse_expression(
    TokenIter* iter, 
    struct StackVariablesArray* variables, 
    struct FunctionDependencies* dependencies,
    bool hasDestination, 
    size_t destinationVariableIndex
);

inline static void expr_value_deinit(ExprValue* self) {
    switch(self->tag) {
        case Expression: {
            ast_node_deinit(&self->value.expression);
        } break;
        case FunctionCall: {
            ast_node_deinit(&self->value.functionCall);
        } break;
        default: break;
    }
}

/// Resolves the type of the actual expression value, and returns the type
/// context.
const struct CubsTypeContext* cubs_expr_node_resolve_type(
    ExprValue* self, struct CubsProgram* program, const struct FunctionBuilder* builder, struct StackVariablesArray* variables
);

typedef struct ExprValueDst {
    bool hasDst;
    uint16_t dst;
} ExprValueDst;

ExprValueDst cubs_expr_value_build_function(
    const ExprValue* self,
    struct FunctionBuilder* builder,
    const struct StackVariablesAssignment* stackAssignment
);

void cubs_expr_value_update_destination(ExprValue* self, size_t destinationVariableIndex);