#ifndef FUNCTION_DEPENDENCY_GRAPH_H
#define FUNCTION_DEPENDENCY_GRAPH_H

#include <stddef.h>
#include "../../primitives/string/string_slice.h"

// TODO handle C functions

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

//struct FunctionEntry;

/// Heap allocated type
typedef struct FunctionEntry {
    size_t hash;
    CubsStringSlice name;
    /// Array of non-owning reference. Range is `0 - dependenciesLen - 1`
    FunctionEntry** dependencies;
    size_t dependenciesLen;
} FunctionEntry;

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

void function_dependency_graph_deinit(FunctionDependencyGraph* self);

typedef struct FunctionDependencyGraphIter {
    const FunctionDependencyGraph* graph;
    size_t currentIndex;
    size_t currentLayer;
} FunctionDependencyGraphIter;

FunctionDependencyGraphIter function_dependency_graph_iter_init(const FunctionDependencyGraph* graph);

/// Returns NULL if there is no next function entry
const FunctionEntry* function_dependency_graph_iter_next(FunctionDependencyGraphIter* self);

typedef struct FunctionDependencyGraphBuilder {
    /// Array of owned heap-allocated function entries
    struct FunctionEntry** entries;
    size_t len;
    size_t capacity;
} FunctionDependencyGraphBuilder;

/// Can be used after `function_dependency_graph_builder_build(...)`, 
/// however is not required.
void function_dependency_graph_builder_deinit(FunctionDependencyGraphBuilder* self);

void function_dependency_graph_builder_push(FunctionDependencyGraphBuilder* self, FunctionDependencies function);

/// Also deinitializes the builder.
FunctionDependencyGraph function_dependency_graph_builder_build(FunctionDependencyGraphBuilder* self);

#endif
