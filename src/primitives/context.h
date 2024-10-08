#pragma once

#include "function/function.h"

typedef struct CubsTypeContext {
    /// In bytes.
    size_t sizeOfType;
    /// Can be zeroed. Expects 1 argument as a mutable reference, and returns nothing
    CubsFunction destructor;
    /// Can be zeroed. Expects 1 argument as a const reference, and returns a value of the same type as the argument
    CubsFunction clone;
    /// Can be zeroed. Expects 2 arguments as const references, and returns a bool
    CubsFunction eql;
    /// Can be zeroed. Expectes 1 argument as a const reference, and returns a size_t / int64_t
    CubsFunction hash;
    /// Can be NULL, only used for debugging purposes
    const char* name;
    /// Is the length of `name`. Can be 0. Only used for debugging purposes
    size_t nameLength;
} CubsTypeContext;

#ifdef __cplusplus
extern "C" {
#endif

extern const CubsTypeContext CUBS_BOOL_CONTEXT;
extern const CubsTypeContext CUBS_INT_CONTEXT;
extern const CubsTypeContext CUBS_FLOAT_CONTEXT;
extern const CubsTypeContext CUBS_CHAR_CONTEXT;
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
extern const CubsTypeContext CUBS_FUNCTION_CONTEXT;
extern const CubsTypeContext CUBS_CONST_REF_CONTEXT;
extern const CubsTypeContext CUBS_MUT_REF_CONTEXT;

void cubs_context_fast_deinit(void* value, const CubsTypeContext* context);

void cubs_context_fast_clone(void* out, const void* value, const CubsTypeContext* context);

/// Assumes lhs and rhs are the same types
bool cubs_context_fast_eql(const void* lhs, const void* rhs, const CubsTypeContext* context);

size_t cubs_context_fast_hash(const void *value, const CubsTypeContext *context);

#ifdef __cplusplus
} // extern "C"
#endif