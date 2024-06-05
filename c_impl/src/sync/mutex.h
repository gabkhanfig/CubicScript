#pragma once

#include <stdbool.h>

#if defined(_WIN32) || defined WIN32

typedef union CubsMutex {
	void* srwlock;
} CubsMutex;

#elif __GNUC__

#include <bits/pthreadtypes-arch.h>

typedef union CubsMutex {
    char __size[__SIZEOF_PTHREAD_MUTEX_T]; // copied directly from pthread_mutex_t
    long int __align;
} CubsMutex;

#endif

void cubs_mutex_init(CubsMutex* mutexToInit);

void cubs_mutex_lock(CubsMutex* self);

bool cubs_mutex_try_lock(CubsMutex* self);

void cubs_mutex_unlock(CubsMutex* self);