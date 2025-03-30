#include "../ast.h"
#include "ast_node_array.h"
#include "../graph/function_dependency_graph.h"

struct Scope;

typedef struct FileNode {
    AstNodeArray functions;
    AstNodeArray structs;
    FunctionDependencyGraph functionDependencyGraph;
    struct Scope* scope;
} FileNode;

AstNode cubs_file_node_init(TokenIter* iter);
