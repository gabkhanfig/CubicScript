#include "return_node.h"
#include "../../util/panic.h"
#include "../../platform/mem.h"
#include <assert.h>
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../stack_variables.h"
#include <stdio.h>
#include "../../util/unreachable.h"
#include "binary_expression.h"
#include "../../program/program_internal.h"

static void return_node_deinit(ReturnNode* self) {
    //cubs_string_deinit(&self->variableName);
    if(self->hasReturn) {
        expr_value_deinit(&self->retValue);
    }
    cubs_free(self, sizeof(ReturnNode), _Alignof(ReturnNode));
}

static CubsStringSlice return_node_to_string(const ReturnNode* self) {
    return (CubsStringSlice){0};
}

static void return_node_build_function(
    const ReturnNode* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {  
    if(!self->hasReturn) {
        const Bytecode bytecode = operands_make_return(false, 0);
        cubs_function_builder_push_bytecode(builder, bytecode);
    } else {
        uint16_t returnSrc;
        switch(self->retValue.tag) {
            case Variable: {
                returnSrc = stackAssignment->positions[self->retValue.value.variableIndex];
            } break;
            case IntLit: {
                returnSrc = stackAssignment->positions[self->retValue.value.intLiteral.variableIndex];
                Bytecode loadImmediateLong[2];
                operands_make_load_immediate_long(
                    loadImmediateLong, cubsValueTagInt, returnSrc, self->retValue.value.intLiteral.literal);
                cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);
            } break;
            case Expression: {
                const AstNode* exprNode = &self->retValue.value.expression;
                switch(exprNode->vtable->nodeType) {
                    case astNodeBinaryExpression: {
                        // TODO should come up with a better way to do this
                        const size_t index = 
                            ((const BinaryExprNode*)exprNode->ptr)->outputVariableIndex;
                        returnSrc = stackAssignment->positions[index];
                    }

                    ast_node_build_function(&self->retValue.value.expression, builder, stackAssignment);
                }
            } break;
            default: {
                cubs_panic("Cannot handle non identifier, int literal, or expression returns yet");
            } break;
        }

        const Bytecode returnBytecode = operands_make_return(true, returnSrc);     
        cubs_function_builder_push_bytecode(builder, returnBytecode);
    }
}

static void return_node_resolve_types(
    ReturnNode* self, CubsProgram* program, const FunctionBuilder* builder, StackVariablesArray* variables
) {
    if(self->hasReturn && builder->optReturnType == NULL) {
        fprintf(stderr, "Function \'%s\' has no return type, but a value is attempting to be returned",
            cubs_string_as_slice(&builder->fullyQualifiedName).str);
    } 

    if(!self->hasReturn) {
        if(builder->optReturnType != NULL) {
            fprintf(stderr, "Function \'%s\' has a return type, but a void return statement is used", 
                cubs_string_as_slice(&builder->fullyQualifiedName).str);
            cubs_panic("void return with non-void function");
        }
        return;
    }

    const CubsTypeContext* retValueContext = 
        cubs_expr_node_resolve_type(&self->retValue, program, builder, variables);
    assert(builder->optReturnType == retValueContext);
}

static AstNodeVTable return_node_vtable = {
    .nodeType = astNodeTypeReturn,
    .deinit = (AstNodeDeinit)&return_node_deinit,
    .compile = NULL,
    .toString = (AstNodeToString)&return_node_to_string,
    .buildFunction = (AstNodeBuildFunction)&return_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&return_node_resolve_types,
    .endsWithReturn = NULL,
};

AstNode cubs_return_node_init(TokenIter *iter, StackVariablesArray* variables)
{
    assert(iter->current.tag == RETURN_KEYWORD);
    ReturnNode* self = (ReturnNode*)cubs_malloc(sizeof(ReturnNode), _Alignof(ReturnNode));
    *self = (ReturnNode){0};

    {
        const TokenType next = cubs_token_iter_next(iter);
        if(next == SEMICOLON_SYMBOL) {
            self->hasReturn = false;
        } 
        else if(next == IDENTIFIER || next == INT_LITERAL) {
            // TODO handle binary expressions as return
            self->retValue = cubs_parse_expression(
                iter, variables, false, -1
            );
            self->hasReturn = true;
        }
        else {
            cubs_panic("Invalid token after return");
        }
    }

    if(self->hasReturn) { // statement must end in semicolon
        if(iter->current.tag != SEMICOLON_SYMBOL) {
            cubs_panic("return statement must end with semicolon");
        }
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &return_node_vtable};
    return node;
}

AstNode cubs_return_node_init_empty()
{
    ReturnNode* self = (ReturnNode*)cubs_malloc(sizeof(ReturnNode), _Alignof(ReturnNode));
    *self = (ReturnNode){0};

    self->hasReturn = false;

    const AstNode node = {.ptr = (void*)self, .vtable = &return_node_vtable};
    return node;
}
