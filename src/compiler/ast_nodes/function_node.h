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
    TokenType token;
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
    /// indices `0` to `argCount` will be the function argument variables
    /// stored within `variables`.
    size_t argCount;
} FunctionNode;

AstNode cubs_function_node_init(TokenIter* iter);