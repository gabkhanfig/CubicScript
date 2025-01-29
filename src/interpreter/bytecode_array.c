#include "bytecode_array.h"
#include "bytecode.h"
#include "../platform/mem.h"
#include <assert.h>

void cubs_bytecode_array_deinit(BytecodeArray* self) {
    if(self->bytecode == NULL) return;

    FREE_TYPE_ARRAY(Bytecode, self->bytecode, self->capacity);
    self->bytecode = NULL;
    self->len = 0;
    self->capacity = 0;
}

Bytecode *cubs_bytecode_array_add_n(BytecodeArray *self, size_t bytecodeToAdd)
{
    const size_t newLen = (self->len + bytecodeToAdd);
    if(self->capacity >= newLen) {
        return &self->bytecode[self->len];
    }

    size_t newCapacity;
    if(newLen > (self->capacity << 1)) {
        newCapacity = newLen;
    } else {
        newCapacity = self->capacity << 1;
    }
    Bytecode* newBuf = MALLOC_TYPE_ARRAY(Bytecode, newCapacity);
    if(self->bytecode != NULL) {
        memcpy((void*)newBuf, (const void*)self->bytecode, self->len * sizeof(Bytecode));
        FREE_TYPE_ARRAY(Bytecode, self->bytecode, self->capacity);
        cubs_free(self->bytecode, self->capacity * sizeof(Bytecode), _Alignof(Bytecode));
    }
    self->bytecode = newBuf;
    self->capacity = newCapacity;
    return &newBuf[self->len];
}
