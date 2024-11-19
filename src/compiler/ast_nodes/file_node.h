#include "../ast.h"

typedef struct FileNode {
    AstNode* items;
    size_t itemsLen;
    size_t itemsCapacity;
} FileNode;

AstNode cubs_file_node_init(const TokenIter* iter);
