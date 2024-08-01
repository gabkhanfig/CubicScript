#include "program.h"
#include "../sync/locks.h"
#include <stdio.h>
#include "../util/mem.h"
#include <string.h>
#include "../util/panic.h"

const char *cubs_program_runtime_error_as_string(CubsProgramRuntimeError err)
{
    switch(err) {
        default: return "";
    }
}

#pragma region Default_Context

static void default_context_error_callback(void* self, const CubsProgram* program, const void* stackTrace, CubsProgramRuntimeError err, const char* message, size_t messageLength) {
    fprintf(stderr, "[Cubic Script Error]: %s\n\t%s", cubs_program_runtime_error_as_string(err), message);
}

static void defaut_context_print(void* self, const CubsProgram* program, const char* message, size_t messageLength) {
    fprintf(stderr, "[Cubic Script]: %s", message);
}

static void default_context_deinit(void* self) {}

const CubsProgramContextVTable DEFAULT_CONTEXT_V_TABLE = {.errorCallback = default_context_error_callback, .print = defaut_context_print, .deinit = default_context_deinit};
const CubsProgramContext DEFAULT_CONTEXT = {.ptr = NULL, .vtable = &DEFAULT_CONTEXT_V_TABLE};

#pragma endregion

typedef struct {
    CubsProgramContext context;
    CubsMutex contextMutex;
} Inner;

/// Ceil to multiple of 64
const size_t INNER_ALLOC_SIZE = sizeof(Inner) + (64 - (sizeof(Inner) % 64));
/// 64 byte cache line alignment
const size_t INNER_ALLOC_ALIGN = 64;

static const Inner* as_inner(const CubsProgram* self) {
    return (const Inner*)self->_inner;
}

static Inner* as_inner_mut(CubsProgram* self) {
    return (Inner*)self->_inner;
}

CubsProgram cubs_program_init(CubsProgramInitParams params)
{
    CubsProgramContext context;
    if(params.context != NULL) {
        context = *params.context;
        params.context->ptr = NULL;
    } else {
        context = DEFAULT_CONTEXT;
    }

    const Inner innerData = {.context = context, .contextMutex = {0}};
    Inner* inner = cubs_malloc(INNER_ALLOC_SIZE, INNER_ALLOC_ALIGN);
    *inner = innerData;

    const CubsProgram program = {._inner = (void*)inner};
    return program;
}

void cubs_program_deinit(CubsProgram *self)
{
    Inner* inner = as_inner_mut(self);
    if(!cubs_mutex_try_lock(&inner->contextMutex)) {
        cubs_panic("Unsafe to deinitialize Cubic Script program while other threads are using it");
    }
    inner->context.vtable->deinit(inner->context.ptr);
    cubs_mutex_unlock(&inner->contextMutex);

    cubs_free((void*)inner, INNER_ALLOC_SIZE, INNER_ALLOC_ALIGN);
}

/// Not defined in `program.h`. Reserved for internal use only.
void _cubs_internal_program_runtime_error(const CubsProgram* self, CubsProgramRuntimeError err, const char* message, size_t messageLength) {
    const Inner* inner = as_inner(self);

    // Explicitly cast away const
    CubsMutex* contextMutex = (CubsMutex*)&inner->contextMutex;
    CubsProgramContext context = inner->context;

    cubs_mutex_lock(contextMutex);
    context.vtable->errorCallback(context.ptr, self, NULL, err, message, messageLength);
    cubs_mutex_unlock(contextMutex);
}

/// Not defined in `program.h`. Reserved for internal use only.
void _cubs_internal_program_print(const CubsProgram* self, const char* message, size_t messageLength) {
    const Inner* inner = as_inner(self);

    // Explicitly cast away const
    CubsMutex* contextMutex = (CubsMutex*)&inner->contextMutex;
    CubsProgramContext context = inner->context;

    cubs_mutex_lock(contextMutex);
    context.vtable->print(context.ptr, self, message, messageLength);
    cubs_mutex_unlock(contextMutex);
}
