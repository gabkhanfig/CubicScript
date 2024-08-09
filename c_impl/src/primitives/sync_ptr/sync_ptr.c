#include "sync_ptr.h"
#include "../../sync/locks.h"
#include "../../sync/atomic.h"
#include <assert.h>
#include "../../util/mem.h"
#include <string.h>
#include "../../util/hash.h"
#include "../primitives_context.h"

#define ALIGNMENT 64

/// If it's for a shared ptr, the ref count is stored in the 8 bytes before the ref header in memory
typedef struct {
    CubsRwLock lock;
    AtomicRefCount weakCount;
    AtomicFlag isExpired;
    bool isShared; // If its shared, then the ref count is also part of the allocation
} RefHeader;

/// Works with unique, shared, and weak ptrs.
CubsRwLock* _cubs_internal_sync_ptr_get_lock(void* syncPtr) {
    /// unique, shared, and weak all have the same memory layout, so this is ok to get the "first" element.
    uintptr_t* nestedPtr = (uintptr_t*)syncPtr;
    RefHeader* header = (RefHeader*)(*nestedPtr);
    return &header->lock;
}

/// Always returns a multiple of 64. This guarantees no false sharing.
static size_t header_and_data_alloc_size(bool isShared, size_t sizeOfType) {
    size_t sum;
    if(isShared) {
        sum = sizeof(AtomicRefCount) + sizeof(RefHeader) + sizeOfType;
    } else {
        sum = sizeof(RefHeader) + sizeOfType;
    }
    const size_t remainder = sum % ALIGNMENT;
    if(remainder == 0) {
        return sum;
    }
    const size_t requiredAllocation = sum + (ALIGNMENT - (sum % ALIGNMENT));
    assert((requiredAllocation % ALIGNMENT) == 0);
    return requiredAllocation;
}

/// If shared, sets the shared ref count to 1.
static RefHeader* header_init(bool isShared, size_t sizeOfType) { 
    const size_t allocSize = header_and_data_alloc_size(isShared, sizeOfType);
    void* mem = cubs_malloc(allocSize, ALIGNMENT);
    
    RefHeader* header = (RefHeader*)mem;
    if(isShared) {
        AtomicRefCount* refCount = (AtomicRefCount*)mem;
        atomic_ref_count_init(refCount);
        header = (RefHeader*)&refCount[1];
    }
    
    RefHeader headerData;
    headerData.weakCount.count = 0;
    headerData.isExpired.flag = false;
    headerData.isShared = isShared;
    *header = headerData;
    header->lock = CUBS_RWLOCK_INITIALIZER;
    return header;
}

static const void* header_value(const RefHeader* header) {
    return (const void*)(&header[1]);
}

static void* header_value_mut(RefHeader* header) {
    return (void*)(&header[1]);
}

static const AtomicRefCount* header_shared_ref_count(const RefHeader* header) {
    assert(header->isShared);
    return ((const AtomicRefCount*)header) - 1;
}

static AtomicRefCount* header_shared_ref_count_mut(RefHeader* header) {
    assert(header->isShared);
    return ((AtomicRefCount*)header) - 1;
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

CubsUnique cubs_unique_init(void *value, const CubsTypeContext *context)
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

    // If there are no weak references, free here.
    const bool shouldFree = cubs_atomic_load_64(&header->weakCount.count) == 0;

    cubs_rwlock_unlock_exclusive(&header->lock);

    if(shouldFree) { // there are no weak references
        header_free(header, self->context->sizeOfType);
    }
}

CubsWeak cubs_unique_make_weak(const CubsUnique *self)
{
    const RefHeader* header = (const RefHeader*)self->_inner;
    atomic_ref_count_add_ref((AtomicRefCount*)&header->weakCount); // explicitly const cast
    const CubsWeak weak = {._inner = self->_inner, .context = self->context};
    return weak;
}

void cubs_unique_lock_shared(const CubsUnique *self)
{
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

/// Copies the memory at `value`.
CubsShared cubs_shared_init(void* value, const CubsTypeContext* context) {
    assert(context != NULL);
    assert(value != NULL);

    RefHeader* header = header_init(true, context->sizeOfType);
    memcpy(header_value_mut(header), value, context->sizeOfType);
    const CubsShared shared = {._inner = (void*)header, .context = context};
    return shared;
}

void cubs_shared_deinit(CubsShared* self) {
    if(self->_inner == NULL) {
        return;
    }

    RefHeader* header = (RefHeader*)self->_inner;
    self->_inner = NULL;

    const bool lastRef = atomic_ref_count_remove_ref(header_shared_ref_count_mut(header));
    if(!lastRef) {
        return;
    }

    cubs_rwlock_lock_exclusive(&header->lock);

    if(self->context->destructor != NULL) {
        self->context->destructor(header_value_mut(header));
    }   
    cubs_atomic_flag_store(&header->isExpired, true);

    
    // If there are no weak references, free here.
    const bool shouldFree = cubs_atomic_load_64(&header->weakCount.count) == 0;

    cubs_rwlock_unlock_exclusive(&header->lock);

    if(shouldFree) { // there are no weak references
        header_free(header, self->context->sizeOfType);
    }
}

CubsWeak cubs_shared_make_weak(const CubsShared *self)
{
    const RefHeader* header = (const RefHeader*)self->_inner;
    atomic_ref_count_add_ref((AtomicRefCount*)&header->weakCount); // explicitly const cast
    const CubsWeak weak = {._inner = self->_inner, .context = self->context};
    return weak;
}

void cubs_shared_lock_shared(const CubsShared *self)
{
    const RefHeader* header = (const RefHeader*)self->_inner;
    cubs_rwlock_lock_shared(&header->lock);
}

bool cubs_shared_try_lock_shared(const CubsShared* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    return cubs_rwlock_try_lock_shared(&header->lock);
}

void cubs_shared_unlock_shared(const CubsShared* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    cubs_rwlock_unlock_shared(&header->lock);
}

void cubs_shared_lock_exclusive(CubsShared* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    cubs_rwlock_lock_exclusive(&header->lock);
}

bool cubs_shared_try_lock_exclusive(CubsShared* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    return cubs_rwlock_try_lock_exclusive(&header->lock);
}

void cubs_shared_unlock_exclusive(CubsShared* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    cubs_rwlock_unlock_exclusive(&header->lock);
}

const void *cubs_shared_get(const CubsShared *self)
{
    const RefHeader* header = (const RefHeader*)self->_inner;
    return header_value(header);
}

void *cubs_shared_get_mut(CubsShared *self)
{
    RefHeader* header = (RefHeader*)self->_inner;
    return header_value_mut(header);
}

CubsShared cubs_shared_clone(const CubsShared* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    AtomicRefCount* refCount = header_shared_ref_count_mut((RefHeader*)header); // explicitly cast away const
    atomic_ref_count_add_ref(refCount);
    return *self;
}

bool cubs_shared_eql(const CubsShared *self, const CubsShared *other)
{
    return self->_inner == other->_inner;
}

void cubs_weak_deinit(CubsWeak* self) {
    if(self->_inner == NULL) {
        return;
    }

    RefHeader* header = (RefHeader*)self->_inner;
    self->_inner = NULL;

    const bool isExpired = cubs_atomic_flag_load(&header->isExpired);
    const bool isLastWeakRef = atomic_ref_count_remove_ref(&header->weakCount);

    if(!isExpired || !isLastWeakRef) {
        return;
    }
    // is expired and is last weak ref
    // dont need to lock here since `self` is the only object with access to the memory
    header_free(header, self->context->sizeOfType);
}

void cubs_weak_lock_shared(const CubsWeak* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    cubs_rwlock_lock_shared(&header->lock);
}

bool cubs_weak_try_lock_shared(const CubsWeak* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    return cubs_rwlock_try_lock_shared(&header->lock);
}

void cubs_weak_unlock_shared(const CubsWeak* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    cubs_rwlock_unlock_shared(&header->lock);
}

void cubs_weak_lock_exclusive(CubsWeak* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    cubs_rwlock_lock_exclusive(&header->lock);
}

bool cubs_weak_try_lock_exclusive(CubsWeak* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    return cubs_rwlock_try_lock_exclusive(&header->lock);
}

void cubs_weak_unlock_exclusive(CubsWeak* self) {
    RefHeader* header = (RefHeader*)self->_inner;
    cubs_rwlock_unlock_exclusive(&header->lock);
}

bool cubs_weak_expired(const CubsWeak* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    return cubs_atomic_flag_load(&header->isExpired);
}

const void* cubs_weak_get(const CubsWeak* self) {
    assert(!cubs_weak_expired(self));
    const RefHeader* header = (const RefHeader*)self->_inner;
    return header_value(header);
}

void* cubs_weak_get_mut(CubsWeak* self) {
    assert(!cubs_weak_expired(self));
    RefHeader* header = (RefHeader*)self->_inner;
    return header_value_mut(header);
}

CubsWeak cubs_weak_clone(const CubsWeak* self) {
    const RefHeader* header = (const RefHeader*)self->_inner;
    atomic_ref_count_add_ref((AtomicRefCount*)&header->weakCount); // explicitly const cast
    return *self;
}

bool cubs_weak_eql(const CubsWeak* self, const CubsWeak* other) {
    return self->_inner == other->_inner;
}