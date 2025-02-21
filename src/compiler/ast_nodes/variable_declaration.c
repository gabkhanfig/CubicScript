#include "variable_declaration.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../util/unreachable.h"
#include <assert.h>
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../../program/program_internal.h"
#include "../graph/function_dependency_graph.h"
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
    cubs_expr_value_build_function(&self->initialValue, builder, stackAssignment);
}

static void variable_declaration_resolve_types(
    VariableDeclarationNode* self, CubsProgram* program, const FunctionBuilder* builder, StackVariablesArray* variables
) {
    TypeResolutionInfo* typeInfo = &variables->variables[self->variableNameIndex].typeInfo;
    if(typeInfo->knownContext != NULL) return;

    const CubsStringSlice typeName = typeInfo->typeName;
    const CubsTypeContext* argContext = cubs_program_find_type_context(program, typeName);
    assert(argContext != NULL);
    typeInfo->knownContext = argContext;
}

static AstNodeVTable variable_declaration_node_vtable = {
    .nodeType = astNodeVariableDeclaration,
    .deinit = (AstNodeDeinit)&variable_declaration_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&variable_declaration_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&variable_declaration_resolve_types,
    .endsWithReturn = NULL,
};

AstNode cubs_variable_declaration_node_init(
    TokenIter *iter,
    StackVariablesArray* variables,
    FunctionDependencies* dependencies
) {
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
    variableInfo.isMutable = self->isMutable;

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
                value.value.boolLiteral.variableIndex = self->variableNameIndex;
                self->initialValue = value;
            }  
            else if(variableInfo.typeInfo.knownContext == &CUBS_INT_CONTEXT) {
                ExprValue value = {0};
                value.tag = IntLit;
                value.value.intLiteral.literal = 0;
                value.value.intLiteral.variableIndex = self->variableNameIndex;
                self->initialValue = value;
            } else if(variableInfo.typeInfo.knownContext == &CUBS_FLOAT_CONTEXT) {
                ExprValue value = {0};
                value.tag = FloatLit;
                value.value.floatLiteral.literal = 0.0;
                value.value.floatLiteral.variableIndex = self->variableNameIndex;
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
            iter, variables, dependencies, true, self->variableNameIndex
        );
        cubs_expr_value_update_destination(&self->initialValue, self->variableNameIndex);
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &variable_declaration_node_vtable};
    return node;
}
