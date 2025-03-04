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

struct ExprValueStructMemberAccess {
    size_t sourceVariableIndex;
    /// Array of nested member names. Is length `len`.
    /// `variable.member1.member2.member3` for example, where the array
    /// contains the names of those members.
    CubsStringSlice* members;
    /// Array of struct member access destination variables.
    /// The final one is the resulting destination for the entire expression.
    size_t* destinations;
    size_t len;
};

struct ExprValueReference {
    /// The index of the source variable, being a reference type.
    size_t sourceVariableIndex;
    /// The index of the temporary, non-owned, dereferenced value.
    size_t tempIndex;
};

struct ExprValueMakeReference {
    /// The index of the source variable, being a non-reference type.
    size_t sourceVariableIndex;
    /// The index of the new, reference typed value.
    size_t destinationIndex;
    bool mutable;
};

union ExprValueMetadata {
    /// Index within the stack variables to find the name of the variable
    size_t variableIndex;
    struct ExprValueReference reference;
    struct ExprValueMakeReference makeReference;
    struct ExprValueBoolLiteral boolLiteral;
    struct ExprValueIntLiteral intLiteral;
    struct ExprValueFloatLiteral floatLiteral;
    //double floatLiteral;
    AstNode expression;
    AstNode functionCall;
    AstNode structMember;
};

/// Corresponds with `MathValueMetadata`
enum ExprValueType {
    Variable,
    Reference,
    MakeReference,
    BoolLit,
    IntLit,
    FloatLit,
    Expression,
    // TODO
    FunctionCall,
    StructMember,
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
        case StructMember: {
            ast_node_deinit(&self->value.structMember);
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