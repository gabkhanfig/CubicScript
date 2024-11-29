#include "function_node.h"
#include "return_node.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../platform/mem.h"
#include "../../primitives/context.h"
#include "../../interpreter/bytecode.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../../interpreter/function_definition.h"
#include "../../primitives/string/string.h"

static void function_node_deinit(FunctionNode* self) {
    ast_node_array_deinit(&self->items);
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

    { // return type
        switch(self->retInfo.retTag) {
            case functionReturnNone: break;

            case functionReturnToken: {

                switch(self->retInfo.retType.token) {
                    case INT_LITERAL: {
                        builder.optReturnType = &CUBS_INT_CONTEXT;
                    } break;
                }
            } break;

            case functionReturnIdentifier: {
                assert(false && "Cannot handle return values other than none and int");
            } break;
        }
    }

    { // arguments
    }

    { // statements
        for(size_t i = 0; i < self->items.len; i++) {
            const AstNode node = self->items.nodes[i];
            // TODO allow nodes that don't just do code gen, such as nested structs maybe? or lambdas? to determine
            assert(node.vtable->buildFunction != NULL);
            ast_node_build_function(node.ptr, &builder, NULL); // TODO stack variable assignment
        }
    }

    cubs_function_builder_build(&builder, program);
}

static AstNodeVTable function_node_vtable = {
    .deinit = (AstNodeDeinit)&function_node_deinit,
    .compile = (AstNodeCompile)&function_node_compile,
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

        if(token == RIGHT_BRACKET_SYMBOL) { // function has no statements

        } else {
            // for now only 1 statement, being a return statement
            assert(token == RETURN_KEYWORD);
            AstNode returnNode = cubs_return_node_init(iter);
            ast_node_array_push(&self->items, returnNode);
        }
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &function_node_vtable};
    return node;
}