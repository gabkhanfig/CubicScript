#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "script_value.h"

typedef enum CubsArrayError {
  cubsArrayErrorNone = 0,
  cubsArrayErrorOutOfRange = 1,
  // Enforce enum size is at least 32 bits, which is `int` on most platforms
  _CUBS_ARRAY_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsArrayError;

/// https://cplusplus.com/reference/string/string/npos/
static const size_t CUBS_ARRAY_N_POS = -1;

/// Does not allocate any memory, just sets the correct bitmasks.
CubsArray cubs_array_init(CubsValueTag tag);

void cubs_array_deinit(CubsArray* self);

CubsValueTag cubs_array_tag(const CubsArray* self);

size_t cubs_array_len(const CubsArray* self);

/// Takes ownership of `value`. Accessing the memory of `value` after this 
/// function is undefined behaviour.
/// Does not validate that `value` has the correct active union.
void cubs_array_push_unchecked(CubsArray* self, CubsRawValue value);

/// Takes ownership of `value`. Accessing the memory of `value` after this 
/// function is undefined behaviour.
/// Asserts that `value` is using the correct active union.
/// NOTE should this return an error if the tags are mismatched, or just assert?
void cubs_array_push(CubsArray* self, CubsTaggedValue value);

/// In debug, asserts that `index` is less than the `cubs_array_len(self)`.
const CubsRawValue* cubs_array_at_unchecked(const CubsArray* self, size_t index);

/// If `index >= cubs_array_len(self)`, returns `cubsArrayErrorOutOfRange`,
/// otherwise returns `cubsArrayErrorNone`.
CubsArrayError cubs_array_at(const CubsRawValue** out, const CubsArray* self, size_t index);