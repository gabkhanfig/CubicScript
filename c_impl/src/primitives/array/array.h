#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

typedef struct CubsArrayConstIter {
    const CubsArray* _arr;
    size_t _nextIndex;
    const void* value;
} CubsArrayConstIter;

typedef struct CubsArrayMutIter {
    CubsArray* _arr;
    size_t _nextIndex;
    void* value;
} CubsArrayMutIter;

typedef struct CubsArrayReverseConstIter {
    const CubsArray* _arr;
    size_t _priorIndex;
    const void* value;
} CubsArrayReverseConstIter;

typedef struct CubsArrayReverseMutIter {
    CubsArray* _arr;
    size_t _priorIndex;
    void* value;
} CubsArrayReverseMutIter;

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

CubsArray cubs_array_init_user_struct(const CubsTypeContext* context);

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

/// Does equality check for `self` having the same elements, in the same order, as `other`.
/// # Debug Asserts
/// - `self->context->eql != NULL`
/// - `other->context->eql != NULL`
/// - `self->context->eql == other->context->eql`
/// - `self->context->sizeOfType == other->context->sizeOfType`
/// - `self->context->tag == other->context->tag`
bool cubs_array_eql(const CubsArray* self, const CubsArray* other);

size_t cubs_array_hash(const CubsArray* self);

CubsArrayConstIter cubs_array_const_iter_begin(const CubsArray* self);

/// For C++ interop
CubsArrayConstIter cubs_array_const_iter_end(const CubsArray* self);

bool cubs_array_const_iter_next(CubsArrayConstIter* iter);

CubsArrayMutIter cubs_array_mut_iter_begin(CubsArray* self);

/// For C++ interop
CubsArrayMutIter cubs_array_mut_iter_end(CubsArray* self);

bool cubs_array_mut_iter_next(CubsArrayMutIter* iter);

CubsArrayReverseConstIter cubs_array_reverse_const_iter_begin(const CubsArray* self);

/// For C++ interop
CubsArrayReverseConstIter cubs_array_reverse_const_iter_end(const CubsArray* self);

bool cubs_array_reverse_const_iter_next(CubsArrayReverseConstIter* iter);

CubsArrayReverseMutIter cubs_array_reverse_mut_iter_begin(CubsArray* self);

/// For C++ interop
CubsArrayReverseMutIter cubs_array_reverse_mut_iter_end(CubsArray* self);

bool cubs_array_reverse_mut_iter_next(CubsArrayReverseMutIter* iter);