#include "sync_queue.h"
#include <assert.h>
#include <string.h>
#include "../util/panic.h"

// TODO thread local allocation?

extern void* _cubs_os_aligned_malloc(size_t len, size_t align);
extern void* _cubs_os_aligned_free(void *buf, size_t len, size_t align);

static const size_t OBJECT_PTR_BITMASK = 0xFFFFFFFFFFFFULL;
static const size_t TAG_BITMASK = ~0xFFFFFFFFFFFFULL;

typedef enum {
    Exclusive = 0,
    Shared = 1,
} LockAcquireType;

typedef struct {
    size_t taggedPtr;
    const CubsSyncObjectVTable* vtable;
} InQueueSyncObj;

typedef struct {
    InQueueSyncObj* objects;
    size_t len;
    size_t capacity;
    bool isAcquired;
} SyncQueue;

static void acquire(SyncQueue* self) {
    for(size_t i = 0; i < self->len; i++) {
        const InQueueSyncObj obj = self->objects[i];
        LockAcquireType acquireType = obj.taggedPtr >> 48;
        void* ptr = (void*)(obj.taggedPtr & OBJECT_PTR_BITMASK);
        if(acquireType == Exclusive) {
            obj.vtable->lockExclusive(ptr);
        } else {
            obj.vtable->lockShared(ptr);
        }
    }
}

static bool try_acquire(SyncQueue* self) {
    size_t i = 0;
    bool didAcquireAll = true;
    for(; i < self->len; i++) {
        const InQueueSyncObj obj = self->objects[i];
        LockAcquireType acquireType = obj.taggedPtr >> 48;
        void* ptr = (void*)(obj.taggedPtr & OBJECT_PTR_BITMASK);
        if(acquireType == Exclusive) {
            if(!obj.vtable->tryLockExclusive(ptr)) {
                didAcquireAll = false;
                break;
            }
        } else {
            if(!obj.vtable->tryLockShared(ptr)) {
                didAcquireAll = false;
                break;
            }
        }
    }

    if(didAcquireAll) {
        return true;
    }

    while(i > 0) {
        i -= 1;
      
        const InQueueSyncObj obj = self->objects[i];
        LockAcquireType acquireType = obj.taggedPtr >> 48;
        void* ptr = (void*)(obj.taggedPtr & OBJECT_PTR_BITMASK);
        if(acquireType == Exclusive) {
            obj.vtable->unlockExclusive(ptr);
        } else {
            obj.vtable->unlockShared(ptr);
        }
    }
    self->len = 0; // "Clear" the currently held sync objects
    return false;
}

static void release(SyncQueue* self) {
    for(size_t i = 0; i < self->len; i++) {
        const InQueueSyncObj obj = self->objects[i];
        LockAcquireType acquireType = obj.taggedPtr >> 48;
        void* ptr = (void*)(obj.taggedPtr & OBJECT_PTR_BITMASK);
        if(acquireType == Exclusive) {
            obj.vtable->unlockExclusive(ptr);
        } else {
            obj.vtable->unlockShared(ptr);
        }
    }
    self->len = 0;
}

static void add_sync_object(SyncQueue* self, CubsSyncObject object, LockAcquireType acquireType) {
    // TODO add debug validation that object has not been acquired by a higher level sync queue
    if((self->len + 1) > self->capacity) {
        size_t newObjectCapacity = 64 / sizeof(InQueueSyncObj); // is 4 here, this ensures no false sharing for 64 byte aligned object
        if(self->capacity != 0) {
           newObjectCapacity = newObjectCapacity << 1; // ensures allocates a multiple of 64 bytes
        }
        InQueueSyncObj* newObjects = (InQueueSyncObj*)_cubs_os_aligned_malloc(sizeof(InQueueSyncObj) * newObjectCapacity, 64);
        if(newObjects == NULL) {
            cubs_panic("CubicScript failed to allocate memory");
        }
        if(self->objects != NULL) {
            memcpy((void*)newObjects, (const void*)self->objects, sizeof(InQueueSyncObj) * self->len);
            _cubs_os_aligned_free((void*)self->objects, self->capacity, 64);
        }
        self->objects = newObjects;
        self->capacity = newObjectCapacity;
    }

    const InQueueSyncObj syncObject = {.taggedPtr = ((size_t)object.ptr) | ((size_t)acquireType << 48), .vtable = object.vtable};

    if(self->len == 0) {
        self->objects[0] = syncObject;
        self->len = 1;
        return;
    }

    for(size_t i = 0; i < self->len; i++) {
        const InQueueSyncObj iterObject = self->objects[i];
        const size_t iterObjectPtrMask = iterObject.taggedPtr & OBJECT_PTR_BITMASK;
        const size_t syncObjectPtrMask = ((size_t)object.ptr);
        if(iterObjectPtrMask == syncObjectPtrMask) {
            // duplicate entry
            return;
        }
        if(iterObjectPtrMask < syncObjectPtrMask) {
            continue;
        }

        size_t moveIter = self->len; // self->len is guaranteed to be greater than 0 here
        while(true) {
            moveIter -= 1; 
            assert(self->capacity > (moveIter + 1));
            self->objects[moveIter + 1] = self->objects[moveIter];
            if(moveIter <= i) {
                break;
            }
        }

        self->objects[i] = syncObject;
        self->len += 1;
        return;
    }
    self->objects[self->len] = syncObject;
    self->len += 1;
}

typedef struct {
    SyncQueue* queues;
    size_t queueCount;
    size_t current;
} SyncQueues;

static _Thread_local SyncQueues threadLocalQueues;

static void queues_ensure_total_capacity() {
    if((threadLocalQueues.current + 1) <= threadLocalQueues.queueCount) {
        return;
    }

    size_t newObjectCapacity = 64 / sizeof(SyncQueue); // is 2 here, this ensures no false sharing for 64 byte aligned object
    if(threadLocalQueues.queueCount != 0) {
        newObjectCapacity = threadLocalQueues.queueCount << 1; // ensures allocates a multiple of 64 bytes
    }
    SyncQueue* newQueues = (SyncQueue*)_cubs_os_aligned_malloc(sizeof(SyncQueue) * newObjectCapacity, 64);
    if(newQueues == NULL) {
        cubs_panic("CubicScript failed to allocate memory");
    }
    memset(newQueues, 0, sizeof(SyncQueue) * newObjectCapacity);
    if(threadLocalQueues.queues != NULL) {
        memcpy((void*)newQueues, (const void*)threadLocalQueues.queues, sizeof(SyncQueue) * threadLocalQueues.queueCount);
        _cubs_os_aligned_free((void*)threadLocalQueues.queues, sizeof(SyncQueue) * threadLocalQueues.queueCount, 64);
    }
    threadLocalQueues.queues = newQueues;
    threadLocalQueues.queueCount = newObjectCapacity;
}

void cubs_sync_queue_lock()
{
    acquire(&threadLocalQueues.queues[threadLocalQueues.current]);
    threadLocalQueues.current += 1;
}

bool cubs_sync_queue_try_lock()
{
    if(try_acquire(&threadLocalQueues.queues[threadLocalQueues.current])) {
        threadLocalQueues.current += 1;
        return true;
    }
    return false;
}

void cubs_sync_queue_unlock()
{  
    #if _DEBUG
    if(threadLocalQueues.current == 0) {
        cubs_panic("Cannot unlock Cubic Script sync queue when there are no acquired queues");
    }
    #endif
    const size_t releaseIndex = threadLocalQueues.current - 1;  
    release(&threadLocalQueues.queues[releaseIndex]);
    threadLocalQueues.current = releaseIndex;
}

void cubs_sync_queue_add_exclusive(CubsSyncObject object)
{
    assert(object.vtable->lockExclusive != NULL);
    assert(object.vtable->tryLockExclusive != NULL);
    assert(object.vtable->unlockExclusive != NULL);
    queues_ensure_total_capacity();
    add_sync_object(&threadLocalQueues.queues[threadLocalQueues.current], object, Exclusive);
}

void cubs_sync_queue_add_shared(CubsSyncObject object)
{    
    assert(object.vtable->lockShared != NULL);
    assert(object.vtable->tryLockShared != NULL);
    assert(object.vtable->unlockShared != NULL);
    queues_ensure_total_capacity();
    add_sync_object(&threadLocalQueues.queues[threadLocalQueues.current], object, Shared);
}
