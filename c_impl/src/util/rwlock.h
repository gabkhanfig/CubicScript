#pragma once

#include <stdbool.h>

typedef struct CubsRwLock {
#if defined(_WIN32) || defined WIN32
	void* srwlock;
#endif
} CubsRwLock;

void cubs_rwlock_init(CubsRwLock* rwlockToInit);

void cubs_rwlock_lock_shared(const CubsRwLock* self);

bool cubs_rwlock_try_lock_shared(const CubsRwLock* self);

void cubs_rwlock_unlock_shared(const CubsRwLock* self);

void cubs_rwlock_lock_exclusive(CubsRwLock* self);

bool cubs_rwlock_try_lock_exclusive(CubsRwLock* self);

void cubs_rwlock_unlock_exclusive(CubsRwLock* self);

