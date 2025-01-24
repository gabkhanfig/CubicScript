#ifndef MEMBER_VARIABLE_NODE_H
#define MEMBER_VARIABLE_NODE_H

#include "../ast.h"

struct CubsTypeContext;

union UVariableTypeInfo {
    const struct CubsTypeContext* knownContext;
    CubsStringSlice typeName;
};

enum EVariableTypeInfo {
    VariableTypeInfoKnown,
    VariableTypeInfoTypeName,
};

typedef struct VariableTypeInfo {
    enum EVariableTypeInfo tag;
    union UVariableTypeInfo info;
} VariableTypeInfo;

typedef struct MemberVariableNode {
    CubsStringSlice name;
    VariableTypeInfo typeInfo;
} MemberVariableNode;

AstNode cubs_member_variable_init(TokenIter* iter);



#endif