#pragma once

#include "script_value.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"

extern const CubsTypeContext CUBS_BOOL_CONTEXT;
extern const CubsTypeContext CUBS_INT_CONTEXT;
extern const CubsTypeContext CUBS_FLOAT_CONTEXT;
extern const CubsTypeContext CUBS_STRING_CONTEXT;
extern const CubsTypeContext CUBS_ARRAY_CONTEXT;
extern const CubsTypeContext CUBS_SET_CONTEXT;
extern const CubsTypeContext CUBS_MAP_CONTEXT;
extern const CubsTypeContext CUBS_OPTION_CONTEXT;

/// Always returns a valid pointer
/// # Debug Asserts
/// - `tag != cubsValueTagNone`
/// - `tag != cubsValueTagUserStruct`
const CubsTypeContext* cubs_primitive_context_for_tag(CubsValueTag tag);