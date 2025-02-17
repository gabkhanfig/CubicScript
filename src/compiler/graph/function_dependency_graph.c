#include "function_dependency_graph.h"
#include "../../platform/mem.h"
#include "../../util/hash.h"
#include "../../util/panic.h"
#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>

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

static size_t string_slice_hash(CubsStringSlice slice) {
    return bytes_hash((const void*)slice.str, slice.len);
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

const size_t NPOS = -1;

typedef struct FunctionDepGraphLayer {
    FunctionEntry** entries;
    size_t len;
    size_t capacity;
} FunctionDepGraphLayer;

static void function_dep_graph_layer_push(FunctionDepGraphLayer* self, FunctionEntry* entry) {
    if(self->capacity == self->len) {
        const size_t newCapacity = self->capacity == 0 ? 4 : self->capacity * 2;
        FunctionEntry** newEntries = MALLOC_TYPE_ARRAY(FunctionEntry*, newCapacity);
        if(self->entries != NULL) {
            for(size_t i = 0; i < self->len; i++) {
                newEntries[i] = self->entries[i];
            }
            FREE_TYPE_ARRAY(FunctionEntry*, self->entries, self->capacity);
        }
        self->entries = newEntries;
        self->capacity = newCapacity;
    }

    self->entries[self->len] = entry;
    self->len += 1;
}


/// Returns `NPOS` if cannot find
static size_t graph_builder_find(const FunctionDependencyGraphBuilder* self, size_t hash, CubsStringSlice name) {
    for(size_t i = 0; i < self->len; i++) {
        const FunctionEntry* entry = self->entries[i];
        if(entry->hash == hash) {
            if(string_slice_eql(entry->name, name)) {
                return i;
            }
        }
    }
    return NPOS;
}

static void graph_builder_ensure_capacity(FunctionDependencyGraphBuilder* self, size_t requiredCapacity) {
    if(self->capacity >= requiredCapacity) {
        return;
    }

    FunctionEntry** newEntries = MALLOC_TYPE_ARRAY(FunctionEntry*, requiredCapacity);
    if(self->entries != NULL) {
        for(size_t i = 0; i < self->len; i++) {
            newEntries[i] = self->entries[i];
        }
        FREE_TYPE_ARRAY(FunctionEntry*, self->entries, self->capacity);
    }

    self->entries = newEntries;
    self->capacity = requiredCapacity;
}

static function_entry_deinit(FunctionEntry* self) {
    if(self->dependencies == NULL) return;

    FREE_TYPE_ARRAY(FunctionEntry*, self->dependencies, self->dependenciesLen);
    self->dependencies = NULL;
    self->dependenciesLen = 0;
}

void function_dependency_graph_deinit(FunctionDependencyGraph *self)
{
    if(self->layers == NULL) return;

    for(size_t layerIter = 0; layerIter < self->layerCount; layerIter++) {
        FunctionDepGraphLayer* layer = &self->layers[layerIter];
        for(size_t i = 0; i < layer->len; i++) {
            function_entry_deinit(layer->entries[i]);
        }
    }

    FREE_TYPE_ARRAY(FunctionDepGraphLayer, self->layers, self->layerCount);
    self->layers = NULL;
    self->layerCount = 0;
}

FunctionDependencyGraphIter function_dependency_graph_iter_init(const FunctionDependencyGraph *graph)
{
    return (FunctionDependencyGraphIter){.graph = graph, .currentLayer = 0, .currentIndex = 0};
}

const FunctionEntry *function_dependency_graph_iter_next(FunctionDependencyGraphIter *self)
{
    if(self->currentLayer > self->graph->layerCount) {
        return NULL;
    }

    const FunctionDepGraphLayer* layer = &self->graph->layers[self->currentLayer];

    assert(self->currentIndex < layer->len);
    const FunctionEntry* entry = layer->entries[self->currentIndex];

    self->currentIndex += 1;
    if(self->currentIndex >= layer->len) {
        self->currentIndex = 0;
        self->currentLayer += 1;
    }

    return entry;
}

void function_dependency_graph_builder_deinit(FunctionDependencyGraphBuilder *self)
{
    if(self->entries == NULL) return;

    for(size_t i = 0; i < self->len; i++) {
        FREE_TYPE(FunctionEntry*,  self->entries[i]);
    }
    FREE_TYPE_ARRAY(FunctionEntry*, self->entries, self->capacity);

    *self = (FunctionDependencyGraphBuilder){.entries = NULL, .len = 0, .capacity = 0};
}

void function_dependency_graph_builder_push(FunctionDependencyGraphBuilder *self, FunctionDependencies function)
{
    const size_t hash = string_slice_hash(function.name);
    const size_t alreadyExistPosition = graph_builder_find(self, hash, function.name);

    // Pre-allocate enough capacity, even if it will likely go unused in this call.
    // Add one and dependencies len for the actual function entry, along with the dependencies.
    graph_builder_ensure_capacity(self, self->capacity + 1 + function.dependenciesLen);

    FunctionEntry* entry = NULL;
    if(alreadyExistPosition == NPOS) {
        entry = MALLOC_TYPE(FunctionEntry);
        *entry = (FunctionEntry){
            .hash = hash, 
            .name = function.name, 
            .dependenciesLen = 0, 
            .dependencies = NULL
        };
        self->entries[self->len] = entry;
        self->len += 1;
    } else {
        // this is safe even after entries array reallocation, as the entries are allocated elsewhere
        entry = self->entries[alreadyExistPosition]; 
        assert(entry->dependenciesLen == 0 && "Expected function to not already have it's dependencies resolved");
        assert(entry->dependencies == NULL);
    }

    entry->dependenciesLen = function.dependenciesLen;
    // Array of non-owning pointers
    entry->dependencies = MALLOC_TYPE_ARRAY(FunctionEntry*, function.dependenciesLen);

    for(size_t i = 0; i < function.dependenciesLen; i++) {
        const CubsStringSlice dependencyName = function.dependencies[i];
        const size_t dependencyHash = string_slice_hash(dependencyName);
        const size_t dependencyAlreadyExistPosition = graph_builder_find(self, dependencyHash, dependencyName);

        FunctionEntry* dependencyEntry = NULL;
        if(dependencyAlreadyExistPosition == NPOS) {
            dependencyEntry = MALLOC_TYPE(FunctionEntry);
            *dependencyEntry = (FunctionEntry){
                .hash = dependencyHash, 
                .name = dependencyName, 
                .dependenciesLen = 0, 
                .dependencies = NULL
            };
            
            self->entries[self->len] = dependencyEntry;
            self->len += 1;
        } else {
            dependencyEntry = self->entries[dependencyAlreadyExistPosition];
        }

        entry->dependencies[i] = dependencyEntry;
    }

    function_dependencies_deinit(&function);
}

/// Check if the graph contains all the resolved dependencies of `entry`, up to layer `layersToCheck - 1`.
static bool all_dependencies_resolved(const FunctionDependencyGraph* self, const FunctionEntry* entry, const size_t layersToCheck) {
    assert(layersToCheck < self->layerCount);

    // This function may likely be a bottleneck
    // TODO benchmark and maybe optimize
    for(size_t depIter = 0; depIter < entry->dependenciesLen; depIter++) {
        const FunctionEntry* dependency = entry->dependencies[depIter];
        bool didFind = false;

        for(size_t layerIter = 0; layerIter < layersToCheck; layerIter++) {
            const FunctionDepGraphLayer* layer = &self->layers[layerIter];
            for(size_t i = 0; i < layer->len; i++) {
                if(dependency->hash != layer->entries[i]->hash) continue;

                if(string_slice_eql(dependency->name, layer->entries[i]->name)) {
                    didFind = true;
                    break;
                }
            }
            if(didFind) {
                break;
            }
        }

        if(didFind == false) {
            // This dependency is unresolved, therefore this function has unresolved dependencies
            return false;
        }
    }

    return true;
}

// Loop over and over until all functions are resolved
// A function is resolved when all of it's dependencies are resolved
// The first functions to get resolved are the functions with no dependencies

// TODO find circular dependenciess

FunctionDependencyGraph function_dependency_graph_builder_build(FunctionDependencyGraphBuilder *self)
{
    FunctionDependencyGraph graph = {0};
    graph.layers = MALLOC_TYPE_ARRAY(FunctionDepGraphLayer, 1);
    graph.layerCount = 1;

    FunctionEntry** entries = self->entries;
    size_t len = self->len;   
    size_t i = 0;
    
    { // Do first layer of functions with no dependencies
        FunctionDepGraphLayer* layer = &graph.layers[0];
        *layer = (FunctionDepGraphLayer){.entries = NULL, .len = 0, .capacity = 0};
        while(i < len) {
            FunctionEntry* entry = entries[i];
            if(entry->dependenciesLen != 0) {
                i += 1;
                continue;
            }

            function_dep_graph_layer_push(layer, entry);
            // shift down all remaining entries for subsequent loops
            for(size_t shiftIter = i; shiftIter < (len - 1); shiftIter++) {
                entries[shiftIter] = entries[shiftIter + 1];
                len -= 1;
            }
        }
        if(layer->len == 0) {
            cubs_panic("Failed to build function graph. No functions with no dependencies found.");
        }
    }

    while(len > 0) {
        { // reallocate
            FunctionDepGraphLayer* newLayers = MALLOC_TYPE_ARRAY(FunctionDepGraphLayer, graph.layerCount + 1);
            for(size_t layerIter = 0; layerIter < graph.layerCount; layerIter++) { // will always loop at least once
                newLayers[layerIter] = graph.layers[layerIter];
            }
            FREE_TYPE_ARRAY(FunctionDepGraphLayer, graph.layers, graph.layerCount);
            graph.layers = newLayers;
            graph.layerCount += 1;
        }

        FunctionDepGraphLayer* layer = &graph.layers[graph.layerCount - 1];
        *layer = (FunctionDepGraphLayer){.entries = NULL, .len = 0, .capacity = 0};
        i = 0;
        while(i < len) {
            FunctionEntry* entry = entries[i];
            if(!all_dependencies_resolved(&graph, entry, graph.layerCount - 1)) {
                i += 1;
                continue;
            }

            function_dep_graph_layer_push(layer, entry);
            // shift down all remaining entries for subsequent loops
            for(size_t shiftIter = i; shiftIter < (len - 1); shiftIter++) {
                entries[shiftIter] = entries[shiftIter + 1];
                len -= 1;
            }
        }
        if(layer->len == 0) {
            cubs_panic("Failed to build function graph. Could not resolve function dependencies.");
        }
    }

    FREE_TYPE_ARRAY(FunctionEntry*, entries, self->capacity);
    
    return graph;
}
