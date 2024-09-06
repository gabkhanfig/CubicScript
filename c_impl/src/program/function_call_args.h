#pragma once

#include "../c_basic_types.h"

typedef struct CubsFunction CubsFunction;
typedef struct CubsTypeContext CubsTypeContext;
typedef struct CubsProgram CubsProgram;

/// Helper struct to push function arguments into the next script stack frame.
typedef struct CubsFunctionCallArgs {
    const CubsFunction* func;
    int _inner[2];
} CubsFunctionCallArgs;

/// Struct to access arguments for C function calls.
typedef struct CubsCFunctionArgs {
    size_t _inner[2];
} CubsCFunctionArgs;

/// Holds the return value and return context destinations for returning from a script-compatible function.
/// For functions with no return value, 0 initializing this struct is fine.
typedef struct CubsFunctionReturn {
    void* value;
    const struct CubsTypeContext** context;
} CubsFunctionReturn;

/// Function pointer definition for C functions that are accessible within scripts, or `CubsFunction`.
/// @param outReturn Destination to move the return value to. If the function has no return value, 
/// `outReturn` will have both params as NULL. See `cubs_function_return_set_value(...)`.
/// @param args Holds the arguments for the function call. Does not need to be deinitialized.
/// @return 0 on success, any other value is an error.
typedef int(*CubsCFunctionPtr)(CubsCFunctionArgs args, CubsFunctionReturn outReturn);

#ifdef __cplusplus
extern "C" {
#endif

/// Pushes an argument into either the next script stack frame in order, or pushes to a C function call.
/// Calling `cubs_function_push_arg(...)` without also eventually calling `cubs_function_call(...)` after
/// pushing all arguments is undefined behaviour.
void cubs_function_push_arg(CubsFunctionCallArgs* self, void* arg, const struct CubsTypeContext* typeContext);

/// Takes ownership of `self`, effectively deinitializing it.
/// NOTE - no actual deinitialization logic is necessary, just don't use the same CubsScriptFunctionCallArgs twice. 
/// Stores the return value in `outReturn`.
/// If the function has no return value, pass in `NULL` for `outReturn`.
void cubs_function_call(CubsFunctionCallArgs self, const struct CubsProgram* program, CubsFunctionReturn outReturn);

/// `memcpy`'s `returnValue` to the destination held in `self`, and sets the return context in `self` to `returnContext`.
/// Takes ownership of `self`, effectively deinitializing it.
/// NOTE - no actual deinitialization logic is necessary, just don't use the same CubsFunctionReturn twice. 
void cubs_function_return_set_value(CubsFunctionReturn self, void* returnValue, const struct CubsTypeContext* returnContext);

#ifdef __cplusplus
} // extern "C"
#endif