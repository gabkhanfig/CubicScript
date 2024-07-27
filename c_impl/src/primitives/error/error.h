#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

/// Pass in 0 for `optionalTag` for a NULL metadata value.
/// Takes ownership of the memory at `optionalMetadata` if non-null.
/// Creates a buffer to store the memory of `optionalMetadata` in.
//CubsError cubs_error_init_primitive(CubsString name, void* optionalMetadata, CubsValueTag optionalTag);

/// Takes ownership of `name`.
/// Takes ownership of the memory at `optionalMetadata` if non-null.
/// Creates a buffer to store the memory of `optionalMetadata` in.
/// # Debug Assert
/// If `optionalMetadata != NULL` -> asserts `optionalContext != NULL`
CubsError cubs_error_init(CubsString name, void* optionalMetadata, const CubsTypeContext* optionalContext);

void cubs_error_deinit(CubsError* self);

CubsError cubs_error_clone(const CubsError* self);

/// memcpy's the owned some value into `out`, relinquishing ownership.
/// # Debug Asserts
/// `self->metadata != NULL && self->context != NULL`
void cubs_error_take_metadata(void* out, CubsError* self);

bool cubs_error_eql(const CubsError* self, const CubsError* other); // TODO should equality comparison take into account metadata, or just error name?

size_t cubs_error_hash(const CubsError* self); // TODO should hash take into account metadata, or just error name?