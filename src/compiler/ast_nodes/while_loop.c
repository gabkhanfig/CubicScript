#include "while_loop.h"
#include "../ast.h"
#include "../parse/tokenizer.h"
#include "../stack_variables.h"
#include "../graph/scope.h"
#include "../graph/function_dependency_graph.h"
#include "../../platform/mem.h"
#include "../parse/parse_statements.h"
#include <assert.h>

static void while_loop_node_deinit(WhileLoopNode* self) {
    expr_value_deinit(&self->condition);
    ast_node_array_deinit(&self->statements);
    cubs_scope_deinit(self->scope);
    FREE_TYPE(Scope, self->scope);
    
    *self = (WhileLoopNode){0};
    FREE_TYPE(WhileLoopNode, self);
}

static AstNodeVTable while_loop_node_vtable = {
    .nodeType = astNodeTypeWhileLoop,
    .deinit = (AstNodeDeinit)&while_loop_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = NULL,
    .defineType = NULL,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

struct AstNode cubs_while_loop_node_init(
    TokenIter* iter,
    StackVariablesArray* variables,
    FunctionDependencies* dependencies,
    Scope* outerScope
) {
    assert(iter->current.tag == WHILE_KEYWORD);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == LEFT_PARENTHESES_SYMBOL);
    (void)cubs_token_iter_next(iter);

    const ExprValue condition = cubs_parse_expression(iter, variables, dependencies, false, -1);
    assert(iter->current.tag == RIGHT_PARENTHESES_SYMBOL);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == LEFT_BRACE_SYMBOL);

    Scope* scope = MALLOC_TYPE(Scope);
    *scope = (Scope){
        .isInFunction = outerScope->isInFunction,
        .isSync = outerScope->isSync,
        .optionalParent = outerScope
    };

    AstNodeArray statements = {0};
    {
        AstNode temp = {0};
        // parses until right brace
        while(parse_next_statement(&temp, iter, variables, dependencies, scope)) {
            ast_node_array_push(&statements, temp);
        }
        assert(iter->current.tag == RIGHT_BRACE_SYMBOL);
    }

    WhileLoopNode* self = MALLOC_TYPE(WhileLoopNode);
    *self = (WhileLoopNode){
        .condition = condition,
        .statements = statements,
        .scope = scope
    };

    return (AstNode){.ptr = (void*)self, .vtable = &while_loop_node_vtable};
}