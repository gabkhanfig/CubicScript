#include "atomic_ref_count.h"
//why the fwick doesnt this work on MSVC
//#include<stdatomic.h>
#if _MSC_VER
#include <vcruntime_c11_atomic_support.h>
#else
#include <stdatomic.h>
#endif

#define MEMORY_ORDER_SEQ_CST 5

void atomic_ref_count_init(AtomicRefCount* refCountToInit)
{
#if _MSC_VER
    volatile size_t* count = (volatile size_t*)&refCountToInit->count;
    (*count) = 1;
#else
    atomic_init((atomic_size_t*)&refCountToInit->count, 1);
#endif
}

void atomic_ref_count_add_ref(AtomicRefCount *self)
{
#if _MSC_VER
    _Atomic_add_fetch64((volatile size_t*)&self->count, 1, MEMORY_ORDER_SEQ_CST);
#else
    (void)atomic_fetch_add((atomic_size_t*)&self->count, 1);
#endif
}

bool atomic_ref_count_remove_ref(AtomicRefCount *self)
{
#if _MSC_VER
    return _Atomic_sub_fetch64((volatile size_t*)&self->count, 1, MEMORY_ORDER_SEQ_CST) == 1;
#else
    return atomic_fetch_sub((atomic_size_t*)&self->count, 1) == 1;
#endif
}
