#include "../ast.h"
#include "ast_node_array.h"
#include "../stack_variables.h"
#include "../parse/type_resolution_info.h"

struct FunctionDependencyGraphBuilder;
struct Scope;

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
    struct Scope* scope;
} FunctionNode;

AstNode cubs_function_node_init(
    TokenIter* iter,
    struct FunctionDependencyGraphBuilder* dependencyBuilder,
    struct Scope* outerScope
);