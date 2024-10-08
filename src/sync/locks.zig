const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("sync/locks.h");
});

pub const Mutex = struct {
    const Self = @This();

    cMutex: c.CubsMutex = c._CUBS_MUTEX_INITIALIZER,

    pub fn lock(self: *Self) void {
        c.cubs_mutex_lock(&self.cMutex);
    }

    pub fn tryLock(self: *Self) bool {
        return c.cubs_mutex_try_lock(&self.cMutex);
    }

    pub fn unlock(self: *Self) void {
        return c.cubs_mutex_unlock(&self.cMutex);
    }

    test lock {
        var mutex = Self{};
        mutex.lock();
        mutex.unlock();
    }

    test tryLock {
        var mutex = Self{};
        try expect(mutex.tryLock());
        mutex.unlock();
    }
};

pub const RwLock = struct {
    const Self = @This();

    cRwLock: c.CubsRwLock = c._CUBS_RWLOCK_INITIALIZER,

    pub fn lockShared(self: *const Self) void {
        c.cubs_rwlock_lock_shared(&self.cRwLock);
    }

    pub fn tryLockShared(self: *const Self) bool {
        return c.cubs_rwlock_try_lock_shared(&self.cRwLock);
    }

    pub fn unlockShared(self: *const Self) void {
        c.cubs_rwlock_unlock_shared(&self.cRwLock);
    }

    pub fn lockExclusive(self: *Self) void {
        c.cubs_rwlock_lock_exclusive(&self.cRwLock);
    }

    pub fn tryLockExclusive(self: *Self) bool {
        return c.cubs_rwlock_try_lock_exclusive(&self.cRwLock);
    }

    pub fn unlockExclusive(self: *Self) void {
        c.cubs_rwlock_unlock_exclusive(&self.cRwLock);
    }

    test lockShared {
        var rwlock = Self{};
        rwlock.lockShared();
        rwlock.unlockShared();
    }

    test tryLockShared {
        var rwlock = Self{};
        try expect(rwlock.tryLockShared());
        rwlock.unlockShared();
    }

    test lockExclusive {
        var rwlock = Self{};
        rwlock.lockExclusive();
        rwlock.unlockExclusive();
    }

    test tryLockExclusive {
        var rwlock = Self{};
        try expect(rwlock.tryLockExclusive());
        rwlock.unlockExclusive();
    }
};
