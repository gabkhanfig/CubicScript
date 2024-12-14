#pragma once

#include <stddef.h>
#include "../primitives/string/string_slice.h"
#include "tokenizer.h"

// https://astexplorer.net/

struct CubsProgram;
struct Ast;
struct FunctionBuilder;
struct StackVariablesAssignment;

enum AstNodeType {
    astNodeTypeFile,
    astNodeTypeFunction,
    astNodeTypeReturn,
};

typedef void (*AstNodeDeinit)(void* self);
typedef void(*AstNodeCompile)(const void* self, struct CubsProgram* program);
typedef CubsStringSlice(*AstNodeToString)(const void* self);
typedef void(*AstNodeBuildFunction)(
    const void* self,
    struct FunctionBuilder* builder,
    const struct StackVariablesAssignment* stackAssignment
);

typedef struct AstNodeVTable {
    enum AstNodeType nodeType;
    AstNodeDeinit deinit;
    AstNodeCompile compile;
    AstNodeToString toString;
    AstNodeBuildFunction buildFunction;
} AstNodeVTable;

typedef struct AstNode {
    void* ptr;
    const AstNodeVTable* vtable;
} AstNode;

inline static void ast_node_deinit(AstNode* self) {
    self->vtable->deinit(self->ptr);
}

inline static void ast_node_compile(const AstNode* self, struct CubsProgram* program) {
    self->vtable->compile(self->ptr, program);
}

inline static CubsStringSlice ast_node_to_string(const AstNode* self) {
    return self->vtable->toString(self->ptr);
}

inline static void ast_node_build_function(const AstNode* self, struct FunctionBuilder* builder, const struct StackVariablesAssignment* stackAssignments) {
    self->vtable->buildFunction(self->ptr, builder, stackAssignments);
}

typedef struct Ast {
    struct CubsProgram* program;
    AstNode rootNode;
} Ast;

Ast cubs_ast_init(TokenIter iter, struct CubsProgram* program);

void cubs_ast_deinit(Ast* self);

void cubs_ast_codegen(const Ast* self);

void cubs_ast_print(const Ast* self);
