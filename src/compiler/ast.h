#pragma once

#include <stddef.h>
#include "../primitives/string/string_slice.h"
#include "tokenizer.h"

// https://astexplorer.net/

struct CubsProgram;
struct Ast;

typedef void (*AstNodeDeinit)(void* self);
typedef void(*AstNodeProcess)(const void* self, struct CubsProgram* program);
typedef CubsStringSlice(*AstNodeToString)(const void* self);

typedef struct AstNodeVTable {
    AstNodeDeinit deinit;
    AstNodeProcess process;
    AstNodeToString toString;
} AstNodeVTable;

typedef struct AstNode {
    void* ptr;
    const AstNodeVTable* vtable;
} AstNode;

inline static void ast_node_deinit(AstNode* self) {
    self->vtable->deinit(self->ptr);
}

inline static void ast_node_process(const AstNode* self, struct CubsProgram* program) {
    self->vtable->process(self->ptr, program);
}

inline static CubsStringSlice ast_node_to_string(const AstNode* self) {
    return self->vtable->toString(self->ptr);
}

typedef struct Ast {
    struct CubsProgram* program;
    AstNode rootNode;
} Ast;

Ast cubs_ast_init(TokenIter iter, struct CubsProgram* program);

void cubs_ast_deinit(Ast* self);

void cubs_ast_codegen(const Ast* self);

void cubs_ast_print(const Ast* self);
