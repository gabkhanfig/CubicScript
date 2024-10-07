#pragma once

#include "../../c_basic_types.h"
#include "../../program/function_call_args.h"

typedef enum CubsFunctionType {
    cubsFunctionPtrTypeC = 0,
    cubsFunctionPtrTypeScript = 1,
    /// Ensure at least 4 bytes
    _CUBS_FUNCTION_PTR_TYPE_USED_BITS = 1,
    _CUBS_FUNCTION_PTR_TYPE_MAX_VALUE = 0x7FFFFFFF,
} CubsFunctionType;

typedef union CubsFunctionPtr {
    CubsCFunctionPtr externC;
    const CubsScriptFunctionPtr* script;
} CubsFunctionPtr;

/// Can be trivially cloned through memcpy or whatever means
typedef struct CubsFunction {
    CubsFunctionPtr func;
    CubsFunctionType funcType;
} CubsFunction;

#ifdef __cplusplus
extern "C" {
#endif

CubsFunction cubs_function_init_c(CubsCFunctionPtr func);

bool cubs_function_eql(const CubsFunction* self, const CubsFunction* other);

size_t cubs_function_hash(const CubsFunction* self);

/// Returns a structure used to push function arguments onto the script stack, or...
/// TODO extern C calling stuff
CubsFunctionCallArgs cubs_function_start_call(const CubsFunction* self);

#ifdef __cplusplus
} // extern "C"
#endif

