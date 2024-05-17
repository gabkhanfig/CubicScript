#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "script_value.h"
#include "../util/ordering.h"

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

static const size_t CUBS_STRING_N_POS = 1ULL << 63;

/// In debug mode, will validate that a null terminator does not exist before `slice.len`.
/// Will always validate that the string is valid utf8, returning the appropriate error if it's not.
CubsStringError cubs_string_init(CubsString* stringToInit, CubsStringSlice slice);

/// In `_DEBUG`:
/// - Asserts that a null terminator does not exist before `slice.len`.
/// - Asserts that the slice is valid utf8.
///
/// If not `_DEBUG`, does not perform those checks.
CubsString cubs_string_init_unchecked(CubsStringSlice slice);

/// Decrements the ref count, freeing the string if all references have been deinitialized.
void cubs_string_deinit(CubsString* self);

/// Increments the ref count, copying the inner pointer.
CubsString cubs_string_clone(const CubsString* self);

size_t cubs_string_len(const CubsString* self);

/// Get an immutable reference to the slice that this string owns. This string slice is null terminated.
/// Mutation operations on this string may make the slice point to invalid memory.
/// If the string is empty, returns a slice where `.str == NULL` and `.len == 0`
CubsStringSlice cubs_string_as_slice(const CubsString* self);

/// Equality comparison of two strings. Uses 32 byte SIMD optimizations (AVX2 on x86) when available.
bool cubs_string_eql(const CubsString* self, const CubsString* other);

/// Equality comparison of a string and a string slice. Uses 32 byte SIMD optimizations (AVX2 on x86) when available.
/// If `slice.len == 0`, checks that string is empty.
///
/// TECHNICAL NOTE: Only derefences `slice.str` if `slice.len == 0`, so it can point to anything as long as `slice.len == 0`.
/// [undefined](https://ziglang.org/documentation/master/#undefined) in Zig, which is 0xAA... is safe for this function.
bool cubs_string_eql_slice(const CubsString* self, CubsStringSlice slice);

/// Compares two strings, returning the ordering between them.
CubsOrdering cubs_string_cmp(const CubsString* self, const CubsString* other);

size_t cubs_string_hash(const CubsString* self);

/// Returns `CUBS_STRING_N_POS` if the value is not found. Unfortunately C does not have optionals by default.
/// Otherwise, just returns the index where the substring starts.
size_t cubs_string_find(const CubsString* self, CubsStringSlice slice, size_t startIndex);