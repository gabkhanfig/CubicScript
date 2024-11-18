#pragma once

#include <stddef.h>
#include "../primitives/string/string_slice.h"

struct CubsProgram;
struct Ast;

typedef size_t(*AstNodeProcess)(const void* self, struct CubsProgram* program);
typedef CubsStringSlice(*AstNodeToString)(const void* self);

typedef struct AstNodeVTable {
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
