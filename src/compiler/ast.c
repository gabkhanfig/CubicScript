#include "ast.h"
#include <stdio.h>
#include "../program/program.h"
#include "../program/program_internal.h"
#include "ast_nodes/file_node.h"

Ast cubs_ast_init(TokenIter iter, CubsProgram* program)
{
    const Ast ast = {
        .program = program,
        .rootNode = cubs_file_node_init(&iter),
    };
    return ast;
}

void cubs_ast_deinit(Ast *self)
{
    ast_node_deinit(&self->rootNode);
}

void cubs_ast_codegen(const Ast *self)
{
}

void cubs_ast_print(const Ast *self)
{
}
