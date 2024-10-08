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

bool cubs_atomic_flag_load(const AtomicFlag* flag) {
    return cubs_atomic_load_bool(&flag->flag);
}

void cubs_atomic_flag_store(AtomicFlag* flag, bool value) {
    cubs_atomic_store_bool(&flag->flag, value);
}