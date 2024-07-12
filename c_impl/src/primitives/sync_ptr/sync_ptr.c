#include "sync_ptr.h"
#include "../../sync/locks.h"
#include "../../sync/atomic.h"
#include <assert.h>
#include "../../util/mem.h"
#include <string.h>
#include "../../util/hash.h"

#define ALIGNMENT 64

/// If it's for a shared ptr, the ref count is stored in the 8 bytes before the ref header in memory
typedef struct {
    CubsRwLock lock;
    AtomicRefCount weakCount;
    AtomicFlag isExpired;
    bool isShared; // If its shared, then the ref count is also part of the allocation
} RefHeader;

/// Always returns a multiple of 64. This guarantees no false sharing.
static size_t header_and_data_alloc_size(bool isShared, size_t sizeOfType) {
    size_t sum;
    if(isShared) {
        sum = sizeof(AtomicRefCount) + sizeof(RefHeader) + sizeOfType;
    } else {
        sum = sizeof(RefHeader) + sizeOfType;
    }
    const size_t requiredAllocation = sum + (ALIGNMENT - (sum % ALIGNMENT));
    assert((requiredAllocation % ALIGNMENT) == 0);
    return requiredAllocation;
}

/// If shared, sets the shared ref count to 1.
static RefHeader* header_init(bool isShared, size_t sizeOfType) { 
    const size_t allocSize = header_and_data_alloc_size(false, sizeOfType);
    AtomicRefCount* mem = (AtomicRefCount*)cubs_malloc(allocSize, ALIGNMENT);
    atomic_ref_count_init(mem);

    RefHeader* header = (RefHeader*)&mem[1];
    RefHeader headerData;
    cubs_rwlock_init(&headerData.lock);
    headerData.weakCount.count = 0;
    headerData.isExpired.flag = false;
    headerData.isShared = false;
    *header = headerData;
    return header;
}

// static void header_deinit(RefHeader* header, const CubsTypeContext* context) {
//     #if _DEBUG
//     if(header->isShared) {
//         const size_t currentRefCount = cubs_atomic_load_64(header_shared_ref_count(header));
//         assert(currentRefCount == 0);
//     }
//     #endif
//     if(context->destructor) {
//         context->destructor(header_value_mut(header));
//     }
//     header_free(header, context->sizeOfType);
// }

static const void* header_value(const RefHeader* header) {
    return (const void*)(&header[1]);
}

static void* header_value_mut(RefHeader* header) {
    return (void*)(&header[1]);
}

static const AtomicRefCount* header_shared_ref_count(const RefHeader* header) {
    assert(header->isShared);
    return (const AtomicRefCount*)header - 1;
}

static AtomicRefCount* header_shared_ref_count_mut(RefHeader* header) {
    assert(header->isShared);
    return (AtomicRefCount*)header - 1;
}

/// Free without deinitizling the value
static void header_free(RefHeader* header, size_t sizeOfType) {
    const size_t allocSize = header_and_data_alloc_size(header->isShared, sizeOfType);
    if(header->isShared) {
        void* memStart = (void*)header_shared_ref_count_mut(header);
        cubs_free(memStart, allocSize, ALIGNMENT);
    } else {
        cubs_free((void*)header, allocSize, ALIGNMENT);
    }
}

CubsUnique cubs_unique_init_user_class(void *value, const CubsTypeContext *context)
{
    assert(context != NULL);
    assert(value != NULL);

    RefHeader* header = header_init(false, context->sizeOfType);
    memcpy(header_value_mut(header), value, context->sizeOfType);
    const CubsUnique unique = {._inner = (void*)header, .context = context};
    return unique;
}

void cubs_unique_deinit(CubsUnique *self)
{
    if(self->_inner == NULL) {
        return;
    }

    RefHeader* header = (RefHeader*)self->_inner;
    self->_inner = NULL;

    cubs_rwlock_lock_exclusive(&header->lock);

    if(self->context->destructor != NULL) {
        self->context->destructor(header_value_mut(header));
    }   
    cubs_atomic_flag_store(&header->isExpired, true);
    const bool shouldFree = cubs_atomic_load_64(&header->weakCount.count) == 0;

    cubs_rwlock_unlock_exclusive(&header->lock);

    if(shouldFree) { // there are no weak references
        header_free(header, self->context->sizeOfType);
    }
}

void cubs_unique_lock_shared(const CubsUnique* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    cubs_rwlock_lock_shared(&header->lock);
}

bool cubs_unique_try_lock_shared(const CubsUnique* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    return cubs_rwlock_try_lock_shared(&header->lock);
}

void cubs_unique_unlock_shared(const CubsUnique* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    cubs_rwlock_unlock_shared(&header->lock);
}

void cubs_unique_lock_exclusive(CubsUnique* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    cubs_rwlock_lock_exclusive(&header->lock);
}

bool cubs_unique_try_lock_exclusive(CubsUnique* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    return cubs_rwlock_try_lock_exclusive(&header->lock);
}

void cubs_unique_unlock_exclusive(CubsUnique* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    cubs_rwlock_unlock_exclusive(&header->lock);
}

const void *cubs_unique_get(const CubsUnique *self)
{
    const RefHeader* header = (const RefHeader*)self->_inner;
    return header_value(header);
}

void *cubs_unique_get_mut(CubsUnique *self)
{
    RefHeader* header = (RefHeader*)self->_inner;
    return header_value_mut(header);
}

CubsUnique cubs_unique_clone(const CubsUnique *self)
{
    assert(self->context->clone != NULL);

    RefHeader* header = header_init(false, self->context->sizeOfType);
    self->context->clone(header_value_mut(header), cubs_unique_get(self));
    const CubsUnique unique = {._inner = (void*)header, .context = self->context};
    return unique;
}

// // TODO equality and hashing without locking are unsafe for the set/map. figure out how to do this or if it shouldnt be allowed as keys

// bool cubs_unique_eql(const CubsUnique *self, const CubsUnique *other)
// {
//     return cubs_unique_eql_value(self, cubs_unique_get(other));
// }

// bool cubs_unique_eql_value(const CubsUnique *self, const void *other)
// {
//     assert(self->context->eql != NULL);
//     return self->context->eql(cubs_unique_get(self), other);
// }

// size_t cubs_unique_hash(const CubsUnique *self)
// {
//     assert(self->context->hash != NULL);

//     const size_t globalHashSeed = cubs_hash_seed();
//     size_t h = globalHashSeed;
//     return cubs_combine_hash(h, self->context->hash(self));
// }

// void cubs_unique_take(void *out, CubsUnique *self)
// {
//     assert(out != NULL);

//     RefHeader* header = (RefHeader*)self->_inner;
//     self->_inner = NULL;

//     cubs_rwlock_lock_exclusive(&header->lock);

//     memcpy(out, header_value(header), self->context->sizeOfType);

//     cubs_atomic_flag_store(&header->isExpired, true);
//     const bool shouldFree = cubs_atomic_load_64(&header->weakCount.count) == 0;

//     cubs_rwlock_unlock_exclusive(&header->lock);

//     if(shouldFree) { // there are no weak references
//         header_free(header, self->context->sizeOfType);
//     }
// }
