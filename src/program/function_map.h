#pragma once

//! Doesn't need "erasing" functionality, just insert and find

#include <stddef.h>
#include "../primitives/string/string_slice.h"

struct CubsScriptFunctionPtr;
struct ProtectedArena;

typedef struct FunctionMap {
    /// An array holding all elements. Is valid to `self.elements[self.count - 1]`
    struct CubsScriptFunctionPtr** allFunctions;
    size_t count;
    size_t capacity;
    void* qualifiedGroups;
    size_t qualifiedGroupCount;
    size_t available;
} FunctionMap;

static const FunctionMap FUNCTION_MAP_INITIALIZER = {0};

/// Probably unnecessary, as deinitializing the entire arena itself should free all the functions and stuff.
//void cubs_function_map_deinit(FunctionMap* self, struct ProtectedArena* arena);

/// Find a script function given a fully qualified function name.
/// Returns NULL if function `name` doesn't exist.
const struct CubsScriptFunctionPtr* cubs_function_map_find(
    const FunctionMap* self, struct CubsStringSlice fullyQualifiedName
);

void cubs_function_map_insert(
    FunctionMap *self, struct ProtectedArena* arena, struct CubsScriptFunctionPtr* function
);
