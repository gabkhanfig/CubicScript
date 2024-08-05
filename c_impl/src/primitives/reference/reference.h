#pragma once

#ifndef __cplusplus

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#endif

#include "../script_value.h"

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

