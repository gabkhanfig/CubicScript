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

static void return_node_deinit(ReturnNode* self) {
    //cubs_string_deinit(&self->variableName);
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
        assert(self->variableNameIndex < stackAssignment->len);
        //const CubsStringSlice variableName = stackAssignment->names[self->variableNameIndex];
        const uint16_t returnSrc = stackAssignment->positions[self->variableNameIndex]; //cubs_stack_assignment_find(stackAssignment, variableName);
        switch(self->retInfo.tag) {
            case IDENTIFIER: break;
            case INT_LITERAL: {
                Bytecode loadImmediateLong[2];
                operands_make_load_immediate_long(loadImmediateLong, cubsValueTagInt, returnSrc, self->retInfo.value.intLiteral);
                cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);
            } break;
            default: {
                cubs_panic("Cannot handle non identifier or int literal returns yet");
            } break;
        }

        const Bytecode returnBytecode = operands_make_return(true, returnSrc);     
        cubs_function_builder_push_bytecode(builder, returnBytecode);
    }
}

static AstNodeVTable return_node_vtable = {
    .nodeType = astNodeTypeReturn,
    .deinit = (AstNodeDeinit)&return_node_deinit,
    .compile = NULL,
    .toString = (AstNodeToString)&return_node_to_string,
    .buildFunction = (AstNodeBuildFunction)&return_node_build_function,
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
        else if(next == IDENTIFIER) {
            self->retInfo = iter->current;
            self->hasReturn = true;
            
            const CubsStringSlice variableNameSlice = self->retInfo.value.identifier;

            const bool foundVariableNameIndex = 
                cubs_stack_variables_array_find(variables, &self->variableNameIndex, variableNameSlice);
            assert(foundVariableNameIndex);
        } 
        else if(next == INT_LITERAL || next == FLOAT_LITERAL || next == CHAR_LITERAL || next == STR_LITERAL) {
            if(next != INT_LITERAL) {
                cubs_panic("TODO return stuff other than int literals");
            }

            self->retInfo = iter->current;
            self->hasReturn = true;
            // TODO come up with proper naming scheme for temporary values
            const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tempRet", .len = 8});
            
            StackVariableInfo temporaryVariable = {
                .name = variableName,
                .isTemporary = true,
                .context = &CUBS_INT_CONTEXT,
                .taggedName = {0},
            };

            // Variable order is preserved
            self->variableNameIndex = variables->len;
            // variables->len will be increased by 1
            cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
        } else {
            cubs_panic("Invalid token after return");
        }
    }

    if(self->hasReturn) { // statement must end in semicolon
        const TokenType next = cubs_token_iter_next(iter);
        if(next != SEMICOLON_SYMBOL) {
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
