#ifndef TYPE_MAP_H
#define TYPE_MAP_H

//! Doesn't need "erasing" functionality, just insert, find, and mutable find

#include <stddef.h>
#include "../primitives/string/string_slice.h"

struct ProgramTypeContext;
struct ProtectedArena;

typedef struct TypeMap {
    /// An array holding all elements. Is valid to `self.elements[self.count - 1]`
    struct CubsTypeContext** allStructs;
    size_t count;
    size_t capacity;
    void* qualifiedGroups;
    size_t qualifiedGroupCount;
    size_t available;
} TypeMap;

static const TypeMap STRUCT_MAP_INITIALIZER = {0};

/// Find a script struct given a fully qualified function name.
/// Returns NULL if function `name` doesn't exist.
const struct CubsTypeContext* cubs_type_map_find(
    const TypeMap* self, struct CubsStringSlice fullyQualifiedName
);

/// Find a script function given a fully qualified function name.
/// Returns NULL if function `name` doesn't exist.
/// # Debug Asserts
/// The context is owned by the program, and isn't user defined.
/// User defined contexts may not be mutated.
struct CubsTypeContext* cubs_type_map_find_mut(
    TypeMap* self, struct CubsStringSlice fullyQualifiedName
);

void cubs_type_map_insert(
    TypeMap *self, struct ProtectedArena* arena, struct ProgramTypeContext* context
);

#endif