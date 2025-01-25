#include "../ast.h"
#include "ast_node_array.h"
#include "../stack_variables.h"
#include "type_resolution_info.h"

typedef struct FunctionNode {
    CubsStringSlice functionName;
    AstNodeArray items;
    bool hasRetType;
    /// Should not be used if `hasRetType == false`.
    TypeResolutionInfo retType;
    StackVariablesArray variables;
    /// indices `0` to `argCount` will be the function argument variables
    /// stored within `variables`.
    size_t argCount;
} FunctionNode;

AstNode cubs_function_node_init(TokenIter* iter);