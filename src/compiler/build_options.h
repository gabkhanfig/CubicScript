#pragma once

#include "../c_basic_types.h"
#include "../primitives/string/string.h"

// TODO need to work for both reading from disk, and reading from memory.
// Writing the memory to a file is not a valid option, as if a crash occurs 
// before those files can be cleaned up, it'll unnecessarily use user storage.

struct CubsModule;

typedef struct CubsModulesSlice {
    const struct CubsModule* ptr;
    size_t len;
} CubsModulesSlice;

typedef struct CubsModule {
    CubsString name;
    CubsModulesSlice dependencies;
} CubsModule;

/// Can 0 initialize.
typedef struct CubsBuildOptions {
    CubsModulesSlice modules;
} CubsBuildOptions;

