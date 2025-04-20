#include "compile_error.h"
#include <assert.h>

void cubs_compile_error_deinit(CompileError *self)
{
    cubs_string_deinit(&self->message);
    assert(self->vtable->deinit != NULL);
    self->vtable->deinit(self->ptr);
}
