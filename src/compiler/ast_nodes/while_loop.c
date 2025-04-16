#include "while_loop.h"
#include "../ast.h"
#include "../parse/tokenizer.h"
#include "../stack_variables.h"
#include "../graph/scope.h"
#include "../graph/function_dependency_graph.h"
#include "../../platform/mem.h"
#include "../parse/parse_statements.h"
#include "../../interpreter/function_definition.h"
#include "../../interpreter/bytecode_array.h"
#include "../../interpreter/operations.h"
#include "../../interpreter/bytecode.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include <assert.h>

static void while_loop_node_deinit(WhileLoopNode* self) {
    expr_value_deinit(&self->condition);
    ast_node_array_deinit(&self->statements);
    cubs_scope_deinit(self->scope);
    FREE_TYPE(Scope, self->scope);
    
    *self = (WhileLoopNode){0};
    FREE_TYPE(WhileLoopNode, self);
}

static void while_loop_node_build_function(
    const WhileLoopNode* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {
    const size_t loopCheckStart = builder->bytecodeLen;
    size_t tempJumpIndex = -1;
    { // condition and jump
        const ExprValueDst dst = cubs_expr_value_build_function(&self->condition, builder, stackAssignment);
        assert(dst.hasDst);

        const Bytecode tempJumpBytecode = cubs_operands_make_jump(
            JUMP_TYPE_IF_FALSE, INT32_MAX, dst.dst);
        tempJumpIndex = builder->bytecodeLen;
        cubs_function_builder_push_bytecode(builder, tempJumpBytecode);
    }
    { // statements
        for(size_t statementIter = 0; statementIter < self->statements.len; statementIter++) {
            const AstNode node = self->statements.nodes[statementIter];
            // TODO allow nodes that don't just do code gen, such as nested structs maybe? or lambdas? to determine
            assert(node.vtable->buildFunction != NULL);
            ast_node_build_function(&node, builder, stackAssignment);
        }       
    }
    { // jump back to start of loop
        const int32_t jumpOffset = ((int32_t)loopCheckStart) - ((int32_t)builder->bytecodeLen);
        assert(jumpOffset < 0);
        const Bytecode jumpToLoopCheck = cubs_operands_make_jump(
            JUMP_TYPE_DEFAULT, jumpOffset, 0); 
    }
    { // set jump to after loop body finishes if condition is false
        const int32_t jumpOffset = ((int32_t)builder->bytecodeLen) - ((int32_t)tempJumpIndex);
        assert(jumpOffset > 0);
        OperandsJump jumpOperands = *(const OperandsJump*)&builder->bytecode[tempJumpIndex];
        jumpOperands.jumpAmount = jumpOffset;
    }
}

static void while_loop_node_resolve_types(
    WhileLoopNode* self, 
    CubsProgram* program, 
    const FunctionBuilder* builder, 
    StackVariablesArray* variables, 
    const Scope* scope
) {
    const CubsTypeContext* conditionContext = 
        cubs_expr_node_resolve_type(&self->condition, program, builder, variables, scope);
    assert(conditionContext == &CUBS_BOOL_CONTEXT);

    for(uint32_t statementIter = 0; statementIter < self->statements.len; statementIter++) {
        AstNode* node = &self->statements.nodes[statementIter];
        if(node->vtable->resolveTypes == NULL) continue;

        ast_node_resolve_types(node, program, builder, variables, scope);
    }
}

static bool while_loop_node_statements_ends_with_return(const WhileLoopNode* self) {
    if(self->statements.nodes[self->statements.len - 1].vtable->nodeType != astNodeTypeReturn) {
        return false;
    }
    return true;
}

static AstNodeVTable while_loop_node_vtable = {
    .nodeType = astNodeTypeWhileLoop,
    .deinit = (AstNodeDeinit)&while_loop_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&while_loop_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&while_loop_node_resolve_types,
    .endsWithReturn = (AstNodeStatementsEndWithReturn)&while_loop_node_statements_ends_with_return,
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