#pragma once

#include "../c_basic_types.h"

typedef struct CubsFunction CubsFunction;
typedef struct CubsTypeContext CubsTypeContext;
typedef struct CubsProgram CubsProgram;

/// Helper struct to push function arguments into the next script stack frame.
typedef struct CubsScriptFunctionCallArgs {
    const CubsFunction* func;
    int _inner[2];
} CubsScriptFunctionCallArgs;

#ifdef __cplusplus
extern "C" {
#endif

/// Pushes an argument into either the next script stack frame in order, or pushes to a C function call.
/// Calling `cubs_function_push_arg(...)` without also eventually calling `cubs_function_call(...)` after
/// pushing all arguments is undefined behaviour.
void cubs_function_push_arg(CubsScriptFunctionCallArgs* self, void* arg, const struct CubsTypeContext* typeContext);

/// Takes ownership of `self`, effectively deinitializing it.
/// NOTE - no actual deinitialization logic is necessary, just don't use the same CubsScriptFunctionCallArgs twice. 
/// Stores the return value in `outReturn`.
/// If the function has no return value, pass in `NULL` for `outReturn`.
void cubs_function_call(CubsScriptFunctionCallArgs self, const struct CubsProgram* program, void* outReturn, const struct CubsTypeContext** outContext);

#ifdef __cplusplus
} // extern "C"
#endif