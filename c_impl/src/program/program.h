#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

typedef struct CubsProgram {
    void* _inner;
} CubsProgram;

typedef enum CubsProgramRuntimeError {
    cubsProgramRuntimeErrorNone = 0,
    cubsProgramRuntimeErrorNullDereference = 1,
    cubsProgramRuntimeErrorAdditionIntegerOverflow = 2,
    cubsProgramRuntimeErrorSubtractionIntegerOverflow = 3,
    cubsProgramRuntimeErrorMultiplicationIntegerOverflow = 4,
    cubsProgramRuntimeErrorDivisionIntegerOverflow = 5,
    cubsProgramRuntimeErrorDivideByZero = 6,
    cubsProgramRuntimeErrorModuloByZero = 7,
    cubsProgramRuntimeErrorRemainderByZero = 8,
    cubsProgramRuntimeErrorPowerIntegerOverflow = 9,
    cubsProgramRuntimeErrorZeroToPowerOfNegative = 10,
    cubsProgramRuntimeErrorInvalidBitShiftAmount = 11,
    cubsProgramRuntimeErrorFloatToIntOverflow = 12,
    cubsProgramRuntimeErrorNegativeRoot = 13,
    cubsProgramRuntimeErrorLogarithmZeroOrNegative = 14,
    cubsProgramRuntimeErrorArcsinUndefined = 15,
    cubsProgramRuntimeErrorArccosUndefined = 16,
    cubsProgramRuntimeErrorHyperbolicArccosUndefined = 17,
    cubsProgramRuntimeErrorHyperbolicArctanUndefined = 18,

    _CUBS_PROGRAM_RUNTIME_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsProgramRuntimeError;

/// Returns the same names as found in Zig's `(program.zig).Program.RuntimeError`
const char* cubs_program_runtime_error_as_string(CubsProgramRuntimeError err);

// TODO stack trace
typedef void(*CubsProgramErrorCallback)(void* self, const CubsProgram* program, const void* stackTrace, CubsProgramRuntimeError err, const char* message, size_t messageLength);
typedef void(*CubsProgramContextPrint)(void* self, const CubsProgram* program, const char* message, size_t messageLength);
typedef void(*CubsProgramContextDeinit)(void* self);

typedef struct CubsProgramContextVTable {
    CubsProgramErrorCallback errorCallback;
    CubsProgramContextPrint print;
    CubsProgramContextDeinit deinit;
} CubsProgramContextVTable;

/// Context for handling virtual machine logic.
/// Is owned by a `CubsProgram`, and is fully thread safe, so no synchronization is needed
/// in the actual vtable / instance implementation.
typedef struct CubsProgramContext {
    void* ptr;
    const CubsProgramContextVTable* vtable;
} CubsProgramContext;

typedef struct CubsProgramInitParams {
    /// Can be NULL
    CubsProgramContext* context;
} CubsProgramInitParams;

/// If `params.context == NULL`, uses the default context. Otherwise, copies `params.context`, taking ownership of it, 
/// and setting the original reference to `NULL`, ie. `params.context->ptr = NULL`.
CubsProgram cubs_program_init(CubsProgramInitParams params);

CubsProgram cubs_program_deinit(CubsProgram* self);