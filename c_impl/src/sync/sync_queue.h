#pragma once

#include <stdbool.h>

typedef void(*CubsSyncQueueLockExclusive)(void* lock);
typedef bool(*CubsSyncQueueTryLockExclusive)(void* lock);
typedef void(*CubsSyncQueueUnlockExclusive)(void* lock);
typedef void(*CubsSyncQueueLockShared)(const void* lock);
typedef bool(*CubsSyncQueueTryLockShared)(const void* lock);
typedef void(*CubsSyncQueueUnlockShared)(const void* lock);

typedef struct CubsSyncObjectVTable {
    CubsSyncQueueLockExclusive lockExclusive;
    CubsSyncQueueTryLockExclusive tryLockExclusive;
    CubsSyncQueueUnlockExclusive unlockExclusive;
    CubsSyncQueueLockShared lockShared;
    CubsSyncQueueTryLockShared tryLockShared;
    CubsSyncQueueUnlockShared unlockShared;
} CubsSyncObjectVTable;

typedef struct CubsSyncObject {
    void* ptr;
    const CubsSyncObjectVTable* vtable;
} CubsSyncObject;

void cubs_sync_queue_lock();

bool cubs_sync_queue_try_lock();

void cubs_sync_queue_unlock();

void cubs_sync_queue_add_exclusive(CubsSyncObject object);

void cubs_sync_queue_add_shared(CubsSyncObject object);