#include "mutex.h"
#include <assert.h>

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

_Static_assert(sizeof(CubsMutex) == sizeof(SRWLOCK), "For Win32, the size of SRWLOCK must be the same as CubsRwLock");
_Static_assert(_Alignof(CubsMutex) == _Alignof(SRWLOCK), "For Win32, the alignment of SRWLOCK must be the same as CubsRwLock");

void cubs_mutex_init(CubsMutex* mutexToInit)
{
	mutexToInit->srwlock = NULL; // zero initialization does work. See macro SRWLOCK_INIT
}

void cubs_mutex_lock(CubsMutex* self)
{
	AcquireSRWLockExclusive((PSRWLOCK)self);
}

bool cubs_mutex_try_lock(CubsMutex* self)
{
	return TryAcquireSRWLockExclusive((PSRWLOCK)self);
}

void cubs_mutex_unlock(CubsMutex* self)
{
	ReleaseSRWLockExclusive((PSRWLOCK)self);
}

#elif __GNUC__

#include <pthread.h>

void cubs_mutex_init(CubsMutex* rwlockToInit)
{
	assert(pthread_mutex_init((pthread_mutex_t*)rwlockToInit, NULL) == 0);
}

void cubs_mutex_lock(CubsMutex* self)
{
	assert(pthread_mutex_lock((pthread_mutex_t*)self) == 0);
}

bool cubs_mutex_try_lock(CubsMutex* self)
{
	return pthread_mutex_trylock((pthread_mutex_t*)self) == 0;
}

void cubs_mutex_unlock(CubsMutex* self)
{
	assert(pthread_mutex_unlock((pthread_mutex_t*)self) == 0);
}

#endif
