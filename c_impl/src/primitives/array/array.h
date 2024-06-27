#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

typedef enum CubsArrayError {
  cubsArrayErrorNone = 0,
  cubsArrayErrorOutOfRange = 1,
  // Enforce enum size is at least 32 bits, which is `int` on most platforms
  _CUBS_ARRAY_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsArrayError;

/// https://cplusplus.com/reference/string/string/npos/
static const size_t CUBS_ARRAY_N_POS = -1;

/// Does not allocate any memory, just sets the correct bitmasks.
CubsArray cubs_array_init_primitive(CubsValueTag tag);

CubsArray cubs_array_init_user_struct(const CubsStructContext* context);

void cubs_array_deinit(CubsArray* self);

CubsArray cubs_array_clone(const CubsArray* self);

/// Takes ownership of the memory at `value`, copying the memory at that location into the array.
/// Accessing the memory at `value` after this call is undefined behaviour.
/// Does not validate that `value` has the correct active union, nor that its valid script value memory.
void cubs_array_push_unchecked(CubsArray* self, void* value);

/// Mutation operations on `self`. may invalidate the returned pointer.
/// In debug, asserts that `index` is less than the `cubs_array_len(self)`.
const void* cubs_array_at_unchecked(const CubsArray* self, size_t index);

/// Mutation operations on `self`. may invalidate `out`.
/// If `index >= cubs_array_len(self)`, returns `cubsArrayErrorOutOfRange`,
/// otherwise returns `cubsArrayErrorNone`.
/// `out` must be a pointer to a variable of type `const CubsRawValue*`, as it's used 
/// to get the actual data.
CubsArrayError cubs_array_at(const void** out, const CubsArray* self, size_t index);

/// Mutation operations on `self`. may invalidate the returned pointer.
/// In debug, asserts that `index` is less than the `cubs_array_len(self)`.
void* cubs_array_at_mut_unchecked(CubsArray* self, size_t index);

/// Mutation operations on `self`. may invalidate `out`.
/// If `index >= cubs_array_len(self)`, returns `cubsArrayErrorOutOfRange`,
/// otherwise returns `cubsArrayErrorNone`.
/// `out` must be a pointer to a variable of type `CubsRawValue*`, as it's used 
/// to get the actual data.
CubsArrayError cubs_array_at_mut(void** out, CubsArray* self, size_t index);