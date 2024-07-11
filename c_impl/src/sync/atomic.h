#pragma once

#include <stdbool.h>
#include <stddef.h>

typedef struct AtomicRefCount {
  /// Care must be taken to avoid data races when interacting with this field directly.
  size_t count;
} AtomicRefCount;

/// Initializes to a ref count of 1.
void atomic_ref_count_init(AtomicRefCount* refCountToInit);

void atomic_ref_count_add_ref(AtomicRefCount* self);

/// Returns true if the ref count is 0, and there are no more references.
bool atomic_ref_count_remove_ref(AtomicRefCount* self);

typedef struct AtomicFlag {
    bool flag;
} AtomicFlag;

bool cubs_atomic_flag_load(const AtomicFlag* flag);

void cubs_atomic_flag_store(AtomicFlag* flag, bool value);

//! For some reason, <stdatomic.h> isn't working for MSVC????

#if _MSC_VER
#include <vcruntime_c11_atomic_support.h>
#include <stdbool.h>

#define cubs_atomic_init_64(ptr, val) \
do { \
    volatile size_t* _p = (volatile size_t*)ptr; \
    (*_p) = val; \
} while(false)

#define cubs_atomic_fetch_add_64(ptr, amount) _Atomic_add_fetch64((volatile size_t*)ptr, amount, _Atomic_memory_order_seq_cst)

#define cubs_atomic_fetch_sub_64(ptr, amount) _Atomic_sub_fetch64((volatile size_t*)ptr, amount, _Atomic_memory_order_seq_cst)

#define cubs_atomic_load_64(ptr) _Atomic_load64((const volatile long long*)ptr, _Atomic_memory_order_seq_cst)

#define cubs_atomic_store_64(ptr, val) _Atomic_store64((volatile long long*)ptr, (long long)val, _Atomic_memory_order_seq_cst)

#define cubs_atomic_load_bool(ptr) _Atomic_load8((const volatile char*)(ptr), _Atomic_memory_order_seq_cst)

#define cubs_atomic_store_bool(ptr, val) _Atomic_store8((volatile char*)(ptr), (char)val, _Atomic_memory_order_seq_cst)

#elif __GNUC__

#include <stdatomic.h>

#define cubs_atomic_init_64(ptr, val) atomic_init((atomic_size_t*)ptr, val)

#define cubs_atomic_fetch_add_64(ptr, amount) atomic_fetch_add((atomic_size_t*)ptr, amount)

#define cubs_atomic_fetch_sub_64(ptr, amount) atomic_fetch_sub((atomic_size_t*)ptr, amount)

#define cubs_atomic_load_64(ptr) atomic_load((const atomic_size_t*)ptr)

#define cubs_atomic_store_64(ptr, val) atomic_store((atomic_size_t*)ptr, val)

#define cubs_atomic_load_bool(ptr) atomic_load((const atomic_bool*)ptr)

#define cubs_atomic_store_bool(ptr, val) atomic_store((atomic_bool*)ptr, val)

#endif

