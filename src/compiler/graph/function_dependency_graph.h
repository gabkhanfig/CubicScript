#ifndef FUNCTION_DEPENDENCY_GRAPH_H
#define FUNCTION_DEPENDENCY_GRAPH_H

#include <stddef.h>
#include "../../primitives/string/string_slice.h"
//#include "../ast.h"

/// Typedef for clarity.
/// Since ast nodes have a fixed memory location (memory allocation + vtable),
/// we can store a shallow copy of the node as a reference type.
//typedef AstNode AstNodeRef;

/// Should be zero initialized. Set `name` to the name of the function.
typedef struct FunctionDependencies {
    CubsStringSlice name;
    CubsStringSlice* dependencies;
    size_t dependenciesLen;
    size_t dependenciesCapacity;
} FunctionDependencies;

void function_dependencies_deinit(FunctionDependencies* self);

/// If an entry that is already stored is passed in, it will be ignored safely
void function_dependencies_push(FunctionDependencies* self, CubsStringSlice dependencyName);

struct FunctionDepGraphLayer;

/// Tree/graph structure for tracking which functions depend on what other functions
/// 
/// Each function is associated with a name as a key, and stores its 
/// dependencies also as names.
/// Two functions may not depend on each other at the same time.
/// A function may not depend on itself. Recursion is not supported at this time.
typedef struct FunctionDependencyGraph {
    struct FunctionDepGraphLayer* layers;
    size_t layerCount;
} FunctionDependencyGraph;

/// Takes ownership of `dependencies`. Cannot have duplicate entries.
void function_dependency_graph_push(FunctionDependencyGraph* self, FunctionDependencies dependencies);

#endif
