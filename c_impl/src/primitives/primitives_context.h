#pragma once

#include <stdbool.h>
#include <stddef.h>

typedef void (*CubsStructDestructorFn)(void* self);
typedef void (*CubsStructCloneFn)(void* dst, const void* self);
typedef bool (*CubsStructEqlFn)(const void* self, const void* other);
typedef size_t (*CubsStructHashFn)(const void* self);
/// Is both RTTI, and a VTable for certain *optional* functionality, such as on-destruction,
/// comparison operations, hashing, etc. 
// TODO implement for script only structs
typedef struct CubsTypeContext {
    /// In bytes.
    size_t sizeOfType;
    /// Can be NULL
    CubsStructDestructorFn destructor;
    /// Can be NULL
    CubsStructCloneFn clone;
    /// Can be NULL
    CubsStructEqlFn eql;
    /// Can be NULL
    CubsStructHashFn hash;
    /// Can be NULL, only used for debugging purposes
    const char* name;
    /// Is the length of `name`. Can be 0. Only used for debugging purposes
    size_t nameLength;
} CubsTypeContext;

extern const CubsTypeContext CUBS_BOOL_CONTEXT;
extern const CubsTypeContext CUBS_INT_CONTEXT;
extern const CubsTypeContext CUBS_FLOAT_CONTEXT;
extern const CubsTypeContext CUBS_STRING_CONTEXT;
extern const CubsTypeContext CUBS_ARRAY_CONTEXT;
extern const CubsTypeContext CUBS_SET_CONTEXT;
extern const CubsTypeContext CUBS_MAP_CONTEXT;
extern const CubsTypeContext CUBS_OPTION_CONTEXT;
extern const CubsTypeContext CUBS_ERROR_CONTEXT;
extern const CubsTypeContext CUBS_RESULT_CONTEXT;
extern const CubsTypeContext CUBS_UNIQUE_CONTEXT;
extern const CubsTypeContext CUBS_SHARED_CONTEXT;
extern const CubsTypeContext CUBS_WEAK_CONTEXT;