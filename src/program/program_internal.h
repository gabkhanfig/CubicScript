#pragma once

#include "program.h"
#include "protected_arena.h"
#include "../sync/locks.h"
#include "function_map.h"
#include "type_map.h"
#include "program_type_context.h"

typedef struct {
    ProtectedArena arena;
    CubsProgramContext context;
    CubsMutex contextMutex;
    FunctionMap functionMap;
    TypeMap typeMap;
} ProgramInner;

/// If `params.context == NULL`, uses the default context. Otherwise, copies `params.context`, taking ownership of it, 
/// and setting the original reference to `NULL`, ie. `params.context->ptr = NULL`.
CubsProgram cubs_program_init(CubsProgramInitParams params);

void _cubs_internal_program_runtime_error(const CubsProgram* self, CubsProgramRuntimeError err, const char* message, size_t messageLength);

CubsTypeContext* cubs_program_malloc_script_context(CubsProgram* self);

/// Allocates memory for `source`, and copies the contents to the memory 
/// region, returning a string slice of that region.
CubsStringSlice cubs_program_malloc_copy_string_slice(CubsProgram* self, CubsStringSlice source);

CubsTypeMemberContext* cubs_program_malloc_member_context_array(CubsProgram* self, size_t count);

/// Returns NULL if cannot find
const CubsTypeContext* cubs_program_find_type_context(const CubsProgram* self, CubsStringSlice fullyQualifiedName);

/// Returns NULL if cannot find
CubsTypeContext* cubs_program_find_mut_script_type_context(CubsProgram* self, CubsStringSlice fullyQualifiedName);

void cubs_program_context_insert(CubsProgram* self, ProgramTypeContext context);
