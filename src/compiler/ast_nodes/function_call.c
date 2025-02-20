#include "function_call.h"
#include "../parse/tokenizer.h"
#include "../ast.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "expression_value.h"
#include <assert.h>
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../graph/function_dependency_graph.h"

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

static void function_call_node_build_function(
    const FunctionCallNode* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {
    
}

// TODO resolve types

static AstNodeVTable function_call_vtable = {
    .nodeType = astNodeTypeFunctionCall,
    .deinit = (AstNodeDeinit)&function_call_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&function_call_node_build_function,
    .defineType = NULL,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

AstNode cubs_function_call_node_init(
    CubsStringSlice functionName, 
    bool hasReturnVariable, 
    size_t returnVariable, 
    TokenIter *iter, 
    StackVariablesArray *variables,
    FunctionDependencies* dependencies
) {
    assert(iter->current.tag == LEFT_PARENTHESES_SYMBOL);

    function_dependencies_push(dependencies, functionName);

    ExprValue* args = NULL;
    size_t len = 0;
    size_t capacity = 0;

    { // fetch every argument expression
        TokenType next = cubs_token_iter_next(iter);
        while(next != RIGHT_PARENTHESES_SYMBOL) {
            if(len == capacity) {
                const size_t newCapacity = capacity == 0 ? 1 : capacity * 2;
                ExprValue* newArgs = MALLOC_TYPE_ARRAY(ExprValue, newCapacity);
                if(args != NULL) {
                    for(size_t i = 0; i < len; i++) {
                        newArgs[i] = args[i];
                    }
                    FREE_TYPE_ARRAY(ExprValue, args, capacity);
                }

                args = newArgs;
                capacity = newCapacity;
            }

            const ExprValue argExpression = cubs_parse_expression(iter, variables, false, 0);
            args[len] = argExpression;
            len += 1;

            next = cubs_token_iter_next(iter);
            if(next == COMMA_SYMBOL) {
                (void)cubs_token_iter_next(iter);
                assert(iter->current.tag != RIGHT_PARENTHESES_SYMBOL); // expects another argument after a comma
            }
        }
    }

    FunctionCallNode* self = MALLOC_TYPE(FunctionCallNode);
    *self = (FunctionCallNode){0};

    self->functionName = functionName;
    
    self->hasReturnVariable = hasReturnVariable;
    if(hasReturnVariable) {
        self->returnVariable = returnVariable;
    }

    self->args = args;
    self->argsLen = len;
    self->argsCapacity = capacity;

    const AstNode node = {.ptr = (void*)self, .vtable = &function_call_vtable};
    return node;
}
