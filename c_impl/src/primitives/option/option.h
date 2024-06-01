#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

typedef enum CubsOptionError {
  /// Weird naming, but this means there is no error
  cubsOptionErrorNone = 0,
  /// This means the option was a none option.
  cubsOptionErrorIsNone = 1,
  // Enforce enum size is at least 32 bits, which is `int` on most platforms
  _CUBS_OPTION_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsOptionError;

/// Takes ownership of `value`.
CubsOption cubs_option_init_unchecked(CubsValueTag tag, void* value);

/// Takes ownership of `value`.
CubsOption cubs_option_init_raw_unchecked(CubsValueTag tag, CubsRawValue value);

/// Takes ownership of `value`.
CubsOption cubs_option_init(CubsTaggedValue value);

void cubs_option_deinit(CubsOption* self);

const void* cubs_option_get_unchecked(const CubsOption* self);

void* cubs_option_get_mut_unchecked(CubsOption* self);

CubsOptionError cubs_option_get(const void** out, const CubsOption* self);

CubsOptionError cubs_option_get_mut(void** out, CubsOption* self);

CubsOptionError cubs_option_take(void* out, CubsOption* self);
