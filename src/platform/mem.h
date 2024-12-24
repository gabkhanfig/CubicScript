#pragma once

#include <stddef.h>

/// Will always return a valid pointer.
/// When compiled with c/c++, using OS specific allocation. See `global_allocator.c`.
/// When compiled with zig, uses zig allocators. See `mem.zig`.
extern void* cubs_malloc(size_t len, size_t align);

/// When compiled with c/c++, using OS specific deallocation. See `global_allocator.c`.
/// When compiled with zig, uses zig allocators. See `mem.zig`.
extern void cubs_free(void *buf, size_t len, size_t align);

/// Does not implement any runtime memory tracking in debug mode. Simply requests a buffer of heap memory.
extern void* _cubs_raw_aligned_malloc(size_t len, size_t align);

/// Does not implement any runtime memory tracking in debug mode. Simply frees a buffer of heap memory.
extern void _cubs_raw_aligned_free(void *buf, size_t len, size_t align);

extern void* _cubs_os_malloc_pages(size_t len);

extern void _cubs_os_free_pages(void* pagesStart, size_t len);

#define MALLOC_TYPE(T) ((T*)cubs_malloc(sizeof(T), _Alignof(T)))

#define FREE_TYPE(T, ptr) (cubs_free((void*)ptr, sizeof(T), _Alignof(T)))

#define MALLOC_TYPE_ARRAY(T, count) ((T*)cubs_malloc(sizeof(T) * count, _Alignof(T)))

#define FREE_TYPE_ARRAY(T, ptr, count) (cubs_free((void*)ptr, sizeof(T) * count, _Alignof(T)))
