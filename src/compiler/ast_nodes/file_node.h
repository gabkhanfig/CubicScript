#include "../ast.h"
#include "ast_node_array.h"

typedef struct FileNode {
    AstNodeArray functions;
    AstNodeArray structs;
} FileNode;

AstNode cubs_file_node_init(TokenIter* iter);
