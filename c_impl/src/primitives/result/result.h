#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

/// If `optionalErrorMetadata` is NULL, `optionalErrorTag` can be any garbage value, including 0.
CubsError cubs_error_init_unchecked(CubsString errorName, void* optionalErrorMetadata, CubsValueTag optionalErrorTag);

/// If `optionalErrorMetadata` is NULL, `optionalErrorTag` can be any garbage value, including 0.
/// If non-null, takes ownership of the raw value.
CubsError cubs_error_init_raw_unchecked(CubsString errorName, CubsRawValue* optionalErrorMetadata, CubsValueTag optionalErrorTag);

/// If `optionalErrorMetadata` is non-null, takes ownership of it.
CubsError cubs_error_init(CubsString errorName, CubsTaggedValue* optionalErrorMetadata);

void cubs_error_deinit(CubsError* self);

/// If `NULL`, means this error has no metadata.
const CubsTaggedValue* cubs_error_metadata(const CubsError* self);

CubsTaggedValue cubs_error_take_metadata_unchecked(CubsError* self);

/// Returns true if there was metadata to take, and false otherwise.
bool cubs_error_take_metadata(CubsTaggedValue* out, CubsError* self);

typedef enum CubsResultError {
    cubsResultErrorNone = 0,
    cubsResultErrorIsOk = 1,
    cubsResultErrorIsErr = 2,
} CubsResultError;

CubsResult cubs_result_init_ok_unchecked(CubsValueTag okTag, void* okValue);

CubsResult cubs_result_init_ok_raw_unchecked(CubsValueTag okTag, CubsRawValue* okValue);

CubsResult cubs_result_init_ok(CubsTaggedValue okValue);

CubsResult cubs_result_init_err(CubsValueTag okTag, CubsError err);

void cubs_result_deinit(CubsResult* self);

CubsValueTag cubs_result_ok_tag(const CubsResult* self);

size_t cubs_result_size_of_ok(const CubsResult* self);

bool cubs_result_is_ok(const CubsResult* self);

/// Takes out the ok variant of the result, storing it in `outOk`, invalidating `self`.
/// Subsequent calls to this AFTER the first one will yield zeroed mem stored in `outOk`.
/// Debug asserts `cubs_result_is_ok(self)`.
void cubs_result_ok_unchecked(void *outOk, CubsResult *self);

/// Takes out the ok variant of the result, storing it in `outOk`, invalidating `self`.
/// Subsequent calls to this AFTER the first one will yield zeroed mem stored in `outOk`.
/// If `!cubs_error_is_ok(self)`, returns an error code.
CubsResultError cubs_result_ok(void *outOk, CubsResult *self);

/// Takes out the ok variant of the result, storing it in `outOk`, invalidating `self`.
/// Subsequent calls to this AFTER the first one will yield zeroed mem stored in `outOk`.
/// Debug asserts `!cubs_result_is_ok(self)`.
CubsError cubs_result_err_unchecked(CubsResult* self);

/// Takes out the ok variant of the result, storing it in `outOk`, invalidating `self`.
/// Subsequent calls to this AFTER the first one will yield zeroed mem stored in `outOk`.
/// If `cubs_error_is_ok(self)`, returns an error code.
CubsResultError cubs_result_err(CubsError* out, CubsResult* self);