#include "../ast.h"
#include "ast_node_array.h"
#include "../graph/function_dependency_graph.h"

typedef struct FileNode {
    AstNodeArray functions;
    AstNodeArray structs;
    FunctionDependencyGraph functionDependencyGraph;
} FileNode;

AstNode cubs_file_node_init(TokenIter* iter);
