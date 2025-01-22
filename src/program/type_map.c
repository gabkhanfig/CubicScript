#include "type_map.h"
#include "string_slice_pointer_map.h"
#include "program_type_context.h"

const CubsTypeContext *cubs_type_map_find(const TypeMap *self, CubsStringSlice fullyQualifiedName)
{
    const _GenericStringSlicePointerMap* asGeneric = (const _GenericStringSlicePointerMap*)self;
    const ProgramTypeContext* ctx = 
        (const ProgramTypeContext*)generic_string_pointer_map_find(asGeneric, fullyQualifiedName);
    // This if should get optimized away.
    // Technically same memory region but for the sake of expressiveness.
    if(ctx->isScriptContext) {
        return ctx->context.scriptContext;
    } else {
        return ctx->context.userContext;
    }
}

CubsTypeContext *cubs_type_map_find_mut(TypeMap *self, CubsStringSlice fullyQualifiedName)
{
    const _GenericStringSlicePointerMap* asGeneric = (const _GenericStringSlicePointerMap*)self;
    ProgramTypeContext* ctx = 
        (ProgramTypeContext*)generic_string_pointer_map_find_mut(asGeneric, fullyQualifiedName);
    assert(ctx->isScriptContext && "Cannot mutate user defined type contexts");
    return ctx->context.scriptContext;
}

void cubs_type_map_insert(TypeMap *self, ProtectedArena *arena, ProgramTypeContext *context)
{
    _GenericStringSlicePointerMap* asGeneric = (_GenericStringSlicePointerMap*)self;
    CubsStringSlice fullyQualifiedName;
    // This if should get optimized away.
    // Technically same memory region but for the sake of expressiveness.
    if(context->isScriptContext) {
        fullyQualifiedName.str = context->context.scriptContext->name;
        fullyQualifiedName.len = context->context.scriptContext->nameLength;
    } else {
        fullyQualifiedName.str = context->context.userContext->name;
        fullyQualifiedName.len = context->context.userContext->nameLength;
    }
    assert(fullyQualifiedName.str != NULL && "Cannot use empty string for program type names");
    assert(fullyQualifiedName.len > 0 && "Cannot use empty string for program type names");

    generic_string_pointer_map_insert(asGeneric, arena, fullyQualifiedName, (void*)context);
}
