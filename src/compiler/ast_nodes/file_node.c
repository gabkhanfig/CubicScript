#include "file_node.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../platform/mem.h"
#include "function_node.h"
#include "struct_node.h"
#include <stdio.h>
#include "../../util/panic.h"

static void file_node_deinit(FileNode* self) {
    ast_node_array_deinit(&self->functions);
    ast_node_array_deinit(&self->structs);
    cubs_free(self, sizeof(FileNode), _Alignof(FileNode));
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

    for(uint32_t i = 0; i < self->functions.len; i++) {
        const AstNode node = self->functions.nodes[i];
        assert(node.vtable->compile != NULL);
        ast_node_compile(&node, program);
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

    { // function node
        const TokenType next = cubs_token_iter_next(iter);
        if(next == TOKEN_NONE) { // end of file

        } else {
            switch(next) {
                case FN_KEYWORD: {
                    const AstNode functionNode = cubs_function_node_init(iter);
                    ast_node_array_push(&self->functions, functionNode);
                } break;
                case STRUCT_KEYWORD: {
                    const AstNode structNode = cubs_struct_node_init(iter);
                    ast_node_array_push(&self->structs, structNode);
                } break;
                default: {
                    fprintf(stderr, "Unexpected token [%d]\n", next);
                    cubs_panic("Found unexpected token when parsing file node");
                } break;
            }         
        }
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &file_node_vtable};
    return node;
}


