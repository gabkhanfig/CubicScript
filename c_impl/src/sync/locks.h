#pragma once

#include <stdbool.h>

#if defined(_WIN32) || defined WIN32

typedef union CubsMutex {
	void* srwlock;
} CubsMutex;

typedef union CubsRwLock {
	void* srwlock;
} CubsRwLock;

#elif __GNUC__

#if __APPLE__

#include <sys/_pthread/_pthread_types.h>

typedef union CubsMutex {
    struct _opaque_pthread_mutex_t mutex;
} CubsMutex;

typedef union CubsRwLock {
    struct _opaque_pthread_rwlock_t rwlock;
} CubsRwLock;

#else // __APPLE__

#include <bits/pthreadtypes-arch.h>

typedef union CubsMutex {
    char __size[__SIZEOF_PTHREAD_MUTEX_T]; // copied directly from pthread_mutex_t
    long int __align;
} CubsMutex;

typedef union CubsRwLock {
    char __size[__SIZEOF_PTHREAD_RWLOCK_T]; // copied directly from pthread_rwlock_t
    long int __align;
} CubsRwLock;

#endif // APPLE
#endif // WIN32 / GNUC

void cubs_mutex_init(CubsMutex* mutexToInit);

void cubs_mutex_lock(CubsMutex* self);

bool cubs_mutex_try_lock(CubsMutex* self);

void cubs_mutex_unlock(CubsMutex* self);

void cubs_rwlock_init(CubsRwLock* rwlockToInit);

void cubs_rwlock_lock_shared(const CubsRwLock* self);

bool cubs_rwlock_try_lock_shared(const CubsRwLock* self);

void cubs_rwlock_unlock_shared(const CubsRwLock* self);

void cubs_rwlock_lock_exclusive(CubsRwLock* self);

bool cubs_rwlock_try_lock_exclusive(CubsRwLock* self);

void cubs_rwlock_unlock_exclusive(CubsRwLock* self);