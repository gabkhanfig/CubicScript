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
//#include <stdio.h>

static void function_node_deinit(FunctionNode* self) {
    ast_node_array_deinit(&self->items);
    cubs_stack_variables_array_deinit(&self->variables);
    cubs_free(self, sizeof(FunctionNode), _Alignof(FunctionNode));
}

static CubsStringSlice function_node_to_string(const FunctionNode* self) {
    return (CubsStringSlice){0};
}

static void function_node_compile(const FunctionNode* self, CubsProgram* program) {
    FunctionBuilder builder = {0};

    { // function name
        CubsString functionName;
        assert(cubs_string_init(&functionName, self->functionName) == cubsStringErrorNone);
        builder.fullyQualifiedName = functionName;
        builder.name = cubs_string_clone(&functionName);
    }

    if(self->hasRetType) {
        assert(self->retType.knownContext != NULL);
        builder.optReturnType = self->retType.knownContext;
    }

    StackVariablesAssignment stackAssignment = cubs_stack_assignment_init(&self->variables);
    builder.stackSpaceRequired = stackAssignment.requiredFrameSize;

    // arguments
    for(size_t i = 0; i < self->argCount; i++) {
        cubs_function_builder_add_arg(&builder, self->variables.variables[i].context);
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

        const TokenType variableNameToken = token;
        assert(variableNameToken == IDENTIFIER && "Expected identifier for function argument variable name");
        const CubsStringError variableNameErr = cubs_string_init(&info.name, iter->current.value.identifier);
        assert(variableNameErr == cubsStringErrorNone && "Invalid UTF8 variable identifier");
        
        const TokenType colonToken = cubs_token_iter_next(iter);
        assert(colonToken == COLON_SYMBOL && "Expected \':\' following function argument variable name");

        const TokenType typeNameToken = cubs_token_iter_next(iter);
        switch(typeNameToken) {
            case INT_KEYWORD: {
                info.context = &CUBS_INT_CONTEXT;
            } break;
            // case IDENTIFIER: { // TODO handle other types
            //     info.taggedName = iter->currentMetadata.identifier;
            // } break;
            default: {
                assert(false && "Unexpected token following variable name and ':'");
            } break;
        }

        cubs_stack_variables_array_push(&variables, info);

        // move iterator forward. while loop will check this
        token = cubs_token_iter_next(iter);
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

AstNode cubs_function_node_init(TokenIter *iter)
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
        bool endsWithReturn = false;

        TokenType token = cubs_token_iter_next(iter);
        while(token != RIGHT_BRACE_SYMBOL) {
            endsWithReturn = false;
            if(token == TOKEN_NONE) {
                break;
            }
            switch(token) {
                case RETURN_KEYWORD: 
                {
                    AstNode returnNode = cubs_return_node_init(iter, &self->variables);
                    ast_node_array_push(&self->items, returnNode);
                    endsWithReturn = true;
                } break;
                case CONST_KEYWORD: // fallthrough
                case MUT_KEYWORD: 
                {
                    AstNode variableDeclarationNode = cubs_variable_declaration_node_init(iter, &self->variables);
                    ast_node_array_push(&self->items, variableDeclarationNode);
                } break;
                default: 
                {
                    assert(false && "Invalid token in function statements");
                } break;
            }
            token = cubs_token_iter_next(iter);
        }

        if(endsWithReturn == false) {
            AstNode emptyReturnNode = cubs_return_node_init_empty();
            ast_node_array_push(&self->items, emptyReturnNode);
        }
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &function_node_vtable};
    return node;
}