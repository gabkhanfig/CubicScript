extern void* _cubs_os_aligned_malloc(size_t len, size_t align);
extern void* _cubs_os_aligned_free(void *buf, size_t len, size_t align);

#include "global_allocator.h"
#include <assert.h>

void *cubs_malloc(size_t len, size_t align) {
    void* mem = _cubs_os_aligned_malloc(len, (size_t)align);
    assert(mem != NULL && "CubicScript failed to allocate memory");
    return mem;
}

void cubs_free(void *buf, size_t len, size_t align) {
    _cubs_os_aligned_free(buf, len, align);
}