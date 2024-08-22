#include "function_definition.h"
#include <stddef.h>
#include "../primitives/context.h"
#include "../platform/mem.h"
#include "bytecode.h"
#include "../program/program.h"
#include <string.h>

void cubs_function_builder_deinit(FunctionBuilder *self)
{
    cubs_string_deinit(&self->fullyQualifiedName);
    cubs_string_deinit(&self->name);
    if(self->args.capacity > 0) {
        cubs_free(self->args.optTypes, self->args.capacity * sizeof(const CubsTypeContext*), _Alignof(const CubsTypeContext*));
    }
    if(self->bytecodeCapacity > 0) {
        cubs_free(self->bytecode, self->bytecodeCapacity * sizeof(Bytecode), _Alignof(Bytecode));
    }
    const FunctionBuilder zeroed = {0};
    *self = zeroed;
}

/// Potentially reallocates the dyanmic bytecode buffer.
/// Returns the start of a region where new bytecode can be copied to.
/// Does not increase the length. That is the callers responsbility.
static Bytecode* function_builder_add_n(FunctionBuilder *self, size_t bytecodeToAdd) {
    const size_t newLen = (self->bytecodeLen + bytecodeToAdd);
    if(self->bytecodeCapacity >= newLen) {
        return &self->bytecode[self->bytecodeLen];
    }

    size_t newCapacity;
    if(newLen > (self->bytecodeCapacity << 1)) {
        newCapacity = newLen;
    } else {
        newCapacity = self->bytecodeCapacity << 1;
    }
    Bytecode* newBuf = (Bytecode*)cubs_malloc((sizeof(Bytecode)) * newCapacity, _Alignof(Bytecode));
    if(self->bytecode != NULL) {
        memcpy((void*)newBuf, (const void*)self->bytecode, self->bytecodeLen * sizeof(Bytecode));
        cubs_free(self->bytecode, self->bytecodeCapacity * sizeof(Bytecode), _Alignof(Bytecode));
    }
    self->bytecode = newBuf;
    self->bytecodeCapacity = newCapacity;
    return &newBuf[self->bytecodeLen];
}

void cubs_function_builder_push_bytecode(FunctionBuilder *self, Bytecode bytecode)
{
    Bytecode* start = function_builder_add_n(self, 1);
    *start = bytecode;
    self->bytecodeLen += 1;
}

void cubs_function_builder_push_bytecode_many(FunctionBuilder* self, const Bytecode *bytecode, size_t count)
{
    Bytecode* start = function_builder_add_n(self, count);
    memcpy((void*)start, (const void*)bytecode, count * sizeof(Bytecode));
    self->bytecodeLen += count;
}

const Bytecode *cubs_function_bytecode_start(const ScriptFunctionDefinitionHeader *header)
{
    return (const Bytecode*)&header[1];
}
