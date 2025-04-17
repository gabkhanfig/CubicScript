#include "compile_error.h"
#include <assert.h>

void cubs_compile_error_deinit(CompileError *self)
{
    assert(self->vtable->deinit != NULL);
    self->vtable->deinit(self->ptr);
}

CubsCompileErrorLocation cubs_compile_error_where(const CompileError *self)
{
    assert(self->vtable->where != NULL);
    return self->vtable->where(self->ptr);
}

CubsStringSlice cubs_compile_error_what(const CompileError *self)
{
    assert(self->vtable->what != NULL);
    return self->vtable->what(self->ptr);
}
