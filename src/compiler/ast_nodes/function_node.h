#include "../ast.h"
#include "ast_node_array.h"

typedef struct FunctionNode {
    CubsStringSlice functionName;
    AstNodeArray items;
} FunctionNode;

AstNode cubs_function_node_init(TokenIter* iter);