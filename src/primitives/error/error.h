#pragma once

#include "../../c_basic_types.h"
#include "../string/string.h"

struct CubsTypeContext;

typedef struct CubsError {
    CubsString name;
    /// Can be NULL. Must be cast to the appropriate type.
    void* metadata;
    /// Is the type of `metadata`. Can be NULL if the error has no metadata.
    const struct CubsTypeContext* context;
} CubsError;


#ifdef __cplusplus
extern "C" {
#endif

/// Pass in 0 for `optionalTag` for a NULL metadata value.
/// Takes ownership of the memory at `optionalMetadata` if non-null.
/// Creates a buffer to store the memory of `optionalMetadata` in.
//CubsError cubs_error_init_primitive(CubsString name, void* optionalMetadata, CubsValueTag optionalTag);

/// Takes ownership of `name`.
/// Takes ownership of the memory at `optionalMetadata` if non-null.
/// Creates a buffer to store the memory of `optionalMetadata` in.
/// # Debug Assert
/// If `optionalMetadata != NULL` -> asserts `optionalContext != NULL`
CubsError cubs_error_init(CubsString name, void* optionalMetadata, const struct CubsTypeContext* optionalContext);

void cubs_error_deinit(CubsError* self);

CubsError cubs_error_clone(const CubsError* self);

/// memcpy's the owned some value into `out`, relinquishing ownership.
/// # Debug Asserts
/// `self->metadata != NULL && self->context != NULL`
void cubs_error_take_metadata(void* out, CubsError* self);

bool cubs_error_eql(const CubsError* self, const CubsError* other); // TODO should equality comparison take into account metadata, or just error name?

size_t cubs_error_hash(const CubsError* self); // TODO should hash take into account metadata, or just error name?

#ifdef __cplusplus
} // extern "C"
#endif