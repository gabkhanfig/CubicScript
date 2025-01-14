#include "../ast.h"
#include "ast_node_array.h"

typedef struct FileNode {
    AstNodeArray items;
} FileNode;

AstNode cubs_file_node_init(TokenIter* iter);
