#include "file_node.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../platform/mem.h"

static void file_node_deinit(FileNode* self) {
    ast_node_array_deinit(&self->items);
    cubs_free(self, sizeof(FileNode), _Alignof(FileNode));
}

static CubsStringSlice file_node_to_string(const FileNode* self) {
    const CubsStringSlice emptyString = {0};
    return emptyString;
}

static AstNodeVTable file_node_vtable = {
    .deinit = (AstNodeDeinit)&file_node_deinit,
    .compile = NULL,
    .toString = (AstNodeToString)&file_node_to_string,
    .buildFunction = NULL,
};

AstNode cubs_file_node_init(TokenIter *iter)
{
    FileNode* self = (FileNode*)cubs_malloc(sizeof(FileNode), _Alignof(FileNode));
    self->items = (AstNodeArray){0};

    const AstNode node = {.ptr = (void*)self, .vtable = &file_node_vtable};
    return node;
}


