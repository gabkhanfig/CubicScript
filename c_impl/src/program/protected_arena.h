#pragma once

#include <stddef.h>

/*
The protected arena handles all script program specific allocations, 
such as the program itself, the bytecode for functions, and struct type contexts.
In the future, it will explicitly protect this memory at the OS level.
*/

// TODO actually mprotect / VirtualProtect

typedef struct {
    void* allAllocations;
    size_t len;
    size_t capacity;
} ProtectedArena;

ProtectedArena cubs_protected_arena_init();

void* cubs_protected_arena_malloc(ProtectedArena* self, size_t len, size_t align);

/// Freeing a specific value allocated by the arena does not need to be fast, 
/// as in most situations, nothing needs to be freed from the arena, rather freeing everything at once
/// in `cubs_protected_arena_deinit()` is better.
void cubs_protected_arena_free(ProtectedArena* self, void* mem);

/// Free's all previously allocated memory
void cubs_protected_arena_deinit(ProtectedArena *self);