#pragma once

#include "program.h"

/// If `params.context == NULL`, uses the default context. Otherwise, copies `params.context`, taking ownership of it, 
/// and setting the original reference to `NULL`, ie. `params.context->ptr = NULL`.
extern CubsProgram cubs_program_init(CubsProgramInitParams params);

extern void _cubs_internal_program_runtime_error(const CubsProgram* self, CubsProgramRuntimeError err, const char* message, size_t messageLength);