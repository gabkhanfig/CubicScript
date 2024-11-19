#include "ast.h"
#include <stdio.h>
#include "../program/program.h"
#include "../program/program_internal.h"

Ast cubs_ast_init(TokenIter iter, CubsProgram* program)
{
    Ast ast = {.program = program};
    return ast;
}

void cubs_ast_deinit(Ast *self)
{
}

void cubs_ast_codegen(const Ast *self)
{
}

void cubs_ast_print(const Ast *self)
{
}
