#include "../ast.h"
#include "../../primitives/string/string.h"

struct StackVariablesArray;

typedef struct ReturnNode {
    bool hasReturn;
    Token retInfo;
    TokenMetadata retValue;
    CubsString variableName;
} ReturnNode;

AstNode cubs_return_node_init(TokenIter* iter, struct StackVariablesArray* variables);
