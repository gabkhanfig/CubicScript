#include "cannot_find_symbol.h"
#include "../../platform/mem.h"
#include <assert.h>

static void cannot_find_symbol_deinit(CannotFindSymbol* self) {
    FREE_TYPE(CannotFindSymbol, self);
}

static CompileErrorVTable cannot_find_symbol_vtable = {
    .errType = compileErrorTypeCannotFindSymbol,
    .deinit = (CompileErrorDeinit)&cannot_find_symbol_deinit,
};

CompileError cannot_find_symbol_init(const TokenIter *iter, CubsStringSlice missingSymbol)
{
    CannotFindSymbol* self = MALLOC_TYPE(CannotFindSymbol);
    *self = (CannotFindSymbol){.missingSymbol = missingSymbol};

    CubsString message = cubs_string_init_unchecked((CubsStringSlice){.str = "Couldn't find symbol '", .len = 22});
    CubsString temp = cubs_string_concat_slice_unchecked(&message, missingSymbol);
    cubs_string_deinit(&message);
    message = cubs_string_concat_slice_unchecked(&temp, (CubsStringSlice){.str = "'.", .len = 2});
    cubs_string_deinit(&temp);

    const CubsCompileErrorLocation location = {.fileName = iter->name, .position = iter->position};

    return (CompileError){
        .vtable = &cannot_find_symbol_vtable,
        .ptr = (void*)self,
        .location = location,
        .message = message
    };
}