#include "conditional_node.h"
#include "../../platform/mem.h"
#include "../ast.h"
#include "../stack_variables.h"
#include "../parse/tokenizer.h"
#include "ast_node_array.h"
#include "expression_value.h"
#include "../../interpreter/function_definition.h"
#include <assert.h>
#include "../parse/parse_statements.h"
#include <string.h>
#include "../../interpreter/bytecode_array.h"
#include "../../interpreter/operations.h"
#include "../../interpreter/bytecode.h"
#include "binary_expression.h"
#include "function_call.h"
#include "../graph/function_dependency_graph.h"
#include "../graph/scope.h"

static bool conditional_node_has_final_else_branch(const ConditionalNode* self) {
    return self->conditionsLen == (self->blocksLen - 1);
}

static void conditional_node_deinit(ConditionalNode* self) {
    for(size_t i = 0; i < self->conditionsLen; i++) {
        expr_value_deinit(&self->conditions[i]);
    }
    for(size_t i = 0; i < self->blocksLen; i++) {
        ast_node_array_deinit(&self->statementBlocks[i]);
    }

    FREE_TYPE_ARRAY(ExprValue, self->conditions, self->capacity);
    FREE_TYPE_ARRAY(AstNodeArray, self->statementBlocks, self->capacity);
    cubs_scope_deinit(self->scope);
    FREE_TYPE(Scope, self->scope);
    *self = (ConditionalNode){0};

    FREE_TYPE(ConditionalNode, self);
}

static void conditional_node_build_function(
    const ConditionalNode* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {
    // Contains the indices of every bytecode corresponding to a "jump" instruction
    // that this conditional node occupies. Add 1 to also track the start of
    // where instructions continue after the if statements.
    size_t* ifEndJumps = MALLOC_TYPE_ARRAY(size_t, self->blocksLen);
    size_t ifEndJumpsIter = 0;

    const Bytecode emptyBytecode = {0};

    assert(self->blocksLen >= self->conditionsLen);
    for(size_t i = 0; i < self->conditionsLen; i++) {
        const ExprValue conditionValue = self->conditions[i];

        const ExprValueDst dst = cubs_expr_value_build_function(&conditionValue, builder, stackAssignment);
        assert(dst.hasDst);

        const Bytecode tempJumpBytecode = cubs_operands_make_jump(
            JUMP_TYPE_IF_FALSE, INT32_MAX, dst.dst);
        const size_t tempJumpIndex = builder->bytecodeLen;
        cubs_function_builder_push_bytecode(builder, tempJumpBytecode);

        const AstNodeArray* statements = &self->statementBlocks[i];
        for(size_t statementIter = 0; statementIter < statements->len; statementIter++) {
            const AstNode node = statements->nodes[statementIter];
            // TODO allow nodes that don't just do code gen, such as nested structs maybe? or lambdas? to determine
            assert(node.vtable->buildFunction != NULL);
            ast_node_build_function(&node, builder, stackAssignment);
        }

        { // insert unconditional jump at the end to escape to the non-conditional instructions
            ifEndJumps[ifEndJumpsIter] = builder->bytecodeLen;
            ifEndJumpsIter += 1;
            // Later on, the correct jump offset will be set
            cubs_function_builder_push_bytecode(builder, emptyBytecode);
        }
        { // set the conditional jump destination. Will always work to go to either
          // else if, else, or escape the conditionals entirely.

            const size_t jumpOffset = builder->bytecodeLen - tempJumpIndex;
            OperandsJump jumpOperands = *(const OperandsJump*)&builder->bytecode[tempJumpIndex];
            jumpOperands.jumpAmount = (int32_t)jumpOffset;
            builder->bytecode[tempJumpIndex] = *(const Bytecode*)&jumpOperands;
        }
    }

    // Handle case with an `else` without a condition
    if(conditional_node_has_final_else_branch(self)) {
        const AstNodeArray* statements = &self->statementBlocks[self->blocksLen - 1];
        for(size_t statementIter = 0; statementIter < statements->len; statementIter++) {
            const AstNode node = statements->nodes[statementIter];
            // TODO allow nodes that don't just do code gen, such as nested structs maybe? or lambdas? to determine
            assert(node.vtable->buildFunction != NULL);
            ast_node_build_function(&node, builder, stackAssignment);
        }

        // Don't need end jump, as the interpreter will implicitly go after the
        // else provided there isn't a return
    }

    for(size_t i = 0; i < ifEndJumpsIter; i++) {
        const size_t jumpOffset = builder->bytecodeLen - ifEndJumps[i];
        const Bytecode jumpOperands = cubs_operands_make_jump(
            JUMP_TYPE_DEFAULT, (int32_t)jumpOffset, 0);
        builder->bytecode[ifEndJumps[i]] = jumpOperands;
    }

    FREE_TYPE_ARRAY(size_t, ifEndJumps, self->blocksLen);
}

static void conditional_node_resolve_types(
    ConditionalNode* self, CubsProgram* program, const FunctionBuilder* builder, StackVariablesArray* variables, const Scope* scope
) {
    // conditions first
    for(size_t i = 0; i < self->conditionsLen; i++) {
        ExprValue* conditionExpr = &self->conditions[i];
        const CubsTypeContext* conditionContext = 
            cubs_expr_node_resolve_type(conditionExpr, program, builder, variables, scope);
        assert(conditionContext == &CUBS_BOOL_CONTEXT);
    }

    // statements
    for(size_t i = 0; i < self->blocksLen; i++) {
        AstNodeArray* statements = &self->statementBlocks[i];
        for(uint32_t statementIter = 0; statementIter < statements->len; statementIter++) {
            AstNode* node = &statements->nodes[statementIter];
            if(node->vtable->resolveTypes == NULL) continue;

            ast_node_resolve_types(node, program, builder, variables, scope);
        }
    }
}

static bool conditional_node_statements_ends_with_return(const ConditionalNode* self) {
    bool allEndWithReturn = true;
    for(size_t i = 0; i > self->blocksLen; i++) {
        const AstNodeArray* statements = self->statementBlocks;
        const AstNode* lastNode = &statements->nodes[statements->len - 1];
        if(lastNode->vtable->nodeType != astNodeTypeReturn) {
            allEndWithReturn = false;
            break;
        }
    }
    return allEndWithReturn;
}

static AstNodeVTable conditional_node_vtable = {
    .nodeType = astNodeTypeConditional,
    .deinit = (AstNodeDeinit)&conditional_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&conditional_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&conditional_node_resolve_types,
    .endsWithReturn = (AstNodeStatementsEndWithReturn)&conditional_node_statements_ends_with_return,
};

AstNode cubs_conditional_node_init(TokenIter *iter, StackVariablesArray *variables, FunctionDependencies* dependencies, Scope* outerScope)
{
    assert(iter->current.tag == IF_KEYWORD);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == LEFT_PARENTHESES_SYMBOL);
    (void)cubs_token_iter_next(iter);

    const ExprValue firstIfCondition = cubs_parse_expression(iter, variables, dependencies, false, -1);
    assert(iter->current.tag == RIGHT_PARENTHESES_SYMBOL);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == LEFT_BRACE_SYMBOL);

    ConditionalNode* self = MALLOC_TYPE(ConditionalNode);
    *self = (ConditionalNode){0};
    self->scope = MALLOC_TYPE(Scope);
    *self->scope = (Scope){
        .isInFunction = outerScope->isInFunction,
        .isSync = outerScope->isSync,
        .optionalParent = outerScope
    };

    AstNodeArray firstIfStatements = {0};
    {
        AstNode temp = {0};
        // parses until right brace
        while(parse_next_statement(&temp, iter, variables, dependencies, self->scope)) {
            ast_node_array_push(&firstIfStatements, temp);
        }
    }

    // check for else
    TokenType peekNext = cubs_token_iter_peek(iter);
    if(peekNext != ELSE_KEYWORD) {
        self->conditions = MALLOC_TYPE_ARRAY(ExprValue, 1);
        self->conditionsLen = 1;
        self->statementBlocks = MALLOC_TYPE_ARRAY(AstNodeArray, 1);
        self->blocksLen = 1;
        self->capacity = 1;

        self->conditions[0] = firstIfCondition;
        self->statementBlocks[0] = firstIfStatements;

        const AstNode node = {.ptr = (void*)self, .vtable = &conditional_node_vtable};
        return node;
    } else {
        { // initial allocation
            self->conditions = MALLOC_TYPE_ARRAY(ExprValue, 2);
            self->statementBlocks = MALLOC_TYPE_ARRAY(AstNodeArray, 2);
            self->capacity = 2;

            self->conditionsLen = 1;
            self->blocksLen = 1;
            self->conditions[0] = firstIfCondition;
            self->statementBlocks[0] = firstIfStatements;
        }

        // TODO computing twice. inefficient
        (void)cubs_token_iter_next(iter); // is now ELSE_KEYWORD

        bool elseWithoutCondition = false;

        while(peekNext == ELSE_KEYWORD) {
            assert(elseWithoutCondition == false && "Already encounted final else block of conditional");

            const TokenType tokenAfterElse = cubs_token_iter_next(iter);
            ExprValue elseIfCondition = {0};
            if(tokenAfterElse == LEFT_BRACE_SYMBOL) {
                elseWithoutCondition = true;
            } else if(tokenAfterElse == IF_KEYWORD) {
                (void)cubs_token_iter_next(iter);
                assert(iter->current.tag == LEFT_PARENTHESES_SYMBOL);

                // step over to actual expression
                (void)cubs_token_iter_next(iter);

                elseIfCondition = cubs_parse_expression(iter, variables, dependencies, false, -1);
                assert(iter->current.tag == RIGHT_PARENTHESES_SYMBOL);

                (void)cubs_token_iter_next(iter);
                assert(iter->current.tag == LEFT_BRACE_SYMBOL);
            } else {
                assert(false && "Expected '{' or 'if' after 'else'");
            }
         
            AstNodeArray elseStatements = {0};
            {
                AstNode temp = {0};
                // parses until right brace
                while(parse_next_statement(&temp, iter, variables, dependencies, self->scope)) {
                    ast_node_array_push(&elseStatements, temp);
                }
            }

            assert(self->capacity != 0);
            assert(self->conditions != NULL);
            assert(self->statementBlocks != NULL);
            assert(self->conditionsLen != 0);
            assert(self->blocksLen != 0);
            assert(self->conditionsLen == self->blocksLen);
            if(self->conditionsLen == self->capacity) {
                const size_t newCapacity = self->capacity * 2;
                ExprValue* newConditions = MALLOC_TYPE_ARRAY(ExprValue, newCapacity);
                AstNodeArray* newStatements = MALLOC_TYPE_ARRAY(AstNodeArray, newCapacity);

                memcpy(newConditions, self->conditions, sizeof(ExprValue) * self->conditionsLen);
                memcpy(newStatements, self->statementBlocks, sizeof(AstNodeArray) * self->blocksLen);

                FREE_TYPE_ARRAY(ExprValue, self->conditions, self->capacity);
                FREE_TYPE_ARRAY(AstNodeArray, self->statementBlocks, self->capacity);

                self->conditions = newConditions;
                self->statementBlocks = newStatements;
                self->capacity = newCapacity;
            }

            if(elseWithoutCondition == false) { // no condition for final else
                self->conditions[self->conditionsLen] = elseIfCondition;
                self->conditionsLen += 1;
            }

            self->statementBlocks[self->blocksLen] = elseStatements;
            self->blocksLen += 1;

            peekNext = cubs_token_iter_peek(iter);
            if(peekNext == ELSE_KEYWORD) {
                // step over
                (void)cubs_token_iter_next(iter);
            }
        }

        const AstNode node = {.ptr = (void*)self, .vtable = &conditional_node_vtable};
        return node;
    }
}
