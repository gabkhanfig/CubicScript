#pragma once

#include "../../c_basic_types.h"

struct CubsTypeContext;

typedef struct CubsConstRef {
    /// Safe to access. Should be cast to the appropriate type.
    /// Should never be NULL. Nullable references must be wrapped in a `CubsOption`.
    const void* ref;
    const struct CubsTypeContext* context;
} CubsConstRef;

typedef struct CubsMutRef {
    /// Safe to access. Should be cast to the appropriate type.
    /// Should never be NULL. Nullable references must be wrapped in a `CubsOption`.
    void* ref;
    const struct CubsTypeContext* context;
} CubsMutRef;

#ifdef __cplusplus
extern "C" {
#endif

/// Is true if they share the same reference, or the different references hold the same value.
bool cubs_const_ref_eql(const CubsConstRef* self, const CubsConstRef* other);

/// Assumes that `other` is of the same type as the type referenced in `self`.
bool cubs_const_ref_eql_value(const CubsConstRef* self, const void* other);

/// Hashes the referenced value.
size_t cubs_const_ref_hash(const CubsConstRef* self);

/// Is true if they share the same reference, or the different references hold the same value.
bool cubs_mut_ref_eql(const CubsMutRef* self, const CubsMutRef* other);

/// Assumes that `other` is of the same type as the type referenced in `self`.
bool cubs_mut_ref_eql_value(const CubsMutRef* self, const void* other);

/// Hashes the referenced value.
size_t cubs_mut_ref_hash(const CubsMutRef* self);

#ifdef __cplusplus
} // extern "C"
#endif

