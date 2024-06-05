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