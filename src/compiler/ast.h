#pragma once

#include <stddef.h>
#include "../primitives/string/string_slice.h"
#include "parse/tokenizer.h"

// https://astexplorer.net/

struct CubsProgram;
struct Ast;
struct FunctionBuilder;
struct StackVariablesArray;
struct StackVariablesAssignment;
struct TypeMap;

enum AstNodeType {
    astNodeTypeFile,
    astNodeTypeFunction,
    astNodeTypeReturn,
    astNodeBinaryExpression,
    astNodeVariableDeclaration,
    astNodeVariableAssignment,
    astNodeTypeStruct,
    astNodeTypeMemberVariable,
    astNodeTypeConditional,
    astNodeTypeFunctionArg,
};

typedef void (*AstNodeDeinit)(void* self);
typedef void(*AstNodeCompile)(void* self, struct CubsProgram* program);
typedef CubsStringSlice(*AstNodeToString)(const void* self);
typedef void(*AstNodeBuildFunction)(
    const void* self,
    struct FunctionBuilder* builder,
    const struct StackVariablesAssignment* stackAssignment
);
typedef void(*AstNodeDefineType)(
    const void* self,
    struct CubsProgram* program
);
typedef void(*AstNodeResolveTypes)(
    void* self, struct CubsProgram* program, const struct FunctionBuilder* builder, struct StackVariablesArray* variables
);
typedef bool(*AstNodeStatementsEndWithReturn)(const void* self);

typedef struct AstNodeVTable {
    enum AstNodeType nodeType;
    AstNodeDeinit deinit;
    AstNodeCompile compile;
    AstNodeToString toString;
    AstNodeBuildFunction buildFunction;
    AstNodeDefineType defineType;
    /// Determines all types used by this node, if they have not yet been 
    /// resolved. Takes place after types are defined, but before function
    /// building occurs.
    AstNodeResolveTypes resolveTypes;
    /// Checks if the collection of statements terminate with a return.
    /// This is useful to ensure functions that return values have all
    /// statements terminate with a return statement.
    AstNodeStatementsEndWithReturn endsWithReturn;
} AstNodeVTable;

typedef struct AstNode {
    void* ptr;
    const AstNodeVTable* vtable;
} AstNode;

inline static void ast_node_deinit(AstNode* self) {
    self->vtable->deinit(self->ptr);
}

inline static void ast_node_compile(AstNode* self, struct CubsProgram* program) {
    self->vtable->compile(self->ptr, program);
}

inline static CubsStringSlice ast_node_to_string(const AstNode* self) {
    return self->vtable->toString(self->ptr);
}

inline static void ast_node_build_function(const AstNode* self, struct FunctionBuilder* builder, const struct StackVariablesAssignment* stackAssignments) {
    self->vtable->buildFunction(self->ptr, builder, stackAssignments);
}

inline static void ast_node_define_type(const AstNode* self, struct CubsProgram* program) {
    self->vtable->defineType(self->ptr, program);
}

inline static void ast_node_resolve_types(
    AstNode* self, 
    struct CubsProgram* program, 
    const struct FunctionBuilder* builder, 
    struct StackVariablesArray* variables
) {
    self->vtable->resolveTypes(self->ptr, program, builder, variables);
}

inline static bool ast_node_statements_end_with_return(const AstNode* self) {
    return self->vtable->endsWithReturn(self->ptr);
}

typedef struct Ast {
    struct CubsProgram* program;
    AstNode rootNode;
} Ast;

Ast cubs_ast_init(TokenIter iter, struct CubsProgram* program);

void cubs_ast_deinit(Ast* self);

void cubs_ast_codegen(const Ast* self);

void cubs_ast_print(const Ast* self);
