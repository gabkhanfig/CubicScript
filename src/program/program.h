#pragma once

#include "../c_basic_types.h"
#include "program_runtime_error.h"
#include "../primitives/function/function.h"
#include "../primitives/string/string.h"
#include "../compiler/build_options.h"

#ifdef __cplusplus
extern "C" {
#endif

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

CubsProgram cubs_program_compile(CubsProgramInitParams params, const CubsBuildOptions* build);

void cubs_program_deinit(CubsProgram* self);

/// Finds a script function with the name `fullyQualifiedName`. If it exists,
/// stores the value in the out-param `outFunc`, and returns true.
/// Otherwise returns false.
bool cubs_program_find_function(const CubsProgram* self, CubsFunction* outFunc, CubsStringSlice fullyQualifiedName);

#ifdef __cplusplus
} // extern "C"
#endif
