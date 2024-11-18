#pragma once

#include "program.h"
#include "protected_arena.h"
#include "../sync/locks.h"
#include "function_map.h"

typedef struct {
    ProtectedArena arena;
    CubsProgramContext context;
    CubsMutex contextMutex;
    FunctionMap functionMap;
} ProgramInner;

/// If `params.context == NULL`, uses the default context. Otherwise, copies `params.context`, taking ownership of it, 
/// and setting the original reference to `NULL`, ie. `params.context->ptr = NULL`.
CubsProgram cubs_program_init(CubsProgramInitParams params);

void _cubs_internal_program_runtime_error(const CubsProgram* self, CubsProgramRuntimeError err, const char* message, size_t messageLength);