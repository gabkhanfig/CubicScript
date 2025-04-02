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
#include "../graph/function_dependency_graph.h"
#include "../graph/scope.h"

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
        const ExprValueDst dst = cubs_expr_value_build_function(&self->retValue, builder, stackAssignment);
        assert(dst.hasDst);
        const Bytecode returnBytecode = operands_make_return(true, dst.dst);     
        cubs_function_builder_push_bytecode(builder, returnBytecode);
    }
}

static void return_node_resolve_types(
    ReturnNode* self, CubsProgram* program, const FunctionBuilder* builder, StackVariablesArray* variables, const Scope* scope
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
        cubs_expr_node_resolve_type(&self->retValue, program, builder, variables, scope);
    assert(builder->optReturnType == retValueContext);
}

static bool return_node_ends_with_return(const ReturnNode* _) {
    return true;
}

static AstNodeVTable return_node_vtable = {
    .nodeType = astNodeTypeReturn,
    .deinit = (AstNodeDeinit)&return_node_deinit,
    .compile = NULL,
    .toString = (AstNodeToString)&return_node_to_string,
    .buildFunction = (AstNodeBuildFunction)&return_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&return_node_resolve_types,
    .endsWithReturn = (AstNodeStatementsEndWithReturn)&return_node_ends_with_return,
};

AstNode cubs_return_node_init(TokenIter *iter, StackVariablesArray* variables, FunctionDependencies* dependencies)
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
                iter, variables, dependencies, false, -1
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
