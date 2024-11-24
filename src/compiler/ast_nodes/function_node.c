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
    self->items = (AstNodeArray){0};

    const AstNode node = {.ptr = (void*)self, .vtable = &function_node_vtable};
    return node;
}