#ifndef BYTECODE_ARRAY_H
#define BYTECODE_ARRAY_H

#include <stddef.h>

struct Bytecode;

typedef struct BytecodeArray {
    struct Bytecode* bytecode;
    size_t len;
    size_t capacity;
} BytecodeArray;

void cubs_bytecode_array_deinit(BytecodeArray* self);

struct Bytecode* cubs_bytecode_array_add_n(BytecodeArray* self, size_t bytecodeToAdd);

#endif