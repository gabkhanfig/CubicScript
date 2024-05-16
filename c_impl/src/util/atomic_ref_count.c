#include "atomic_ref_count.h"
//#include <stdatomic.h> why the heck doesnt this work on MSVC

#define MEMORY_ORDER_SEQ_CST 5

void atomic_ref_count_init(AtomicRefCount* refCountToInit)
{
#if _MSC_VER
  __c11_atomic_init((volatile size_t*)&refCountToInit->count, 1);
#else
  __c11_atomic_init((_Atomic(size_t)*)& refCountToInit->count, 1);
#endif
}

void atomic_ref_count_add_ref(AtomicRefCount *self)
{
#if _MSC_VER
  __c11_atomic_fetch_add((volatile size_t*)& self->count, 1, MEMORY_ORDER_SEQ_CST);
#else
  __c11_atomic_fetch_add((_Atomic(size_t)*)&self->count, 1, MEMORY_ORDER_SEQ_CST);
#endif
}

bool atomic_ref_count_remove_ref(AtomicRefCount *self)
{
#if _MSC_VER
  return __c11_atomic_fetch_sub((volatile size_t*) & self->count, 1, MEMORY_ORDER_SEQ_CST);
#else
  return __c11_atomic_fetch_sub((_Atomic(size_t)*)&self->count, 1, MEMORY_ORDER_SEQ_CST);
#endif
}
