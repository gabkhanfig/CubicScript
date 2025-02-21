#include "function_node.h"
#include "return_node.h"
#include "variable_declaration.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../platform/mem.h"
#include "../../primitives/context.h"
#include "../../interpreter/bytecode.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../../interpreter/function_definition.h"
#include "../../primitives/string/string.h"
#include "../parse/parse_statements.h"
#include "../graph/function_dependency_graph.h"
//#include <stdio.h>

static void function_node_deinit(FunctionNode* self) {
    ast_node_array_deinit(&self->items);
    cubs_stack_variables_array_deinit(&self->variables);
    cubs_free(self, sizeof(FunctionNode), _Alignof(FunctionNode));
}

static CubsStringSlice function_node_to_string(const FunctionNode* self) {
    return (CubsStringSlice){0};
}

static void function_node_compile(FunctionNode* self, CubsProgram* program) {
    FunctionBuilder builder = {0};

    { // function name
        CubsString functionName;
        assert(cubs_string_init(&functionName, self->functionName) == cubsStringErrorNone);
        builder.fullyQualifiedName = functionName;
        builder.name = cubs_string_clone(&functionName);
    }

    if(self->hasRetType) {
        const CubsTypeContext* retContext = NULL;
        if(self->retType.knownContext != NULL) {
            retContext = self->retType.knownContext;
        } else {
            const CubsStringSlice typeName = self->retType.typeName;
            retContext = cubs_program_find_type_context(program, typeName);
            assert(retContext != NULL);
        }
        builder.optReturnType = retContext;
    } 

    // resolve types of arguments
    // NOTE the first variables in `self->variables` are the function
    // arguments, up to inclusively `self->argCount - 1`
    for(size_t i = 0; i < self->argCount; i++) {
        if(self->variables.variables[i].typeInfo.knownContext != NULL) continue;

        const CubsStringSlice typeName = self->variables.variables[i].typeInfo.typeName;
        const CubsTypeContext* argContext = cubs_program_find_type_context(program, typeName);
        assert(argContext != NULL);
        self->variables.variables[i].typeInfo.knownContext = argContext;
    }
    
    // arguments
    for(size_t i = 0; i < self->argCount; i++) {
        assert(self->variables.variables[i].typeInfo.knownContext != NULL);
        cubs_function_builder_add_arg(&builder, self->variables.variables[i].typeInfo.knownContext);
    }

    // resolve all types for all statements
    for(uint32_t i = 0; i < self->items.len; i++) {
        AstNode* node = &self->items.nodes[i];
        if(node->vtable->resolveTypes == NULL) continue;

        ast_node_resolve_types(node, program, &builder, &self->variables);
    }

    StackVariablesAssignment stackAssignment = cubs_stack_assignment_init(&self->variables);
    builder.stackSpaceRequired = stackAssignment.requiredFrameSize;
 
    { // Validate that the function ends with returns
        const AstNode* lastNode = &self->items.nodes[self->items.len - 1];
        assert(lastNode->vtable->endsWithReturn != NULL && 
            "The last node in a function must be a return, or a collection of statements that result in a return");
        assert(ast_node_statements_end_with_return(lastNode));
    }

    // Statements
    // If there are no statements, a single return bytecode is required.
    if(self->items.len == 0) {
        const Bytecode bytecode = operands_make_return(false, 0);
        cubs_function_builder_push_bytecode(&builder, bytecode);
    } else {
        for(size_t i = 0; i < self->items.len; i++) {
            const AstNode node = self->items.nodes[i];
            // TODO allow nodes that don't just do code gen, such as nested structs maybe? or lambdas? to determine
            assert(node.vtable->buildFunction != NULL);
            ast_node_build_function(&node, &builder, &stackAssignment); // TODO stack variable assignment
        }
    }

    cubs_function_builder_build(&builder, program);

    // cleanup
    cubs_stack_assignment_deinit(&stackAssignment);
}

static AstNodeVTable function_node_vtable = {
    .nodeType = astNodeTypeFunction,
    .deinit = (AstNodeDeinit)&function_node_deinit,
    .compile = (AstNodeCompile)&function_node_compile,
    .toString = (AstNodeToString)&function_node_to_string,
    .buildFunction = NULL,
    .defineType = NULL,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

/// Parses from `'('` to `')'`.
/// After calling, assuming no parsing errors occur,
/// `iter->current` will be `RIGHT_PARENTHESES_SYMBOL`
static StackVariablesArray parse_function_args(TokenIter *iter) {
    assert(iter->current.tag == LEFT_PARENTHESES_SYMBOL);

    TokenType token = cubs_token_iter_next(iter);
    StackVariablesArray variables = {0};

    if(token == RIGHT_PARENTHESES_SYMBOL) { // has no arguments
        return variables;
    }

    while(token != RIGHT_PARENTHESES_SYMBOL) {
        StackVariableInfo info = {0};
        info.isMutable = true; // TODO should function arguments be immutable?

        const TokenType variableNameToken = token;
        assert(variableNameToken == IDENTIFIER && "Expected identifier for function argument variable name");
        const CubsStringError variableNameErr = cubs_string_init(&info.name, iter->current.value.identifier);
        assert(variableNameErr == cubsStringErrorNone && "Invalid UTF8 variable identifier");
        
        const TokenType colonToken = cubs_token_iter_next(iter);
        assert(colonToken == COLON_SYMBOL && "Expected \':\' following function argument variable name");

        (void)cubs_token_iter_next(iter);
        info.typeInfo = cubs_parse_type_resolution_info(iter);

        cubs_stack_variables_array_push(&variables, info);

        // move iterator forward. while loop will check this
        token = iter->current.tag;
        if(token != COMMA_SYMBOL && token != RIGHT_PARENTHESES_SYMBOL) {
            assert(false && "Expected comma or right parentheses to follow function argument");
        }
        if(token == COMMA_SYMBOL) {
            // move forward again to next argument or parentheses
            token = cubs_token_iter_next(iter);
        }
    }

    return variables;
}

AstNode cubs_function_node_init(TokenIter *iter, struct FunctionDependencyGraphBuilder* dependencyBuilder)
{
    assert(iter->current.tag == FN_KEYWORD);
    FunctionNode* self = (FunctionNode*)cubs_malloc(sizeof(FunctionNode), _Alignof(FunctionNode));
    *self = (FunctionNode){0}; // 0 initialize everything. Means no return type by default

    { // function name
        const TokenType token = cubs_token_iter_next(iter);
        assert(token == IDENTIFIER && "Identifier must occur after fn keyword");
        self->functionName = iter->current.value.identifier;
    }

    assert(cubs_token_iter_next(iter) == LEFT_PARENTHESES_SYMBOL);

    self->variables = parse_function_args(iter);
    self->argCount = self->variables.len;
    assert(iter->current.tag = RIGHT_PARENTHESES_SYMBOL);

    { // return type
        const TokenType optionalRetToken = cubs_token_iter_next(iter);
        if(optionalRetToken == LEFT_BRACE_SYMBOL) {
            self->hasRetType = false;
        } else {
            self->hasRetType = true;
            self->retType = cubs_parse_type_resolution_info(iter);
            assert(iter->current.tag == LEFT_BRACE_SYMBOL); 
        }
    }

    // TODO figure out how to handle temporary variables

    { // statements
        FunctionDependencies dependencies = {0};
        dependencies.name = self->functionName;

        bool endsWithReturn = false;

        AstNode temp = {0};
        while(parse_next_statement(&temp, iter, &self->variables, &dependencies)) {
            ast_node_array_push(&self->items, temp);
            endsWithReturn = temp.vtable->nodeType == astNodeTypeReturn;
        }

        // If there is no return type, we can automatically insert a return 
        // statement otherwise, the source code must have a return statement at
        // the end of all control flow.
        if(endsWithReturn == false && self->hasRetType == false) {
            AstNode emptyReturnNode = cubs_return_node_init_empty();
            ast_node_array_push(&self->items, emptyReturnNode);
        }

        function_dependency_graph_builder_push(dependencyBuilder, dependencies);
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &function_node_vtable};
    return node;
}