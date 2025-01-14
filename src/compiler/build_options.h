#pragma once

#include "../c_basic_types.h"
#include "../primitives/string/string.h"

// TODO need to work for both reading from disk, and reading from memory.
// Writing the memory to a file is not a valid option, as if a crash occurs 
// before those files can be cleaned up, it'll unnecessarily use user storage.

// struct CubsModule;

// typedef struct CubsModuleSourceGraph {

// } CubsModuleSourceGraph;

typedef struct CubsModule {
    CubsString name;
    CubsStringSlice rootSource;
    // const struct CubsModule* moduleDependencies;
    // size_t dependenciesLen;
    // CubsModuleSourceGraph graph;
} CubsModule;

/// Should 0 initialize.
typedef struct CubsBuildOptions {
    CubsModule* modules;
    size_t modulesLen;
    size_t _modulesCapacity;
} CubsBuildOptions;

#ifdef __cplusplus
extern "C" {
#endif

CubsModule cubs_module_clone(const CubsModule* self);

void cubs_module_deinit(CubsModule* self);

/// Copies `module`.
void cubs_build_options_add_module(CubsBuildOptions* self, const CubsModule* module);

void cubs_build_options_deinit(CubsBuildOptions* self);

#ifdef __cplusplus
}
#endif
