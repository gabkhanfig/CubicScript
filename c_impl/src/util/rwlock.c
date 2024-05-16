#include "rwlock.h"

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

_Static_assert(sizeof(CubsRwLock) == sizeof(SRWLOCK), "For windows, the SRWLOCK implementation must be the same as CubsRwLock");

#endif


#if defined(_WIN32) || defined(WIN32)
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
#endif


