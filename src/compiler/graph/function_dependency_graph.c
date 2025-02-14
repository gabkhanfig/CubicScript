#include "function_dependency_graph.h"
#include "../../platform/mem.h"
#include <assert.h>
#include <stdbool.h>
#include <string.h>

static bool string_slice_eql(CubsStringSlice lhs, CubsStringSlice rhs) {
    if(lhs.len != rhs.len) {
        return false;
    }

    for(size_t i = 0; i < lhs.len; i++) {
        if(lhs.str[i] != rhs.str[i]) {
            return false;
        }
    }

    return true;
}

void function_dependencies_deinit(FunctionDependencies *self)
{
    if(self->dependencies != NULL) {
        assert(self->dependenciesCapacity > 0);

        FREE_TYPE_ARRAY(CubsStringSlice, self->dependencies, self->dependenciesCapacity);
        *self = (FunctionDependencies){0};
    } else {
        assert(self->dependenciesCapacity == 0);
    }
}

void function_dependencies_push(FunctionDependencies *self, CubsStringSlice dependencyName)
{
    assert((string_slice_eql(self->name, dependencyName)  == false)&& "Cannot do recursive function calls");

    for(size_t i = 0; i < self->dependenciesLen; i++) {
        if(string_slice_eql(self->dependencies[i], dependencyName)) {
            // don't bother with duplicates
            return;
        }
    }

    if(self->dependenciesCapacity == self->dependenciesLen) {
        const size_t newCapacity = self->dependenciesCapacity == 0 ? 1 : self->dependenciesCapacity * 2;
        CubsStringSlice* newDependencies = MALLOC_TYPE_ARRAY(CubsStringSlice, newCapacity);

        if(self->dependencies != NULL) {
            for(size_t i = 0; i < self->dependenciesLen; i++) {
                newDependencies[i] = self->dependencies[i];
            }
        }

        self->dependencies = newDependencies;
        self->dependenciesCapacity = newCapacity;
    }

    self->dependencies[self->dependenciesLen] = dependencyName;
    self->dependenciesLen += 1;
}

typedef struct FunctionDepGraphLayer {
    FunctionDependencies* functions;
    size_t len;
    size_t capacity;
} FunctionDepGraphLayer;

const size_t NPOS = -1;

/// Returns the index within the layer, otherwise `NPOS`.
static size_t graph_layer_find(const FunctionDepGraphLayer* self, CubsStringSlice name) {
    for(size_t i = 0; i < self->len; i++) {
        if(string_slice_eql(self->functions[i].name, name)) {
            return i;
        }
    }
    return NPOS;
}

static FunctionDependencies graph_layer_remove(FunctionDepGraphLayer* self, size_t index) {
    assert(index < self->len);

    FunctionDependencies out = self->functions[index];
    for(size_t i = index; i < self->len - 1; i++) {
        // shift over all entries
        self->functions[i] = self->functions[i + 1];
    }
    self->len -= 1;
    return out;
}

static void graph_layer_push(FunctionDepGraphLayer* self, FunctionDependencies function) {
    assert(graph_layer_find(self, function.name) == NPOS);

    if(self->capacity == self->len) {
        const size_t newCapacity = self->capacity == 0 ? 1 : self->capacity * 2;
        FunctionDependencies* newFunctions = MALLOC_TYPE_ARRAY(FunctionDependencies, newCapacity);
        for(size_t i = 0; i < self->len; i++) {
            newFunctions[i] = self->functions[i];
        }

        if(self->functions != NULL) {
            FREE_TYPE_ARRAY(FunctionDependencies, self->functions, self->capacity);
        }
        self->functions = newFunctions;
        self->capacity = newCapacity;
    }

    self->functions[self->len] = function;
    self->len += 1;
}

typedef struct FunctionEntry {
    bool isValid;
    /// Only usable if `isValid` is true
    size_t layer;
    /// Only usable if `isValid` is true
    size_t index;
} FunctionEntry;

static FunctionEntry function_dependency_graph_find(const FunctionDependencyGraph* self, CubsStringSlice name) {
    for(size_t i = 0; i < self->layerCount; i++) {
        const size_t foundIndex = graph_layer_find(&self->layers[i], name);
        if(foundIndex == NPOS) continue;

        const FunctionEntry entry = {.isValid = true, .layer = i, .index = foundIndex};
        return entry;
    }

    return (FunctionEntry){.isValid = false, .layer = NPOS, .index = NPOS};
}

static void ensure_has_layers(FunctionDependencyGraph* self, const size_t requiredLayers) {
    if(self->layerCount >= requiredLayers) {
        return;
    }

    FunctionDepGraphLayer* newLayers = MALLOC_TYPE_ARRAY(FunctionDepGraphLayer, requiredLayers);
    size_t i = 0;
    for(; i < self->layerCount; i++) {
        newLayers[i] = self->layers[i]; // move over old data
    }
    for(; i < requiredLayers; i++) {
        newLayers[i] = (FunctionDepGraphLayer){0};
    }

    FREE_TYPE_ARRAY(FunctionDepGraphLayer, self->layers, self->layerCount);

    self->layers = newLayers;
    self->layerCount = requiredLayers;
}

typedef struct {
    size_t layer;
    size_t index;
} EntryTrack;

/// Any function that depends on `name` must be shifted to be on a layer below `mustBeBelow`.
static void shift_all_dependencies(FunctionDependencyGraph* self, const size_t mustBeBelow, const CubsStringSlice name) {
    assert(self->layerCount >= mustBeBelow);

    EntryTrack* entries = NULL;
    size_t len = 0;
    size_t capacity = 0;
    for(size_t i = 0; i < self->layerCount; i++) {
        
    }
}

void function_dependency_graph_push(FunctionDependencyGraph *self, FunctionDependencies dependencies)
{
    #if _DEBUG
    { // ensure no duplicates
        const FunctionEntry entry = function_dependency_graph_find(self, dependencies.name);
        assert(!entry.isValid);
    }
    #endif

    if(dependencies.dependenciesLen == 0) {     
        // no dependencies, so can exist on the top layer       
        ensure_has_layers(self, 1);
        graph_layer_push(&self->layers[0], dependencies);
        return;
    }

    size_t layerToPut = 1;
    // Since this function has dependencies, it must be placed lower than all dependencies
    for(size_t i = 0; i < dependencies.dependenciesLen; i++) {
        const FunctionEntry entry = function_dependency_graph_find(self, dependencies.dependencies[i]);
        if(!entry.isValid) continue;

        layerToPut = layerToPut > entry.layer ? layerToPut : entry.layer; // max between the two
    }

    // Anything that depends on this function will need to be placed lower than it,
    // and those dependencies will also need to be placed lower cyclically
    ensure_has_layers(self, layerToPut + 1); // preallocate
    shift_all_dependencies(self, layerToPut, dependencies.name);
}
