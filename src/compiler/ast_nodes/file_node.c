#include "file_node.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../platform/mem.h"
#include "function_node.h"
#include "struct_node.h"
#include <stdio.h>
#include "../../util/panic.h"
#include "../graph/scope.h"

static bool string_slice_eql(CubsStringSlice lhs, CubsStringSlice rhs) {
    if(lhs.len != rhs.len) {
        return false;
    }

    for(size_t i = 0; i < lhs.len; i++) {
        if(lhs.str[i] != rhs.str[i]) {
            return false;
        }
    }

    return true;
}

static void file_node_deinit(FileNode* self) {
    ast_node_array_deinit(&self->functions);
    ast_node_array_deinit(&self->structs);
    function_dependency_graph_deinit(&self->functionDependencyGraph);
    cubs_scope_deinit(self->scope);
    FREE_TYPE(Scope, self->scope);
    *self = (FileNode){0};

    FREE_TYPE(FileNode, self);
}

static CubsStringSlice file_node_to_string(const FileNode* self) {
    const CubsStringSlice emptyString = {0};
    return emptyString;
}

static void file_node_compile(FileNode* self, struct CubsProgram* program) {
    for(uint32_t i = 0; i < self->structs.len; i++) {
        const AstNode node = self->structs.nodes[i];
        assert(node.vtable->defineType != NULL);
        ast_node_define_type(&node, program);
    }

    { // compile functions in dependency order
        FunctionDependencyGraphIter iter = function_dependency_graph_iter_init(&self->functionDependencyGraph);

        const FunctionEntry* entry = function_dependency_graph_iter_next(&iter);
        while(entry != NULL) {
            const CubsStringSlice functionName = entry->name;
            // TODO maybe this can be optimized
            for(uint32_t i = 0; i < self->functions.len; i++) {
                AstNode node = self->functions.nodes[i];
                assert(node.vtable->nodeType == astNodeTypeFunction);

                const FunctionNode* functionNode = (const FunctionNode*)node.ptr;
                if(string_slice_eql(functionNode->functionName, functionName)) {
                    assert(node.vtable->compile != NULL);
                    ast_node_compile(&node, program);
                    break;
                }
            }
            entry = function_dependency_graph_iter_next(&iter);
        }
    }
}

static AstNodeVTable file_node_vtable = {
    .nodeType = astNodeTypeFile,
    .deinit = (AstNodeDeinit)&file_node_deinit,
    .compile = (AstNodeCompile)&file_node_compile,
    .toString = (AstNodeToString)&file_node_to_string,
    .buildFunction = NULL,
    .defineType = NULL,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

AstNode cubs_file_node_init(TokenIter *iter)
{
    FileNode* self = (FileNode*)cubs_malloc(sizeof(FileNode), _Alignof(FileNode));
    *self = (FileNode){0};

    assert(iter->current.tag == TOKEN_NONE && "File node should begin at the start of the iterator");

    FunctionDependencyGraphBuilder functionDependencyBuilder = {0};

    self->scope = MALLOC_TYPE(Scope);
    *self->scope = (Scope){0};

    {
        TokenType next = cubs_token_iter_next(iter);
        while(next != TOKEN_NONE) {
            switch(next) {
                case FN_KEYWORD: {
                    const AstNode functionNode = cubs_function_node_init(iter, &functionDependencyBuilder, self->scope);
                    ast_node_array_push(&self->functions, functionNode);
                } break;
                case STRUCT_KEYWORD: {
                    const AstNode structNode = cubs_struct_node_init(iter, self->scope);
                    ast_node_array_push(&self->structs, structNode);
                } break;
                default: {
                    fprintf(stderr, "Unexpected token [%d]\n", next);
                    cubs_panic("Found unexpected token when parsing file node");
                } break;
            }
            next = cubs_token_iter_next(iter);
        }
    }

    self->functionDependencyGraph = function_dependency_graph_builder_build(&functionDependencyBuilder);

    const AstNode node = {.ptr = (void*)self, .vtable = &file_node_vtable};
    return node;
}


