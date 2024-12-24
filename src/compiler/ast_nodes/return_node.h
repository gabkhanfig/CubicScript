#include "../ast.h"
#include "../../primitives/string/string.h"

struct StackVariablesArray;

typedef struct ReturnNode {
    bool hasReturn;
    Token retInfo;
    /// Index within the stack variables to find the name of the return value.
    size_t variableNameIndex;
} ReturnNode;

AstNode cubs_return_node_init(TokenIter* iter, struct StackVariablesArray* variables);
