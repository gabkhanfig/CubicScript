#pragma once

#include "script_value.h"

extern const CubsTypeContext CUBS_BOOL_CONTEXT;
extern const CubsTypeContext CUBS_INT_CONTEXT;
extern const CubsTypeContext CUBS_FLOAT_CONTEXT;
extern const CubsTypeContext CUBS_STRING_CONTEXT;
extern const CubsTypeContext CUBS_ARRAY_CONTEXT;
extern const CubsTypeContext CUBS_SET_CONTEXT;
extern const CubsTypeContext CUBS_MAP_CONTEXT;
extern const CubsTypeContext CUBS_OPTION_CONTEXT;
extern const CubsTypeContext CUBS_ERROR_CONTEXT;
extern const CubsTypeContext CUBS_RESULT_CONTEXT;
extern const CubsTypeContext CUBS_UNIQUE_CONTEXT;
extern const CubsTypeContext CUBS_SHARED_CONTEXT;
extern const CubsTypeContext CUBS_WEAK_CONTEXT;

/// Always returns a valid pointer
/// # Debug Asserts
/// - `tag != cubsValueTagNone`
/// - `tag != cubsValueTagUserStruct`
const CubsTypeContext* cubs_primitive_context_for_tag(CubsValueTag tag);