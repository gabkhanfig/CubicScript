#pragma once;

#include <stddef.h>
#include "script_value.h"

typedef enum CubsStringError {
    cubsStringErrorNone = 0,
    cubsStringErrorInvalidUtf8 = 1,
    cubsStringErrorIndexOutOfBounds = 2,

    // Enforce enum size is at least 32 bits, which is `int` on most platforms
    _CUBS_STRING_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsStringError;

typedef struct CubsStringSlice {
  const char* str;
  size_t len;
} CubsStringSlice;

/// In debug mode, will validate that a null terminator does not exist before `slice.len`.
/// Will always validate that the string is valid utf8, returning the appropriate error if it's not.
CubsStringError cubs_string_init(CubsString* stringToInit, CubsStringSlice slice);

/// In debug mode, will validate that a null terminator does not exist before `slice.len`.
/// Does not check that `slice` is valid utf8.
CubsString cubs_string_init_unchecked(CubsStringSlice slice);

/// Decrements the ref count, freeing the string if all references have been deinitialized.
void cubs_string_deinit(CubsString* self);

/// Increments the ref count, copying the inner pointer.
CubsString cubs_string_clone(const CubsString* self);

size_t cubs_string_len(const CubsString* self);

