#include "variable_declaration.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../util/unreachable.h"
#include <assert.h>
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"

static void variable_declaration_node_deinit(VariableDeclarationNode* self) {
    expr_value_deinit(&self->initialValue);
    FREE_TYPE(VariableDeclarationNode, self);
}

static void variable_declaration_node_build_function(
    const VariableDeclarationNode* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {  
    const uint16_t returnSrc = stackAssignment->positions[self->variableNameIndex];

    switch(self->initialValue.tag) {
        case IntLit: {
            Bytecode loadImmediateLong[2];
            operands_make_load_immediate_long(
                loadImmediateLong,
                cubsValueTagInt,
                returnSrc,
                *(const size_t*)&self->initialValue.value.intLiteral.literal // bit cast
            );
            cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);
        } break;
        case Expression: {
            ast_node_build_function(&self->initialValue.value.expression, builder, stackAssignment);
        } break;
        default: {
            assert(false && "Can only handle variable assignment from int literals");
        }
    }
}

static AstNodeVTable variable_declaration_node_vtable = {
    .nodeType = astNodeBinaryExpression,
    .deinit = (AstNodeDeinit)&variable_declaration_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&variable_declaration_node_build_function,
    .defineType = NULL,
};

AstNode cubs_variable_declaration_node_init(TokenIter *iter, StackVariablesArray *variables)
{
    VariableDeclarationNode* self = MALLOC_TYPE(VariableDeclarationNode);
    *self = (VariableDeclarationNode){0};

    { // current token should be `const` or `mut`
        const TokenType tokenType = iter->current.tag;
        switch(tokenType) {
            case CONST_KEYWORD: {
                self->isMutable = false;
            } break;
            case MUT_KEYWORD: {
                self->isMutable = true;
            } break;
            default: unreachable();
        }
    }

    StackVariableInfo variableInfo = {0};
    variableInfo.isTemporary = false;

    { // after `const` or `mut` is the variable name
        const TokenType nextType = cubs_token_iter_next(iter);
        assert(nextType == IDENTIFIER);

        const CubsString variableName = cubs_string_init_unchecked(iter->current.value.identifier);
        variableInfo.name = variableName;
    }

    TokenType typenameToken = TOKEN_NONE;

    { // currently implicit types are not permitted, forcing explicit types to be set for variables
        const TokenType colonNext = cubs_token_iter_next(iter);
        assert(colonNext == COLON_SYMBOL);

        typenameToken = cubs_token_iter_next(iter);
        switch(typenameToken) {
            case INT_KEYWORD: {
                variableInfo.context = &CUBS_INT_CONTEXT;
            } break;
            case IDENTIFIER: {
                assert(false && "Cannot handle idenfitiers as typenames currently");
            } break;
            default: {
                assert(false && "Expected type name");
            } break;
        }
    }

    // Variable order is preserved
    self->variableNameIndex = variables->len;
    // variables->len will be increased by 1
    const bool doesntExist = cubs_stack_variables_array_push(variables, variableInfo);
    assert(doesntExist == true);

    bool isNonZeroedInitial = false;
    { // next will either be a semicolon or the assignment
        const TokenType followingTypename = cubs_token_iter_next(iter);
        // If its just a semicolon and not an expression/literal,
        // we zero initialize the variable
        if(followingTypename == SEMICOLON_SYMBOL) {
            switch(typenameToken) {
                case INT_KEYWORD: {
                    ExprValue value = {0};
                    value.tag = IntLit;
                    value.value.intLiteral.literal = 0;
                    // We don't need to set the stack variable index for the literal value as
                    // it's just used as an immediate value.
                    self->initialValue = value;
                } break;
                default: {
                    assert(false && "Cannot zero initialize other types");
                }
            }
        } else {
            assert(followingTypename == ASSIGN_OPERATOR);
            isNonZeroedInitial = true;
        }
    }

    // Parse the literal or expression
    if(isNonZeroedInitial) {
        (void)cubs_token_iter_next(iter); // step over to next
        self->initialValue = cubs_parse_expression(
            iter, variables, true, self->variableNameIndex
        );
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &variable_declaration_node_vtable};
    return node;
}
