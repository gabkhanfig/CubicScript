#include "protected_arena.h"
#include "../platform/mem.h"
#include <string.h>
#include "../util/panic.h"
#include <stdio.h>
#include <assert.h>

typedef struct {
    void* mem;
    size_t len;
    size_t align;
} Allocation;

ProtectedArena cubs_protected_arena_init()
{
    const ProtectedArena arena = {0};
    return arena;
}

void *cubs_protected_arena_malloc(ProtectedArena *self, size_t len, size_t align)
{
    void* mem = cubs_malloc(len, align);
    Allocation allocation = {.mem = mem, .len = len, .align = align};
    if(self->len == self->capacity) {
        const size_t DEFAULT_CAPACITY = 256;
        const size_t newCapacity = self->capacity == 0 ? DEFAULT_CAPACITY : self->capacity << 1;
        Allocation* newArray = (Allocation*)cubs_malloc(newCapacity * sizeof(Allocation), _Alignof(Allocation));
        if(self->allAllocations != NULL) {
            memcpy((void*)newArray, self->allAllocations, self->len * sizeof(Allocation));
            cubs_free(self->allAllocations, self->capacity * sizeof(Allocation), _Alignof(Allocation));
        }
        self->allAllocations = (void*)newArray;
        self->capacity = newCapacity; 
    }
    ((Allocation*)(self->allAllocations))[self->len] = allocation;
    self->len += 1;
    return mem;
}

static void protected_arena_invalid_mem_panic(ProtectedArena *self, void *mem) {
    char errBuf[256];
    #if defined(_WIN32) || defined(WIN32)
    const int len = sprintf_s(errBuf, 256, "Allocation at [%p] not allocated by this[%p] arena\n", mem, self);
    #else
    const int len = sprintf(errBuf, "Allocation at [%p] not allocated by this[%p] arena\n", mem, self);
    #endif
    assert(len >= 0);
    cubs_panic(errBuf);
}

void cubs_protected_arena_free(ProtectedArena *self, void *mem)
{
    Allocation* allocations = (Allocation*)self->allAllocations;
    assert(mem != NULL);
    if(allocations == NULL) {
        protected_arena_invalid_mem_panic(self, mem);
    } else {
        for(size_t i = 0; i < self->len; i++) {
            Allocation allocation = allocations[i];
            if(allocation.mem == mem) {
                cubs_free(allocation.mem, allocation.len, allocation.align);
                allocations[i].mem = NULL;
                return;
            }
        }
        protected_arena_invalid_mem_panic(self, mem);
    }
}

void cubs_protected_arena_deinit(ProtectedArena *self)
{
    Allocation* allocations = (Allocation*)self->allAllocations;
    if(allocations == NULL) {
        return;
    }
    for(size_t i = 0; i < self->len; i++) {
        Allocation allocation = allocations[i];
        if(allocation.mem != NULL) {
            cubs_free(allocation.mem, allocation.len, allocation.align);
        }     
    }
    cubs_free(self->allAllocations, self->capacity * sizeof(Allocation), _Alignof(Allocation));
    self->allAllocations = NULL;
}
