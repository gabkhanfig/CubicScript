const std = @import("std");
const expect = std.testing.expect;
const Mutex = std.Thread.Mutex;
const RwLock = std.Thread.RwLock;
const ScriptMutex = @import("locks.zig").Mutex;
const ScriptRwLock = @import("locks.zig").RwLock;
const script_value = @import("../primitives//script_value.zig");
const Unique = script_value.Unique;
const Shared = script_value.Shared;
const Weak = script_value.Weak;

const c = struct {
    extern fn cubs_sync_queue_lock() callconv(.C) void;
    extern fn cubs_sync_queue_try_lock() callconv(.C) bool;
    extern fn cubs_sync_queue_unlock() callconv(.C) void;
    extern fn cubs_sync_queue_add_exclusive(object: SyncObject) callconv(.C) void;
    extern fn cubs_sync_queue_add_shared(object: SyncObject) callconv(.C) void;
    extern fn cubs_sync_queue_unique_add_exclusive(unique: *script_value.c.CubsUnique) callconv(.C) void;
    extern fn cubs_sync_queue_unique_add_shared(unique: *const script_value.c.CubsUnique) callconv(.C) void;
    extern fn cubs_sync_queue_shared_add_exclusive(shared: *script_value.c.CubsShared) callconv(.C) void;
    extern fn cubs_sync_queue_shared_add_shared(shared: *const script_value.c.CubsShared) callconv(.C) void;
    extern fn cubs_sync_queue_weak_add_exclusive(weak: *script_value.c.CubsWeak) callconv(.C) void;
    extern fn cubs_sync_queue_weak_add_shared(weak: *const script_value.c.CubsWeak) callconv(.C) void;
};

pub fn lock() void {
    c.cubs_sync_queue_lock();
}

pub fn tryLock() bool {
    return c.cubs_sync_queue_try_lock();
}

pub fn unlock() void {
    c.cubs_sync_queue_unlock();
}

pub fn addExclusive(object: SyncObject) void {
    c.cubs_sync_queue_add_exclusive(object);
}

pub fn addShared(object: SyncObject) void {
    c.cubs_sync_queue_add_shared(object);
}

pub fn addStdMutex(mutex: *Mutex) void {
    addExclusive(SyncObject{ .ptr = @ptrCast(mutex), .vtable = STD_MUTEX_VTABLE });
}

pub fn addStdRwLockExclusive(rwlock: *RwLock) void {
    addExclusive(SyncObject{ .ptr = @ptrCast(rwlock), .vtable = STD_RWLOCK_VTABLE });
}

pub fn addStdRwLockShared(rwlock: *const RwLock) void {
    addShared(SyncObject{ .ptr = @ptrCast(@constCast(rwlock)), .vtable = STD_RWLOCK_VTABLE });
}

pub fn addScriptMutex(mutex: *ScriptMutex) void {
    addExclusive(SyncObject{ .ptr = @ptrCast(mutex), .vtable = SCRIPT_MUTEX_VTABLE });
}

pub fn addScriptRwLockExclusive(rwlock: *ScriptRwLock) void {
    addExclusive(SyncObject{ .ptr = @ptrCast(rwlock), .vtable = SCRIPT_RWLOCK_VTABLE });
}

pub fn addScriptRwLockShared(rwlock: *const ScriptRwLock) void {
    addShared(SyncObject{ .ptr = @ptrCast(@constCast(rwlock)), .vtable = SCRIPT_RWLOCK_VTABLE });
}

pub fn addSyncPtrExclusive(ptr: anytype) void {
    const ptrType = @TypeOf(ptr);
    const typeInfo = @typeInfo(ptrType);
    if (typeInfo != .Pointer) {
        @compileError("Expected pointer type");
    }
    const ptrInfo = typeInfo.Pointer;
    if (ptrInfo.size != .One) {
        @compileError("Expected a one pointer");
    }
    if (ptrInfo.is_const) {
        @compileError("Cannot get exclusive access to a const sync object");
    }
    if (!@hasDecl(ptrInfo.child, "SCRIPT_SELF_TAG")) {
        @compileError("Expected script sync ptr type");
    }
    const scriptSelfTag: script_value.ValueTag = ptrInfo.child.SCRIPT_SELF_TAG;
    switch (scriptSelfTag) {
        .unique => {
            c.cubs_sync_queue_unique_add_exclusive(ptr.asRawMut());
        },
        .shared => {
            c.cubs_sync_queue_shared_add_exclusive(ptr.asRawMut());
        },
        .weak => {
            c.cubs_sync_queue_weak_add_exclusive(ptr.asRawMut());
        },
        else => {
            @compileError("Expected Unique, Shared, or Weak ptrs");
        },
    }
}

pub fn addSyncPtrShared(ptr: anytype) void {
    const ptrType = @TypeOf(ptr);
    const typeInfo = @typeInfo(ptrType);
    if (typeInfo == .Pointer) {
        @compileError("Expected pointer type");
    }
    const ptrInfo = typeInfo.Pointer;
    if (ptrInfo.size != .One) {
        @compileError("Expected a one pointer");
    }
    if (!@hasDecl(ptrInfo.child, "SCRIPT_SELF_TAG")) {
        @compileError("Expected script sync ptr type");
    }
    const scriptSelfTag: script_value.ValueTag = ptrInfo.child.SCRIPT_SELF_TAG;
    switch (scriptSelfTag) {
        .unique => {
            c.cubs_sync_queue_unique_add_shared(ptr.asRawMut());
        },
        .shared => {
            c.cubs_sync_queue_shared_add_shared(ptr.asRawMut());
        },
        .weak => {
            c.cubs_sync_queue_weak_add_shared(ptr.asRawMut());
        },
        else => {
            @compileError("Expected Unique, Shared, or Weak ptrs");
        },
    }
}

pub const SyncObject = extern struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = extern struct {
        lockExclusive: ?*const fn (*anyopaque) callconv(.C) void,
        tryLockExclusive: ?*const fn (*anyopaque) callconv(.C) bool,
        unlockExclusive: ?*const fn (*anyopaque) callconv(.C) void,
        lockShared: ?*const fn (*anyopaque) callconv(.C) void,
        tryLockShared: ?*const fn (*anyopaque) callconv(.C) bool,
        unlockShared: ?*const fn (*anyopaque) callconv(.C) void,
    };
};

const std_locking_functions = struct {
    fn mutexLock(mutex: *std.Thread.Mutex) callconv(.C) void {
        mutex.lock();
    }

    fn mutexTryLock(mutex: *std.Thread.Mutex) callconv(.C) bool {
        return mutex.tryLock();
    }

    fn mutexUnlock(mutex: *std.Thread.Mutex) callconv(.C) void {
        mutex.unlock();
    }

    fn rwlockLock(rwl: *std.Thread.RwLock) callconv(.C) void {
        rwl.lock();
    }

    fn rwlockTryLock(rwl: *std.Thread.RwLock) callconv(.C) bool {
        return rwl.tryLock();
    }

    fn rwlockUnlock(rwl: *std.Thread.RwLock) callconv(.C) void {
        rwl.unlock();
    }

    fn rwlockLockShared(rwl: *std.Thread.RwLock) callconv(.C) void {
        rwl.lockShared();
    }

    fn rwlockTryLockShared(rwl: *std.Thread.RwLock) callconv(.C) bool {
        return rwl.tryLockShared();
    }

    fn rwlockUnlockShared(rwl: *std.Thread.RwLock) callconv(.C) void {
        rwl.unlockShared();
    }
};

const STD_MUTEX_VTABLE: *const SyncObject.VTable = &.{
    .lockExclusive = @ptrCast(&std_locking_functions.mutexLock),
    .tryLockExclusive = @ptrCast(&std_locking_functions.mutexTryLock),
    .unlockExclusive = @ptrCast(&std_locking_functions.mutexUnlock),
    .lockShared = null,
    .tryLockShared = null,
    .unlockShared = null,
};

const STD_RWLOCK_VTABLE: *const SyncObject.VTable = &.{
    .lockExclusive = @ptrCast(&std_locking_functions.rwlockLock),
    .tryLockExclusive = @ptrCast(&std_locking_functions.rwlockTryLock),
    .unlockExclusive = @ptrCast(&std_locking_functions.rwlockUnlock),
    .lockShared = @ptrCast(&std_locking_functions.rwlockLockShared),
    .tryLockShared = @ptrCast(&std_locking_functions.rwlockTryLockShared),
    .unlockShared = @ptrCast(&std_locking_functions.rwlockUnlockShared),
};

const SCRIPT_RWLOCK_VTABLE: *const SyncObject.VTable = &.{
    .lockExclusive = @ptrCast(&ScriptRwLock.lockExclusive),
    .tryLockExclusive = @ptrCast(&ScriptRwLock.tryLockExclusive),
    .unlockExclusive = @ptrCast(&ScriptRwLock.unlockExclusive),
    .lockShared = @ptrCast(&ScriptRwLock.lockShared),
    .tryLockShared = @ptrCast(&ScriptRwLock.tryLockShared),
    .unlockShared = @ptrCast(&ScriptRwLock.unlockShared),
};

const SCRIPT_MUTEX_VTABLE: *const SyncObject.VTable = &.{
    .lockExclusive = @ptrCast(&ScriptMutex.lock),
    .tryLockExclusive = @ptrCast(&ScriptMutex.tryLock),
    .unlockExclusive = @ptrCast(&ScriptMutex.unlock),
    .lockShared = null,
    .tryLockShared = null,
    .unlockShared = null,
};

test lock {
    { // lock one
        var m = Mutex{};
        addStdMutex(&m);
        lock();
        unlock();
    }
    { // lock multiple
        var lock1 = Mutex{};
        var lock2 = RwLock{};
        var lock3 = RwLock{};
        { // order 1
            addStdMutex(&lock1);
            addStdRwLockExclusive(&lock2);
            addStdRwLockShared(&lock3);
            lock();
            defer unlock();
        }
        { // order 2
            addStdRwLockShared(&lock2);
            addStdMutex(&lock1);
            addStdRwLockExclusive(&lock3);
            lock();
            defer unlock();
        }
    }
}

test tryLock {
    {
        var m = Mutex{};
        addStdMutex(&m);
        try expect(tryLock());
        defer unlock();
    }
}
