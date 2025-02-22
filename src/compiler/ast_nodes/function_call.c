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
    switch(self->function.funcType) { // same memory location but for the sake of clarity
        case cubsFunctionPtrTypeC: {
            assert(self->function.func.externC != NULL);
        } break;
        case cubsFunctionPtrTypeScript: {
            assert(self->function.func.script != NULL);
        } break;
        default: unreachable();
    }

    const uint16_t argCount = (uint16_t)self->argsLen;
    uint16_t* args = NULL;
    if(argCount > 0) {
        args = MALLOC_TYPE_ARRAY(uint16_t, argCount);
    }

    for(uint16_t i = 0; i < argCount; i++) { // handle each argument
        const ExprValue argExpression = self->args[i];
        const ExprValueDst dst = cubs_expr_value_build_function(&argExpression, builder, stackAssignment);
        assert(dst.hasDst);
        args[i] = dst.dst;
    }

    uint16_t retDst = 0;
    if(self->hasReturnVariable) {
        retDst = stackAssignment->positions[self->returnVariable];
    }

    const size_t availableBytecode = 2 + (4 * argCount);
    Bytecode* callBytecode = MALLOC_TYPE_ARRAY(Bytecode, availableBytecode);
    const size_t usedBytecode = cubs_operands_make_call_immediate(
        callBytecode,
        availableBytecode,
        argCount,
        args,
        self->hasReturnVariable,
        retDst, 
        self->function
    );

    cubs_function_builder_push_bytecode_many(builder, callBytecode, usedBytecode);

    FREE_TYPE_ARRAY(Bytecode, callBytecode, availableBytecode);
    if(args != NULL) {
        FREE_TYPE_ARRAY(uint16_t, args, argCount);
    }
}

static void function_call_node_resolve_types(
    FunctionCallNode* self,
    CubsProgram* program,
    const FunctionBuilder* builder,
    StackVariablesArray* variables
) {
    CubsFunction actualFunction = {0};
    const bool found = cubs_program_find_function(program, &actualFunction, self->functionName);
    assert(found);

    // TODO do actual type validation
    self->function = actualFunction;

    if(self->hasReturnVariable) {
        if(actualFunction.funcType == cubsFunctionPtrTypeScript) {
            const CubsScriptFunctionPtr* scriptFuncPtr = actualFunction.func.script;
            assert(scriptFuncPtr->returnType != NULL);

            TypeResolutionInfo* typeInfo = &variables->variables[self->returnVariable].typeInfo;
            assert(typeInfo->knownContext == NULL);

            typeInfo->knownContext = scriptFuncPtr->returnType;
        } else {
            cubs_panic("Cannot resolve types for C function pointers");
        }
    }
}

static AstNodeVTable function_call_vtable = {
    .nodeType = astNodeTypeFunctionCall,
    .deinit = (AstNodeDeinit)&function_call_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&function_call_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&function_call_node_resolve_types,
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

    // TODO handle function pointers

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

            const ExprValue argExpression = cubs_parse_expression(iter, variables, dependencies, false, 0);
            args[len] = argExpression;
            len += 1;

            next = iter->current.tag;
            if(iter->current.tag == COMMA_SYMBOL) {
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
