#include "return_node.h"
#include "../../util/panic.h"
#include "../../platform/mem.h"
#include <assert.h>
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include <stdio.h>

static void return_node_deinit(ReturnNode* self) {
    cubs_free(self, sizeof(ReturnNode), _Alignof(ReturnNode));
}

static CubsStringSlice return_node_to_string(const ReturnNode* self) {
    return (CubsStringSlice){0};
}

static void return_node_build_function(const ReturnNode* self, FunctionBuilder* builder, const void* reserveStackAssignments) {  
    if(self->hasReturn) {
        const Bytecode bytecode = operands_make_return(false, 0);
        cubs_function_builder_push_bytecode(builder, bytecode);
    } else {
        const uint16_t returnSrc = 0; // TODO get actual src
        assert(self->retInfo == INT_LITERAL);

        Bytecode loadImmediateLong[2];
        operands_make_load_immediate_long(loadImmediateLong, cubsValueTagInt, returnSrc, self->retValue.intLiteral);

        const Bytecode returnBytecode =  operands_make_return(true, returnSrc);
        
        cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);
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

AstNode cubs_return_node_init(TokenIter *iter)
{
    assert(iter->current == RETURN_KEYWORD);
    ReturnNode* self = (ReturnNode*)cubs_malloc(sizeof(ReturnNode), _Alignof(ReturnNode));
    *self = (ReturnNode){0};

    {
        const Token next = cubs_token_iter_next(iter);
        if(next == SEMICOLON_SYMBOL) {
            self->hasReturn = false;
        } else if(next == INT_LITERAL || next == FLOAT_LITERAL || next == CHAR_LITERAL || next == STR_LITERAL || next == IDENTIFIER) {
            if(next != INT_LITERAL) {
                cubs_panic("TODO return stuff other than int literals");
            }

            self->retInfo = next;
            self->retValue = iter->currentMetadata;
            self->hasReturn = true;
        } else {
            cubs_panic("Invalid token after return");
        }
    }

    if(self->hasReturn) { // statement must end in semicolon
        const Token next = cubs_token_iter_next(iter);
        if(next != SEMICOLON_SYMBOL) {
            cubs_panic("return statement must end with semicolon");
        }
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &return_node_vtable};
    return node;
}
