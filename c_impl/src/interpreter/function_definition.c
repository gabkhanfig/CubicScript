#include "function_definition.h"
#include <stddef.h>
#include "../primitives/context.h"
#include "../platform/mem.h"
#include "bytecode.h"
#include "../program/program.h"

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

const Bytecode *cubs_function_bytecode_start(const ScriptFunctionDefinitionHeader *header)
{
    return (const Bytecode*)&header[1];
}
