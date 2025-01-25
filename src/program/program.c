#include "program.h"
#include "program_internal.h"
#include <stdio.h>
#include "../platform/mem.h"
#include <string.h>
#include "../util/panic.h"
#include "protected_arena.h"
#include "../interpreter/function_definition.h"
#include "../interpreter/bytecode.h"

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

static const CubsProgramContextVTable DEFAULT_CONTEXT_V_TABLE = {.errorCallback = default_context_error_callback, .print = defaut_context_print, .deinit = default_context_deinit};
static const CubsProgramContext DEFAULT_PROGRAM_CONTEXT = {.ptr = NULL, .vtable = &DEFAULT_CONTEXT_V_TABLE};

#pragma endregion

/// Ceil to multiple of 64
static const size_t INNER_ALLOC_SIZE = sizeof(ProgramInner) + (64 - (sizeof(ProgramInner) % 64));
/// 64 byte cache line alignment
static const size_t INNER_ALLOC_ALIGN = 64;

static const ProgramInner* as_inner(const CubsProgram* self) {
    return (const ProgramInner*)self->_inner;
}

static ProgramInner* as_inner_mut(CubsProgram* self) {
    return (ProgramInner*)self->_inner;
}

CubsProgram cubs_program_compile(CubsProgramInitParams params, const CubsBuildOptions* build)
{
    CubsProgram self = cubs_program_init(params);
    return self;
}

CubsProgram cubs_program_init(CubsProgramInitParams params)
{
    CubsProgramContext context;
    if(params.context != NULL) {
        context = *params.context;
        params.context->ptr = NULL;
    } else {
        context = DEFAULT_PROGRAM_CONTEXT;
    }

    ProtectedArena arena = cubs_protected_arena_init();
    ProgramInner* inner = (ProgramInner*)cubs_protected_arena_malloc(&arena, INNER_ALLOC_SIZE, INNER_ALLOC_ALIGN);

    const ProgramInner innerData = {
        .arena = arena, 
        .context = context, 
        .contextMutex = CUBS_MUTEX_INITIALIZER,
        .functionMap = (FunctionMap){0},
        .typeMap = (TypeMap){0},
    };
    *inner = innerData;

    const CubsProgram program = {._inner = (void*)inner};
    return program;
}

void cubs_program_deinit(CubsProgram *self)
{
    ProgramInner* inner = as_inner_mut(self);
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
    const ProgramInner* inner = as_inner(self);
    const CubsScriptFunctionPtr* header = cubs_function_map_find(&inner->functionMap, fullyQualifiedName);
    if(header == NULL) {
        return false;
    }
    CubsFunction func = {.func = {.script = (const void*)header }, .funcType = cubsFunctionPtrTypeScript};
    *outFunc = func;
    return true;
}

/// Not defined in `program.h`. Reserved for internal use only.
void _cubs_internal_program_runtime_error(const CubsProgram* self, CubsProgramRuntimeError err, const char* message, size_t messageLength) {
    const ProgramInner* inner = as_inner(self);

    // Explicitly cast away const
    CubsMutex* contextMutex = (CubsMutex*)&inner->contextMutex;
    CubsProgramContext context = inner->context;

    cubs_mutex_lock(contextMutex);
    context.vtable->errorCallback(context.ptr, self, NULL, err, message, messageLength);
    cubs_mutex_unlock(contextMutex);
}

CubsTypeContext *cubs_program_malloc_script_context(CubsProgram *self)
{
    ProgramInner* inner = as_inner_mut(self);
    CubsTypeContext* mem = (CubsTypeContext*)cubs_protected_arena_malloc(
        &inner->arena, sizeof(CubsTypeContext), _Alignof(CubsTypeContext));
    return mem;
}

CubsStringSlice cubs_program_malloc_copy_string_slice(CubsProgram *self, CubsStringSlice source)
{
    ProgramInner* inner = as_inner_mut(self);
    // Add one for null terminator
    // Technically unnecessary but convenient
    char* mem = (char*)cubs_protected_arena_malloc(
        &inner->arena, sizeof(char) * source.len + 1, _Alignof(char)); 
    memcpy(mem, source.str, source.len);
    mem[source.len] = '\0';
    const CubsStringSlice slice = {.str = mem, .len = source.len};
    return slice;
}

CubsTypeMemberContext *cubs_program_malloc_member_context_array(CubsProgram *self, size_t count)
{
    ProgramInner* inner = as_inner_mut(self);
    CubsTypeMemberContext* mem = (CubsTypeMemberContext*)cubs_protected_arena_malloc(
        &inner->arena, sizeof(CubsTypeMemberContext) * count, _Alignof(CubsTypeMemberContext));
    return mem;
}

const CubsTypeContext *cubs_program_find_type_context(const CubsProgram *self, CubsStringSlice fullyQualifiedName)
{
    const ProgramInner* inner = as_inner(self);
    return cubs_type_map_find(&inner->typeMap, fullyQualifiedName);
}

CubsTypeContext *cubs_program_find_mut_script_type_context(CubsProgram *self, CubsStringSlice fullyQualifiedName)
{
    ProgramInner* inner = as_inner_mut(self);
    return cubs_type_map_find_mut(&inner->typeMap, fullyQualifiedName);
}

void cubs_program_context_insert(CubsProgram *self, ProgramTypeContext context)
{    
    ProgramInner* inner = as_inner_mut(self);
    ProgramTypeContext* contextMem = cubs_protected_arena_malloc(
        &inner->arena, sizeof(ProgramTypeContext), _Alignof(ProgramTypeContext));
    *contextMem = context;
    cubs_type_map_insert(&inner->typeMap, &inner->arena, contextMem);
}

/// Not defined in `program.h`. Reserved for internal use only.
void _cubs_internal_program_print(const CubsProgram* self, const char* message, size_t messageLength) {
    const ProgramInner* inner = as_inner(self);

    // Explicitly cast away const
    CubsMutex* contextMutex = (CubsMutex*)&inner->contextMutex;
    CubsProgramContext context = inner->context;

    cubs_mutex_lock(contextMutex);
    context.vtable->print(context.ptr, self, message, messageLength);
    cubs_mutex_unlock(contextMutex);
}

CubsScriptFunctionPtr* cubs_function_builder_build(FunctionBuilder* self, CubsProgram* program) {
    _Static_assert(_Alignof(CubsScriptFunctionPtr) == _Alignof(Bytecode), "Alignment of function definition header must equal the bytecode alignment");
    
    assert(self->bytecode != NULL);
    assert(self->bytecodeLen > 0);

    ProgramInner* inner = as_inner_mut(program);

    const CubsTypeContext** newArgsTypes = NULL;
    size_t newArgsLen = 0;
    if(self->args.len > 0) {
        newArgsLen = self->args.len;
        newArgsTypes = cubs_protected_arena_malloc(
            &inner->arena, 
            sizeof(const CubsTypeContext*) * newArgsLen, 
            _Alignof(const CubsTypeContext*)
        );
        memcpy((void*)newArgsTypes, (const void*)self->args.optTypes, sizeof(const CubsTypeContext*) * self->args.len);
    }

    const CubsScriptFunctionPtr headerData = {
        .program = program,
        .fullyQualifiedName = self->fullyQualifiedName,
        .name = self->name,
        .returnType = self->optReturnType,
        .argsTypes = newArgsTypes,
        .argsLen = newArgsLen,
        ._stackSpaceRequired = self->stackSpaceRequired,
        ._bytecodeCount = self->bytecodeLen,
    };
    CubsScriptFunctionPtr* header = cubs_protected_arena_malloc(
        &inner->arena, 
        sizeof(CubsScriptFunctionPtr) + (sizeof(Bytecode) * self->bytecodeLen), 
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


