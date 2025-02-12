#include "function_call.h"
#include "../parse/tokenizer.h"
#include "../ast.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "expression_value.h"
#include <assert.h>

static void function_call_node_deinit(FunctionCallNode* self) {
    if(self->argsCapacity > 0) {
        assert(self->args != NULL);
        for(size_t i = 0; i < self->argsLen; i++) {
            expr_value_deinit(&self->args[i]);
        }
        FREE_TYPE_ARRAY(ExprValue, self->args, self->argsCapacity);
    }

    FREE_TYPE(FunctionCallNode, self);
}

static AstNodeVTable function_call_vtable = {
    .nodeType = astNodeTypeFunctionCall,
    .deinit = (AstNodeDeinit)&function_call_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = NULL,
    .defineType = NULL,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

AstNode cubs_function_call_node_init(
    const CubsStringSlice functionName, 
    bool hasReturnVariable, 
    size_t returnVariable, 
    TokenIter *iter, 
    StackVariablesArray *variables
) {
    
    FunctionCallNode* self = MALLOC_TYPE(FunctionCallNode);
    *self = (FunctionCallNode){0};

    const AstNode node = {.ptr = (void*)self, .vtable = &function_call_vtable};
    return node;
}
