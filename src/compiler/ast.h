#pragma once

#include <stddef.h>
#include "../primitives/string/string_slice.h"
#include "tokenizer.h"

struct CubsProgram;
struct Ast;

typedef void (*AstNodeDeinit)(void* self);
typedef size_t(*AstNodeProcess)(const void* self, struct CubsProgram* program);
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

typedef struct Ast {
    struct CubsProgram* program;
} Ast;

Ast cubs_ast_init(TokenIter iter, struct CubsProgram* program);

void cubs_ast_deinit(Ast* self);

void cubs_ast_codegen(const Ast* self);

void cubs_ast_print(const Ast* self);
