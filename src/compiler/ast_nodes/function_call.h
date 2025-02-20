#ifndef FUNCTION_CALL_H
#define FUNCTION_CALL_H

#include <stddef.h>
#include <stdbool.h>
#include "../../primitives/string/string_slice.h"
//#include "../../primitives/function/function.h"

struct ExprValue;
struct TokenIter;
struct StackVariablesArray;
struct AstNode;
struct FunctionDependencies;

typedef struct FunctionCallNode {
    CubsStringSlice functionName;
    bool hasReturnVariable;
    /// Only used if `hasReturnVariable` is true
    size_t returnVariable;
    struct ExprValue* args;
    size_t argsLen;
    size_t argsCapacity;
    // Unknown until type resolution
    //CubsFunction function;
} FunctionCallNode;

struct AstNode cubs_function_call_node_init(
    CubsStringSlice functionName, 
    bool hasReturnVariable,
    size_t returnVariable,
    struct TokenIter* iter,
    struct StackVariablesArray* variables,
    struct FunctionDependencies* dependencies
);

#endif