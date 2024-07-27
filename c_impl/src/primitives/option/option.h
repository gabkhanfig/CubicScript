#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

/// If `optionalValue != NULL`, takes ownership. Otherwise, this is a none option.
//CubsOption cubs_option_init_primitive(CubsValueTag tag, void* optionalValue);

/// If `optionalValue != NULL`, takes ownership. Otherwise, this is a none option.
CubsOption cubs_option_init(const CubsTypeContext* context, void* optionalValue);

void cubs_option_deinit(CubsOption* self);

CubsOption cubs_option_clone(const CubsOption* self);

/// Always returns a valid pointer.
/// # Debug Asserts
/// `self->isSome`
const void* cubs_option_get(const CubsOption* self);

/// Always returns a valid pointer.
/// # Debug Asserts
/// `self->isSome`
void* cubs_option_get_mut(CubsOption* self);

/// memcpy's the owned some value into `out`, relinquishing ownership.
/// # Debug Asserts
/// `self->isSome`
void cubs_option_take(void* out, CubsOption* self);

bool cubs_option_eql(const CubsOption* self, const CubsOption* other);

size_t cubs_option_hash(const CubsOption* self);
