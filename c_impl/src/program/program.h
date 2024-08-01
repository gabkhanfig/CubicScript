#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include "program_runtime_error.h"

typedef struct CubsProgram {
    void* _inner;
} CubsProgram;

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

void cubs_program_deinit(CubsProgram* self);