#pragma once

#include <stddef.h>

/// Will always return a valid pointer.
/// When compiled with c/c++, using OS specific allocation. See `global_allocator.c`.
/// When compiled with zig, uses zig allocators. See `global_allocator.zig`.
extern void* cubs_malloc(size_t len, size_t align);

/// When compiled with c/c++, using OS specific deallocation. See `global_allocator.c`.
/// When compiled with zig, uses zig allocators. See `global_allocator.zig`.
extern void cubs_free(void *buf, size_t len, size_t align);