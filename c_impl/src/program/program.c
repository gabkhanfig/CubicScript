#include "program.h"
#include "../sync/locks.h"
#include <stdio.h>
#include "../platform/mem.h"
#include <string.h>
#include "../util/panic.h"
#include "protected_arena.h"
#include "../interpreter/function_definition.h"
#include "../interpreter/bytecode.h"
#include "protected_arena.h"
#include "function_map.h"

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
    ProtectedArena arena;
    CubsProgramContext context;
    CubsMutex contextMutex;
    FunctionMap functionMap;
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

    ProtectedArena arena = cubs_protected_arena_init();
    Inner* inner = (Inner*)cubs_protected_arena_malloc(&arena, INNER_ALLOC_SIZE, INNER_ALLOC_ALIGN);

    const Inner innerData = {
        .arena = arena, 
        .context = context, 
        .contextMutex = CUBS_MUTEX_INITIALIZER,
        .functionMap = FUNCTION_MAP_INITIALIZER,
    };
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

    ProtectedArena arena = inner->arena;
    cubs_protected_arena_free(&arena, (void*)inner);
    cubs_protected_arena_deinit(&arena);
}

bool cubs_program_find_function(const CubsProgram *self, CubsFunction *outFunc, CubsStringSlice fullyQualifiedName)
{
    const Inner* inner = as_inner(self);
    const ScriptFunctionDefinitionHeader* header = cubs_function_map_find(&inner->functionMap, fullyQualifiedName);
    if(header == NULL) {
        return false;
    }
    CubsFunction func = {.func = {.script = (const void*)header }, .funcType = cubsFunctionPtrTypeScript};
    *outFunc = func;
    return true;
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

ScriptFunctionDefinitionHeader* cubs_function_builder_build(FunctionBuilder* self, CubsProgram* program) {
    _Static_assert(_Alignof(ScriptFunctionDefinitionHeader) == _Alignof(Bytecode), "Alignment of function definition header must equal the bytecode alignment");
    
    assert(self->bytecode != NULL);
    assert(self->bytecodeLen > 0);

    Inner* inner = as_inner_mut(program);

    ScriptFunctionArgTypesSlice newArgs = {0};
    if(self->args.len > 0) {
        newArgs.len = self->args.len;
        newArgs.capacity = newArgs.len;
        newArgs.optTypes = cubs_protected_arena_malloc(
            &inner->arena, 
            sizeof(const CubsTypeContext*) * newArgs.len, 
            _Alignof(const CubsTypeContext*)
        );
        memcpy((void*)newArgs.optTypes, (const void*)self->args.optTypes, sizeof(const CubsTypeContext*) * self->args.len);
    }

    const ScriptFunctionDefinitionHeader headerData = {
        .program = program,
        .fullyQualifiedName = self->fullyQualifiedName,
        .name = self->name,
        .stackSpaceRequired = self->stackSpaceRequired,
        .optReturnType = self->optReturnType,
        .args = newArgs,
        .bytecodeCount = self->bytecodeLen,
    };
    ScriptFunctionDefinitionHeader* header = cubs_protected_arena_malloc(
        &inner->arena, 
        sizeof(ScriptFunctionDefinitionHeader) + (sizeof(Bytecode) * self->bytecodeLen), 
        _Alignof(Bytecode)
    );
    *header = headerData;
    memcpy((void*)cubs_function_bytecode_start(header), (const void*)self->bytecode, self->bytecodeLen * sizeof(Bytecode));

    { // deinitialize function builder
        // Explicitly DO NOT deinitialize the names, as their ownership is transferred above with `headerData`
        cubs_free(self->bytecode, self->bytecodeCapacity * sizeof(Bytecode), _Alignof(Bytecode));
        if(self->args.optTypes != NULL) {         
            cubs_free(self->args.optTypes, sizeof(const CubsTypeContext*) * self->args.capacity, _Alignof(const CubsTypeContext*));
        }
        const FunctionBuilder zeroed = {0};
        *self = zeroed;
    }

    cubs_function_map_insert(&inner->functionMap, &inner->arena, header);
    return header;
}


