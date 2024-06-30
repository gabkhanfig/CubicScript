#pragma once

//! For some reason, <stdatomic.h> isn't working for MSVC????

#if _MSC_VER
#include <vcruntime_c11_atomic_support.h>

#define cubs_atomic_init_64(ptr, val) \
do { \
    volatile size_t* _p = (volatile size_t*)ptr; \
    (*_p) = val; \
} while(false)

#define cubs_atomic_fetch_add_64(ptr, amount) _Atomic_add_fetch64((volatile size_t*)ptr, amount, _Atomic_memory_order_seq_cst)

#define cubs_atomic_fetch_sub_64(ptr, amount) _Atomic_sub_fetch64((volatile size_t*)ptr, amount, _Atomic_memory_order_seq_cst)

#define cubs_atomic_load_64(ptr) _Atomic_load64((const volatile long long*)ptr, _Atomic_memory_order_seq_cst)

#define cubs_atomic_store_64(ptr, val) _Atomic_store64((volatile long long*)ptr, (long long)val, _Atomic_memory_order_seq_cst)

#else
#include <stdatomic.h>

#define cubs_atomic_init_64(ptr, val) atomic_init((atomic_size_t*)ptr, val)

#define cubs_atomic_fetch_add_64(ptr, amount) atomic_fetch_add((atomic_size_t*)ptr, amount)

#define cubs_atomic_fetch_sub_64(ptr, amount) atomic_fetch_sub((atomic_size_t*)ptr, amount)

#define cubs_atomic_load_64(ptr) atomic_load((atomic_size_t*)ptr)

#define cubs_atomic_store_64(ptr, val) atomic_store((atomic_size_t*)ptr, val)

#endif

