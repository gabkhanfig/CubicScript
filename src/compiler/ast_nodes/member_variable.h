#ifndef MEMBER_VARIABLE_NODE_H
#define MEMBER_VARIABLE_NODE_H

#include "type_resolution_info.h"
#include "../ast.h"

typedef struct MemberVariableNode {
    CubsStringSlice name;
    TypeResolutionInfo typeInfo;
} MemberVariableNode;

AstNode cubs_member_variable_init(TokenIter* iter);



#endif