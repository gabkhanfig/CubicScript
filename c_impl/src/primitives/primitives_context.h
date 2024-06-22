#pragma once

#include "script_value.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"

extern const CubsStructContext CUBS_BOOL_CONTEXT;
extern const CubsStructContext CUBS_INT_CONTEXT;
extern const CubsStructContext CUBS_FLOAT_CONTEXT;
extern const CubsStructContext CUBS_STRING_CONTEXT;
extern const CubsStructContext CUBS_ARRAY_CONTEXT;

/// Always returns a valid pointer
/// # Debug Asserts
/// - `tag != cubsValueTagNone`
/// - `tag != cubsValueTagUserStruct`
const CubsStructContext* cubs_primitive_context_for_tag(CubsValueTag tag);