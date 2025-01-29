#include "variable_declaration.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../util/unreachable.h"
#include <assert.h>
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include <stdio.h>

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
        case BoolLit: {
            const Bytecode loadImmediateBool = operands_make_load_immediate(
                LOAD_IMMEDIATE_BOOL,
                returnSrc,
                (int64_t)self->initialValue.value.boolLiteral.literal
            );
            cubs_function_builder_push_bytecode(builder, loadImmediateBool);
        } break;
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
            assert(false && "Can only handle variable assignment from int literals, bool literals, and expressions");
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

    const TokenType colonNext = cubs_token_iter_next(iter);
    assert(colonNext == COLON_SYMBOL);
    (void)cubs_token_iter_next(iter);
    variableInfo.typeInfo = cubs_parse_type_resolution_info(iter);

    // Variable order is preserved
    self->variableNameIndex = variables->len;
    // variables->len will be increased by 1
    const bool doesntExist = cubs_stack_variables_array_push(variables, variableInfo);
    assert(doesntExist == true);

    bool isNonZeroedInitial = false;
    { // next will either be a semicolon or the assignment
        const TokenType followingTypename = iter->current.tag;
        // If its just a semicolon and not an expression/literal,
        // we zero initialize the variable
        if(followingTypename == SEMICOLON_SYMBOL) {
            if(variableInfo.typeInfo.knownContext == &CUBS_BOOL_CONTEXT) {
                ExprValue value = {0};
                value.tag = BoolLit;
                value.value.boolLiteral.literal = false;
                // We don't need to set the stack variable index for the literal value as
                // it's just used as an immediate value.
                self->initialValue = value;
            }  
            else if(variableInfo.typeInfo.knownContext == &CUBS_INT_CONTEXT) {
                ExprValue value = {0};
                value.tag = IntLit;
                value.value.intLiteral.literal = 0;
                // We don't need to set the stack variable index for the literal value as
                // it's just used as an immediate value.
                self->initialValue = value;
            } else if(variableInfo.typeInfo.knownContext == &CUBS_FLOAT_CONTEXT) {
                ExprValue value = {0};
                value.tag = FloatLit;
                value.value.floatLiteral.literal = 0.0;
                // We don't need to set the stack variable index for the literal value as
                // it's just used as an immediate value.
                self->initialValue = value;
            } else {
                assert(false && "Cannot zero initialize other types");
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
