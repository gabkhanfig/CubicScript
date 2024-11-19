#include "file_node.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../platform/mem.h"

static void file_node_deinit(FileNode* self) {
    cubs_free(self, sizeof(FileNode), _Alignof(FileNode));
}

static CubsStringSlice file_node_to_string(const FileNode* self) {
    const CubsStringSlice emptyString = {0};
    return emptyString;
}

static AstNodeVTable file_node_vtable = {
    .deinit = (AstNodeDeinit)&file_node_deinit,
    .process = NULL,
    .toString = (AstNodeToString)&file_node_to_string,
};

AstNode cubs_file_node_init(const TokenIter *iter)
{
    FileNode* self = cubs_malloc(sizeof(FileNode), _Alignof(FileNode));
    const AstNode node = {.ptr = (void*)self, .vtable = &file_node_vtable};
    return node;
}


