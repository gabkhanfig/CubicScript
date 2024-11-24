#include "../ast.h"

typedef struct ReturnNode {
    bool hasReturn;
    Token retInfo;
    TokenMetadata retValue;
} ReturnNode;

AstNode cubs_return_node_init(TokenIter* iter);
