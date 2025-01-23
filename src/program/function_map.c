#include "function_map.h"
#include "string_slice_pointer_map.h"
#include "../interpreter/function_definition.h"
#include "../primitives/string/string.h"

const CubsScriptFunctionPtr* cubs_function_map_find(
    const FunctionMap* self, CubsStringSlice fullyQualifiedName
) {
    const _GenericStringSlicePointerMap* asGeneric = (const _GenericStringSlicePointerMap*)self;
    return (const CubsScriptFunctionPtr*)generic_string_pointer_map_find(asGeneric, fullyQualifiedName);
}

void cubs_function_map_insert(FunctionMap *self, ProtectedArena* arena, CubsScriptFunctionPtr* function) {
    _GenericStringSlicePointerMap* asGeneric = (_GenericStringSlicePointerMap*)self;
    const CubsStringSlice fullyQualifiedName = cubs_string_as_slice(&function->fullyQualifiedName);

    generic_string_pointer_map_insert(asGeneric, arena, fullyQualifiedName, (void*)function);
}
