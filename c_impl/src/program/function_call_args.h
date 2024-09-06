#pragma once

#include "../c_basic_types.h"

typedef struct CubsFunction CubsFunction;
typedef struct CubsTypeContext CubsTypeContext;
typedef struct CubsProgram CubsProgram;

/// Helper struct to push function arguments into the next script stack frame.
typedef struct CubsFunctionCallArgs {
    const CubsFunction* func;
    /// Do not access
    int _inner[2];
} CubsFunctionCallArgs;

/// Holds the return value and return context destinations for returning from a script-compatible function.
/// For functions with no return value, 0 initializing this struct is fine.
typedef struct CubsFunctionReturn {
    void* value;
    const struct CubsTypeContext** context;
} CubsFunctionReturn;

/// Holds everything necessary to get the arguments of a C function call, as well as returning values.
/// Scripts and `CubsFunction` use this.
typedef struct CubsCFunctionHandler {
    const struct CubsProgram* program;
    /// Do not access
    size_t _frameBaseOffset;
    /// Do not access
    int _offsetForArgs;
    int argCount;
    CubsFunctionReturn outReturn;
} CubsCFunctionHandler;

/// Function pointer definition for C functions that are accessible within scripts, or `CubsFunction`.
/// See `CubsCFunctionHandler`.
/// @return 0 on success, or a non 0 user defined error code.
typedef int(*CubsCFunctionPtr)(CubsCFunctionHandler);

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

/// Defined in `interpreter.c`.
/// Moves the argument at `argIndex` to the memory at `outArg`.
/// `argIndex` is an array index, in which `0` is the first argument, `1` is the second argument, etc. 
/// regardless of the actual sizes of the argument data types.
/// If `outContext == NULL`, does not bother setting it.
extern void cubs_function_take_arg(const CubsCFunctionHandler* self, size_t argIndex, void* outArg, const struct CubsTypeContext** outContext);

/// `memcpy`'s `returnValue` to the destination held in `self`, and sets the return context in `self` to `returnContext`.
/// Takes ownership of `self`, effectively deinitializing it.
/// NOTE - no actual deinitialization logic is necessary, just don't use the same CubsFunctionReturn twice. 
void cubs_function_return_set_value(CubsCFunctionHandler self, void* returnValue, const struct CubsTypeContext* returnContext);

#ifdef __cplusplus
} // extern "C"
#endif