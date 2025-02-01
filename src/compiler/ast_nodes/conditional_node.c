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
#include "../../interpreter/bytecode_array.h"
#include "../../interpreter/operations.h"
#include "../../interpreter/bytecode.h"
#include "binary_expression.h"

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

    assert(self->conditionsLen >= self->blocksLen);
    for(size_t i = 0; i < self->conditionsLen; i++) {
        const ExprValue conditionValue = self->conditions[i];

        size_t conditionVariableSrc = -1;

        switch(conditionValue.tag) {
            case Variable: {
                conditionVariableSrc = conditionValue.value.variableIndex;
            } break;
            case BoolLit: {
                const Bytecode loadImmediateBool = operands_make_load_immediate(
                    LOAD_IMMEDIATE_BOOL, 
                    conditionValue.value.boolLiteral.variableIndex, 
                    (int64_t)conditionValue.value.boolLiteral.literal
                );
                cubs_function_builder_push_bytecode(builder, loadImmediateBool);
                conditionVariableSrc = conditionValue.value.boolLiteral.variableIndex;
            } break;
            case Expression: {
                const AstNode node = conditionValue.value.expression;
                assert(node.vtable->nodeType == astNodeBinaryExpression);

                ast_node_build_function(&node, builder, stackAssignment);

                const BinaryExprNode* binExpr = (const BinaryExprNode*)node.ptr;
                assert(binExpr->operation == Equal);
                conditionVariableSrc = binExpr->outputVariableIndex;
            } break;
            default: {
                assert(false && "Cannot handle condition expression value as condition");
            } break;
        }

        const Bytecode tempJumpBytecode = cubs_operands_make_jump(
            JUMP_TYPE_IF_FALSE, INT32_MAX, (uint16_t)conditionVariableSrc);
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
            ast_node_build_function(&node, &builder, &stackAssignment);
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
    ConditionalNode* self, CubsProgram* program, const FunctionBuilder* builder, StackVariablesArray* variables
) {
    // conditions first
    for(size_t i = 0; i < self->conditionsLen; i++) {
        ExprValue* conditionExpr = &self->conditions[i];
        const CubsTypeContext* conditionContext = 
            cubs_expr_node_resolve_type(conditionExpr, program, builder, variables);
        assert(conditionContext == &CUBS_BOOL_CONTEXT);
    }

    // statements
    for(size_t i = 0; i < self->blocksLen; i++) {
        AstNodeArray* statements = &self->statementBlocks[i];
        for(uint32_t statementIter = 0; statementIter < statements->len; statementIter++) {
            AstNode* node = &statements->nodes[statementIter];
            if(node->vtable->resolveTypes == NULL) continue;

            ast_node_resolve_types(node, program, builder, variables);
        }
    }
}

static AstNodeVTable conditional_node_vtable = {
    .nodeType = astNodeTypeConditional,
    .deinit = (AstNodeDeinit)&conditional_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&conditional_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&conditional_node_resolve_types,
};

AstNode cubs_conditional_node_init(TokenIter *iter, StackVariablesArray *variables)
{
    assert(iter->current.tag == IF_KEYWORD);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == LEFT_PARENTHESES_SYMBOL);
    (void)cubs_token_iter_next(iter);

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
