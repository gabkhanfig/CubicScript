#include "locks.h"
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

_Static_assert(sizeof(CubsRwLock) == sizeof(SRWLOCK), "For Win32, the size of SRWLOCK must be the same as CubsRwLock");
_Static_assert(_Alignof(CubsRwLock) == _Alignof(SRWLOCK), "For Win32, the alignment of SRWLOCK must be the same as CubsRwLock");

void cubs_rwlock_init(CubsRwLock* rwlockToInit)
{
	rwlockToInit->srwlock = NULL; // zero initialization does work. See macro SRWLOCK_INIT
}

void cubs_rwlock_lock_shared(const CubsRwLock* self)
{
	AcquireSRWLockShared((PSRWLOCK)self);
}

bool cubs_rwlock_try_lock_shared(const CubsRwLock* self)
{
	return TryAcquireSRWLockShared((PSRWLOCK)self);
}

void cubs_rwlock_unlock_shared(const CubsRwLock* self)
{
	ReleaseSRWLockShared((PSRWLOCK)self);
}

void cubs_rwlock_lock_exclusive(CubsRwLock* self)
{
	AcquireSRWLockExclusive((PSRWLOCK)self);
}

bool cubs_rwlock_try_lock_exclusive(CubsRwLock* self)
{
	return TryAcquireSRWLockExclusive((PSRWLOCK)self);
}

void cubs_rwlock_unlock_exclusive(CubsRwLock* self)
{
	ReleaseSRWLockExclusive((PSRWLOCK)self);
}

#elif __GNUC__

#include <pthread.h>

_Static_assert(sizeof(CubsMutex) == sizeof(pthread_mutex_t), "The size of pthread_rwlock_t must be the same size as CubsRwLock");
_Static_assert(_Alignof(CubsMutex) == _Alignof(pthread_mutex_t), "The alignment of pthread_rwlock_t must be the same as CubsRwLock");

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

_Static_assert(sizeof(CubsRwLock) == sizeof(pthread_rwlock_t), "The size of pthread_rwlock_t must be the same size as CubsRwLock");
_Static_assert(_Alignof(CubsRwLock) == _Alignof(pthread_rwlock_t), "The alignment of pthread_rwlock_t must be the same as CubsRwLock");

void cubs_rwlock_init(CubsRwLock* rwlockToInit)
{
	assert(pthread_rwlock_init((pthread_rwlock_t*)rwlockToInit, NULL) == 0);
}

void cubs_rwlock_lock_shared(const CubsRwLock* self)
{
	pthread_rwlock_rdlock((pthread_rwlock_t*)self);
}

bool cubs_rwlock_try_lock_shared(const CubsRwLock* self)
{
	return pthread_rwlock_tryrdlock((pthread_rwlock_t*)self) == 0;
}

void cubs_rwlock_unlock_shared(const CubsRwLock* self)
{
	pthread_rwlock_unlock((pthread_rwlock_t*)self);
}

void cubs_rwlock_lock_exclusive(CubsRwLock* self)
{
	pthread_rwlock_wrlock((pthread_rwlock_t*)self);
}

bool cubs_rwlock_try_lock_exclusive(CubsRwLock* self)
{
	return pthread_rwlock_trywrlock((pthread_rwlock_t*)self) == 0;
}

void cubs_rwlock_unlock_exclusive(CubsRwLock* self)
{
	pthread_rwlock_unlock((pthread_rwlock_t*)self);
}

#endif