#ifndef STRUCT_NODE_H
#define STRUCT_NODE_H

#include "../ast.h"
#include "ast_node_array.h"

typedef struct StructNode {
    CubsStringSlice name;
    AstNodeArray memberVariables;
} StructNode;

AstNode cubs_struct_node_init(TokenIter* iter);

#endif

