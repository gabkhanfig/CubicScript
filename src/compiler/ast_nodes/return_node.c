#include "return_node.h"
#include "../../util/panic.h"
#include "../../platform/mem.h"
#include <assert.h>

static void return_node_deinit(ReturnNode* self) {
    cubs_free(self, sizeof(ReturnNode), _Alignof(ReturnNode));
}

static CubsStringSlice return_node_to_string(const ReturnNode* self) {
    return (CubsStringSlice){0};
}

static AstNodeVTable return_node_vtable = {
    .deinit = (AstNodeDeinit)&return_node_deinit,
    .compile = NULL,
    .toString = (AstNodeToString)&return_node_to_string,
    .buildFunction = NULL,
};

AstNode cubs_return_node_init(TokenIter *iter)
{
    assert(iter->current == RETURN_KEYWORD);
    ReturnNode* self = (ReturnNode*)cubs_malloc(sizeof(ReturnNode), _Alignof(ReturnNode));

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
