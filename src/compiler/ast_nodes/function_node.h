#include "../ast.h"
#include "ast_node_array.h"
#include "../stack_variables.h"

enum FunctionReturnEType {
    functionReturnNone = 0,
    functionReturnToken,
    /// struct identifier for example
    functionReturnIdentifier,
};

union FunctionReturnUType {
    Token token;
    CubsStringSlice identifier;
};

typedef struct FunctionReturnType {
    enum FunctionReturnEType retTag;
    union FunctionReturnUType retType;
} FunctionReturnType;

typedef struct FunctionNode {
    CubsStringSlice functionName;
    AstNodeArray items;
    FunctionReturnType retInfo;
    StackVariablesArray variables;
} FunctionNode;

AstNode cubs_function_node_init(TokenIter* iter);