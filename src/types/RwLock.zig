//! Similar to zig's std RwLock, but uses operating system specific implementations where appropriate.
//! Currently, windows SRWLOCK is implemented. Otherwise, the zig default is used.
//! The size of the windows SRWLOCK is 8 bytes.

const std = @import("std");
const builtin = @import("builtin");

const Self = @This();

impl: Impl = .{},

const Impl = if (builtin.os.tag == .windows)
    Win32SRWLOCK
else
    std.Thread.RwLock;

/// Blocks until shared lock ownership is acquired.
pub fn read(self: *const Self) void {
    const mutSelf: *Self = @constCast(self);
    mutSelf.impl.lockShared();
}

/// Attempts to obtain shared lock ownership.
/// Returns `true` if the lock is obtained, `false` otherwise.
pub fn tryRead(self: *const Self) bool {
    const mutSelf: *Self = @constCast(self);
    return mutSelf.impl.tryLockShared();
}

/// Releases a held shared lock.
pub fn unlockRead(self: *const Self) void {
    const mutSelf: *Self = @constCast(self);
    mutSelf.impl.unlockShared();
}

/// Blocks until shared lock ownership is acquired.
pub fn write(self: *Self) void {
    self.impl.lock();
}

/// Attempts to obtain exclusive lock ownership.
/// Returns `true` if the lock is obtained, `false` otherwise.
pub fn tryWrite(self: *Self) void {
    return self.impl.tryLock();
}

/// Releases a held exclusive lock.
/// Asserts the lock is held exclusively.
pub fn unlockWrite(self: *Self) void {
    self.impl.unlock();
}

/// Function naming is the same as zig RwLock to make it simple.
const Win32SRWLOCK = struct {
    srwlock: std.os.windows.SRWLOCK = std.os.windows.SRWLOCK_INIT,

    /// Blocks until shared lock ownership is acquired.
    pub fn lockShared(rwl: *@This()) void {
        Win32Extern.AcquireSRWLockShared(&rwl.srwlock);
    }

    /// Attempts to obtain shared lock ownership.
    /// Returns `true` if the lock is obtained, `false` otherwise.
    pub fn tryLockShared(rwl: *@This()) bool {
        return Win32Extern.TryAcquireSRWLockShared(&rwl.srwlock);
    }

    /// Blocks until exclusive lock ownership is acquired.
    pub fn lock(rwl: *@This()) void {
        Win32Extern.AcquireSRWLockExclusive(&rwl.srwlock);
    }

    /// Attempts to obtain exclusive lock ownership.
    /// Returns `true` if the lock is obtained, `false` otherwise.
    pub fn tryLock(rwl: *@This()) bool {
        return Win32Extern.TryAcquireSRWLockExclusive(&rwl.srwlock);
    }

    /// Releases a held shared lock.
    pub fn unlockShared(rwl: *@This()) void {
        Win32Extern.ReleaseSRWLockShared(&rwl.srwlock);
    }

    /// Releases a held exclusive lock.
    pub fn unlock(rwl: *@This()) void {
        Win32Extern.ReleaseSRWLockExclusive(&rwl.srwlock);
    }

    const Win32Extern = struct {
        extern fn AcquireSRWLockExclusive(srwlock: *std.os.windows.SRWLOCK) void;
        extern fn AcquireSRWLockShared(srwlock: *std.os.windows.SRWLOCK) void;
        extern fn TryAcquireSRWLockExclusive(srwlock: *std.os.windows.SRWLOCK) bool;
        extern fn TryAcquireSRWLockShared(srwlock: *std.os.windows.SRWLOCK) bool;
        extern fn ReleaseSRWLockExclusive(srwlock: *std.os.windows.SRWLOCK) void;
        extern fn ReleaseSRWLockShared(srwlock: *std.os.windows.SRWLOCK) void;
    };
};
