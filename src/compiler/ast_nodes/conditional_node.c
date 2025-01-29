#include "conditional_node.h"
#include "../../platform/mem.h"
#include "../ast.h"
#include "../stack_variables.h"
#include "../tokenizer.h"
#include "ast_node_array.h"
#include "expression_value.h"
#include "../../interpreter/function_definition.h"
#include <assert.h>
#include "parse_statements.h"
#include <string.h>

static void conditional_node_deinit(ConditionalNode* self) {
    for(size_t i = 0; i < self->conditionsLen; i++) {
        expr_value_deinit(&self->conditions[i]);
    }
    for(size_t i = 0; i < self->blocksLen; i++) {
        ast_node_array_deinit(&self->statementBlocks[i]);
    }

    FREE_TYPE_ARRAY(ExprValue, self->conditions, self->capacity);
    FREE_TYPE_ARRAY(AstNodeArray, self->statementBlocks, self->capacity);
    FREE_TYPE(ConditionalNode, self);
}

// static void conditional_node_build_function(
//     const ConditionalNode* self,
//     FunctionBuilder* builder,
//     const StackVariablesAssignment* stackAssignment
// ) {

// }

static AstNodeVTable conditional_node_vtable = {
    .nodeType = astNodeTypeConditional,
    .deinit = (AstNodeDeinit)&conditional_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = NULL, //(AstNodeBuildFunction)&conditional_node_build_function,
    .defineType = NULL,
};

AstNode cubs_conditional_node_init(TokenIter *iter, StackVariablesArray *variables)
{
    assert(iter->current.tag == IF_KEYWORD);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == LEFT_PARENTHESES_SYMBOL);

    const ExprValue firstIfCondition = cubs_parse_expression(iter, variables, false, -1);
    assert(iter->current.tag == RIGHT_PARENTHESES_SYMBOL);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == LEFT_BRACE_SYMBOL);

    AstNodeArray firstIfStatements = {0};
    {
        AstNode temp = {0};
        // parses until right brace
        while(parse_next_statement(&temp, iter, variables)) {
            ast_node_array_push(&firstIfStatements, temp);
        }
    }

    ConditionalNode* self = MALLOC_TYPE(ConditionalNode);
    *self = (ConditionalNode){0};

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

                const ExprValue firstIfCondition = cubs_parse_expression(iter, variables, false, -1);
                assert(iter->current.tag == RIGHT_PARENTHESES_SYMBOL);
            } else {
                assert(false && "Expected \'{\' or \'if\' after \'else\'");
            }
         
            (void)cubs_token_iter_next(iter);
            assert(iter->current.tag == LEFT_BRACE_SYMBOL);

            AstNodeArray elseStatements = {0};
            {
                AstNode temp = {0};
                // parses until right brace
                while(parse_next_statement(&temp, iter, variables)) {
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

                memcpy(newConditions, self->conditions, self->conditionsLen);
                memcpy(newStatements, self->statementBlocks, self->blocksLen);

                FREE_TYPE_ARRAY(ExprValue, self->conditions, self->capacity);
                FREE_TYPE_ARRAY(AstNodeArray, self->statementBlocks, self->capacity);

                self->conditions = newConditions;
                self->statementBlocks = newStatements;
            }

            if(elseWithoutCondition == false) { // no condition for final else
                self->conditions[self->conditionsLen] = elseIfCondition;
                self->conditionsLen += 1;
            }

            self->statementBlocks[self->blocksLen] = elseStatements;
            self->blocksLen += 1;

            peekNext = cubs_token_iter_peek(iter);
        }

        const AstNode node = {.ptr = (void*)self, .vtable = &conditional_node_vtable};
        return node;
    }
}
