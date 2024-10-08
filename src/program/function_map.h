#pragma once

//! Doesn't need "erasing" functionality, just insert and find

#include <stddef.h>
#include "../primitives/string/string.h"

typedef struct CubsScriptFunctionPtr CubsScriptFunctionPtr;
typedef struct FunctionMapQualifiedGroup FunctionMapQualifiedGroup;
typedef struct ProtectedArena ProtectedArena;

/// Maps all of the script functions. Must be zero initialized.
typedef struct FunctionMap {
    /// An array holding all of the functions. Is valid to `self.allFunctions[self.count - 1]`
    struct CubsScriptFunctionPtr** allFunctions;
    size_t allFunctionsCount;
    size_t allFunctionsCapacity;
    struct FunctionMapQualifiedGroup* qualifiedGroups;
    size_t qualifiedGroupCount;
    size_t available;
} FunctionMap;

static const FunctionMap FUNCTION_MAP_INITIALIZER = {0};

/// Probably unnecessary, as deinitializing the entire arena itself should free all the functions and stuff.
//void cubs_function_map_deinit(FunctionMap* self, struct ProtectedArena* arena);

/// Find a script function given a fully qualified function name.
/// Returns NULL if function `name` doesn't exist.
const CubsScriptFunctionPtr* cubs_function_map_find(const FunctionMap* self, CubsStringSlice fullyQualifiedName);

void cubs_function_map_insert(FunctionMap *self, ProtectedArena* arena, CubsScriptFunctionPtr* function);