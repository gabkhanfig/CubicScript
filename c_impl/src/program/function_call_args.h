#pragma once

#include "../c_basic_types.h"

typedef struct CubsFunctionPtr CubsFunctionPtr;
typedef struct CubsTypeContext CubsTypeContext;
typedef struct CubsProgram CubsProgram;

/// Helper struct to push function arguments into the next script stack frame.
typedef struct CubsScriptFunctionCallArgs {
    const CubsFunctionPtr* func;
    int _inner[2];
} CubsScriptFunctionCallArgs;

#ifdef __cplusplus
extern "C" {
#endif

void cubs_function_push_arg(CubsScriptFunctionCallArgs* self, void* arg, const struct CubsTypeContext* typeContext);

/// Takes ownership of `self`, effectively deinitializing it. Stores the return value in `outReturn`.
/// If the function has no return value, pass in `NULL` for `outReturn`.
void cubs_function_call(CubsScriptFunctionCallArgs self, const struct CubsProgram* program, void* outReturn, const struct CubsTypeContext** outContext);

#ifdef __cplusplus
} // extern "C"
#endif