#include "atomic_ref_count.h"
#include "atomic.h"

void atomic_ref_count_init(AtomicRefCount* refCountToInit)
{
    cubs_atomic_init_64(&refCountToInit->count, 1);
}

void atomic_ref_count_add_ref(AtomicRefCount *self)
{
    (void)cubs_atomic_fetch_add_64(&self->count, 1);
}

bool atomic_ref_count_remove_ref(AtomicRefCount *self)
{
    return cubs_atomic_fetch_sub_64(&self->count, 1) == 1;
}
