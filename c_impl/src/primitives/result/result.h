#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

/// If `okValue == NULL`, is an empty ok value. Pass in `0` for `okTag`.
//CubsResult cubs_result_init_ok_primitive(void* okValue, CubsValueTag okTag);

/// If `okValue == NULL`, is an empty ok value. Pass in `NULL` for `okContext`.
CubsResult cubs_result_init_ok(void* okValue, const CubsTypeContext* okContext);

/// If `okTag == 0`, is an empty ok value.
//CubsResult cubs_result_init_err_primitive(CubsError errValue, CubsValueTag okTag);

/// If `okContext == NULL`, is an empty ok value.
CubsResult cubs_result_init_err(CubsError errValue, const CubsTypeContext* okContext);

void cubs_result_deinit(CubsResult* self);

const void* cubs_result_get_ok(const CubsResult* self);

void* cubs_result_get_ok_mut(CubsResult* self);

/// Invalidates `self`. Still safe to call `cubs_result_deinit` after, but unnecessary.
void cubs_result_take_ok(void* outOk, CubsResult* self);

const CubsError* cubs_result_get_err(const CubsResult* self);

CubsError* cubs_result_get_err_mut(CubsResult* self);

/// Invalidates `self`. Still safe to call `cubs_result_deinit` after, but unnecessary.
CubsError cubs_result_take_err(CubsResult* self);