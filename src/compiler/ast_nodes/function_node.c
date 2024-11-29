#include "function_node.h"

static void function_node_deinit(FunctionNode* self) {
    ast_node_array_deinit(&self->items);
    cubs_free(self, sizeof(FunctionNode), _Alignof(FunctionNode));
}

static CubsStringSlice function_node_to_string(const FunctionNode* self) {
    return (CubsStringSlice){0};
}

static AstNodeVTable function_node_vtable = {
    .deinit = (AstNodeDeinit)&function_node_deinit,
    .compile = NULL,
    .toString = (AstNodeToString)&function_node_to_string,
    .buildFunction = NULL,
};


AstNode cubs_function_node_init(TokenIter *iter)
{
    assert(iter->current == FN_KEYWORD);
    FunctionNode* self = (FunctionNode*)cubs_malloc(sizeof(FunctionNode), _Alignof(FunctionNode));
    *self = (FunctionNode){0}; // 0 initialize everything. Means no return type by default

    { // function name
        const Token token = cubs_token_iter_next(iter);
        assert(token == IDENTIFIER && "Identifier must occur after fn keyword");
        self->functionName = iter->currentMetadata.identifier;
    }

    assert(cubs_token_iter_next(iter) == LEFT_PARENTHESES_SYMBOL);
    assert(cubs_token_iter_next(iter) == RIGHT_PARENTHESES_SYMBOL); // no arguments for now

    { // return type
        Token token = cubs_token_iter_next(iter);
        if(token != LEFT_BRACKET_SYMBOL) { // has return type            
            if(token == INT_LITERAL) {
                self->retInfo.retTag = functionReturnToken;
                self->retInfo.retType.token = INT_KEYWORD;
            }
            if(token == IDENTIFIER) {
                assert("Cannot handle identifier returns yet");
            } else {
                assert("Cannot handle other stuff for function return yet");
            }

            token = cubs_token_iter_next(iter); // left bracket should follow after token
            assert(token == LEFT_BRACKET_SYMBOL); 
        }
        // TODO more complex return types, for now just nothing or ints           
    }

    { // statements
        Token token = cubs_token_iter_next(iter);
        assert(token == RETURN_KEYWORD);
    }


    const AstNode node = {.ptr = (void*)self, .vtable = &function_node_vtable};
    return node;
}