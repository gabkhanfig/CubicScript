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
