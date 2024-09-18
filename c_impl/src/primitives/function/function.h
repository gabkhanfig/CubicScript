#pragma once

#include "../../c_basic_types.h"
#include "../../program/function_call_args.h"

typedef enum CubsFunctionType {
    cubsFunctionPtrTypeC = 0,
    cubsFunctionPtrTypeScript = 1,
    /// Ensure at least 4 bytes
    _CUBS_FUNCTION_PTR_TYPE_MAX_VALUE = 0x7FFFFFFF,
} CubsFunctionType;

typedef union CubsFunctionPtr {
    CubsCFunctionPtr externC;
    const void* script;
} CubsFunctionPtr;

typedef struct CubsFunction {
    CubsFunctionPtr func;
    CubsFunctionType funcType;
} CubsFunction;

#ifdef __cplusplus
extern "C" {
#endif

CubsFunction cubs_function_init_c(CubsCFunctionPtr func);

/// Returns a structure used to push function arguments onto the script stack, or...
/// TODO extern C calling stuff
CubsFunctionCallArgs cubs_function_start_call(const CubsFunction* self);

#ifdef __cplusplus
} // extern "C"
#endif

