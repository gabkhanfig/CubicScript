//! Handles queueing Mutexes and RwLocks to be acquired in deterministic order at once.
//! If locks were not acquired in a deterministic order, and a thread needs to acquire two or more
//! locks that another thread also needs in different orders, it's possible a deadlock will occur.
//! `sync_queue` avoids this entirely by pre-sorting the locks by their addresses, and acquiring them
//! in that order.
//!
//! Uses thread local variables, with multiple, nested queues. When `acquire()` or `tryAcquire()` are called,
//! it will acquire the locks for the current queue, and then increment to the next.
//! `release()` will work accordingly, releasing the locks in the currently **ACQUIRED**
//! queue, and decrementing to the previous queue. If multiple queues have been acquired,
//! release goes in reverse order. It can be thought of a stack of queues.
//!
//! # Example:
//! ```
//! var lock1 = RwLock{};
//! var lock2 = RwLock{};
//!
//! // Thread 1
//! sync_queue.queueScriptRwLockExclusive(&lock1);
//! sync_queue.queueScriptRwLockExclusive(&lock2);
//! acquire();
//! defer release();
//!
//! // Thread 2
//! sync_queue.queueScriptRwLockExclusive(&lock2);
//! sync_queue.queueScriptRwLockExclusive(&lock1);
//! acquire(); // the locks will be acquired in the same order as in Thread 1 no matter which was queued first.
//! defer release();
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const RwLock = @import("../types/RwLock.zig");

threadlocal var threadLocalSyncQueue: SyncQueues = .{};

/// Acquires the currently queued sync objects.
/// Any queue operations before `release()` is called will be queued on a deeper nested
/// queue. Failing to call `release()` is undefined behaviour.
pub fn acquire() void {
    assert(threadLocalSyncQueue.current != null);

    threadLocalSyncQueue.queues[threadLocalSyncQueue.current.?].acquire();
    threadLocalSyncQueue.current = threadLocalSyncQueue.current.? + 1;
}

/// Acquires the currently queued sync objects.
/// Any queue operations before `release()` is called will be queued on a deeper nested
/// queue. Failing to call `release()` is undefined behaviour.
pub fn tryAcquire() bool {
    assert(threadLocalSyncQueue.current != null);

    if (threadLocalSyncQueue.queues[threadLocalSyncQueue.current.?].tryAcquire()) {
        threadLocalSyncQueue.current = threadLocalSyncQueue.current.? + 1;
        return true;
    } else {
        return false;
    }
}

/// Releases the acquired sync objects on the current queue.
pub fn release() void {
    assert(threadLocalSyncQueue.current != null);

    const releaseIndex = threadLocalSyncQueue.current.? - 1;
    threadLocalSyncQueue.queues[releaseIndex].release();
    threadLocalSyncQueue.current = releaseIndex;
}

pub fn queueScriptRwLockExclusive(lock: *RwLock) void {
    if (threadLocalSyncQueue.current) |current| {
        ensureTotalCapacityThreadLocal(current + 1);
    } else {
        ensureTotalCapacityThreadLocal(1);
        threadLocalSyncQueue.current = 0;
    }

    const object = SyncObject{ .object = @ptrCast(lock), .vtable = SCRIPT_RWLOCK_VTABLE, .lockType = .Exclusive };
    threadLocalSyncQueue.queues[threadLocalSyncQueue.current.?].addSyncObject(
        threadLocalSyncQueue.allocator,
        object,
    ) catch unreachable;
}

fn ensureTotalCapacityThreadLocal(minCapacity: usize) void {
    if (minCapacity >= threadLocalSyncQueue.queues.len) {
        const newQueues = threadLocalSyncQueue.allocator.alloc(SyncQueue, minCapacity) catch unreachable;
        @memset(newQueues, SyncQueue{});
        var i: usize = 0;
        for (threadLocalSyncQueue.queues) |oldQueue| {
            newQueues[i] = oldQueue;
            i += 1;
        }
        threadLocalSyncQueue.allocator.free(threadLocalSyncQueue.queues);
        threadLocalSyncQueue.queues = newQueues;
    }
}

const SyncQueues = struct {
    queues: []SyncQueue = std.mem.zeroes([]SyncQueue),
    allocator: Allocator = std.heap.c_allocator,
    /// Points to the current queue to push SyncObjects to.
    /// On release, `current - 1` is the queue index to use.
    current: ?usize = null,
};

const SyncQueue = struct {
    const Self = @This();

    objects: ArrayListUnmanaged(SyncObject) = .{},
    isAcquired: bool = false,

    fn acquire(self: *Self) void {
        for (self.objects.items) |object| {
            switch (object.lockType) {
                .Exclusive => {
                    object.vtable.lockExclusive(object.object);
                },
                .Shared => {
                    object.vtable.lockShared.?(object.object);
                },
            }
        }
    }

    fn tryAcquire(self: *Self) bool {
        var i: usize = 0; // Counts the amount of locks acquired.
        var didAcquireAll: bool = true;
        for (self.objects.items) |object| {
            switch (object.lockType) {
                .Exclusive => {
                    if (!object.vtable.tryLockExclusive(object.object)) {
                        didAcquireAll = false;
                        break;
                    }
                },
                .Shared => {
                    if (!object.vtable.tryLockShared.?(object.object)) {
                        didAcquireAll = false;
                        break;
                    }
                },
            }
            i += 1;
        }
        if (didAcquireAll) {
            return true;
        } else {
            while (i > 0) {
                i -= 1;

                var object = self.objects.items[i];
                switch (object.lockType) {
                    .Exclusive => {
                        object.vtable.unlockExclusive(object.object);
                    },
                    .Shared => {
                        object.vtable.unlockShared.?(object.object);
                    },
                }
            }
            return false;
        }
    }

    fn release(self: *Self) void {
        for (self.objects.items) |object| {
            switch (object.lockType) {
                .Exclusive => {
                    object.vtable.unlockExclusive(object.object);
                },
                .Shared => {
                    object.vtable.unlockShared.?(object.object);
                },
            }
        }
        self.objects.items.len = 0;
    }

    fn addSyncObject(self: *Self, allocator: Allocator, syncObject: SyncObject) Allocator.Error!void {
        const oldLength = self.objects.items.len;
        const newLength = oldLength + 1;
        try self.objects.resize(allocator, newLength);
        const buffer = self.objects.items;

        if (oldLength == 0) { // addOne() increases the length, so this means it has no prior elements
            //std.debug.print("no other sync objects, so putting at beginning\n", .{});
            buffer[0] = syncObject;
            return;
        }

        // TODO binary search. iterate for now.
        for (0..oldLength) |i| {
            const iterObject = buffer[i];
            if (@intFromPtr(iterObject.object) == @intFromPtr(syncObject.object)) { // dont sync duplicates
                //std.debug.print("found duplicate sync object at address {x}\n", .{@intFromPtr(syncObject.object)});
                self.objects.items.len -= 1;
                return;
            } else if (@intFromPtr(iterObject.object) < @intFromPtr(syncObject.object)) {
                continue;
            } else {
                var moveIter: usize = oldLength;
                while (moveIter > i) {
                    buffer[moveIter] = buffer[moveIter - 1]; // shuffle over elements
                    moveIter -= 1;
                }
                //std.debug.print("putting sync object at index {}\n", .{i});
                buffer[i] = syncObject;
                return;
            }
        }
        // Put at end
        //std.debug.print("putting sync object at the end\n", .{});
        buffer[oldLength] = syncObject;
    }
};

const SyncObject = struct {
    object: *anyopaque,
    vtable: *const VTable,
    lockType: enum {
        Exclusive,
        Shared,
    },
};

pub const VTable = extern struct {
    lockExclusive: *const fn (*anyopaque) callconv(.C) void,
    tryLockExclusive: *const fn (*anyopaque) callconv(.C) bool,
    unlockExclusive: *const fn (*anyopaque) callconv(.C) void,
    lockShared: ?*const fn (*anyopaque) callconv(.C) void = null,
    tryLockShared: ?*const fn (*anyopaque) callconv(.C) bool = null,
    unlockShared: ?*const fn (*anyopaque) callconv(.C) void = null,
    isMarkLocked: ?*const fn (*const anyopaque) callconv(.C) bool = null,
    markLocked: ?*const fn (*anyopaque) callconv(.C) void = null,
};

const SCRIPT_RWLOCK_VTABLE: *const VTable = &.{
    .lockExclusive = @ptrCast(&RwLock.write),
    .tryLockExclusive = @ptrCast(&RwLock.tryWrite),
    .unlockExclusive = @ptrCast(&RwLock.unlockWrite),
    .lockShared = @ptrCast(&RwLock.read),
    .tryLockShared = @ptrCast(&RwLock.tryRead),
    .unlockShared = @ptrCast(&RwLock.unlockRead),
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

const STD_MUTEX_VTABLE: *const VTable = &.{
    .lockExclusive = @ptrCast(&std_locking_functions.mutexLock),
    .tryLockExclusive = @ptrCast(&std_locking_functions.mutexTryLock),
    .unlockExclusive = @ptrCast(&std_locking_functions.mutexUnlock),
};

const STD_RWLOCK_VTABLE: *const VTable = &.{
    .lockExclusive = @ptrCast(&std_locking_functions.rwlockLock),
    .tryLockExclusive = @ptrCast(&std_locking_functions.rwlockTryLock),
    .unlockExclusive = @ptrCast(&std_locking_functions.rwlockUnlock),
    .lockShared = @ptrCast(&std_locking_functions.rwlockLockShared),
    .tryLockShared = @ptrCast(&std_locking_functions.rwlockTryLockShared),
    .unlockShared = @ptrCast(&std_locking_functions.rwlockUnlockShared),
};

test "acquire script rwlock exclusive" {
    var lock: RwLock = .{};
    queueScriptRwLockExclusive(&lock);
    acquire();
    defer release();
}

test "acquire two script rwlock exclusive" {
    {
        var lock1: RwLock = .{};
        var lock2: RwLock = .{};
        queueScriptRwLockExclusive(&lock1);
        queueScriptRwLockExclusive(&lock2);
        acquire();
        defer release();
    }
    {
        var lock1: RwLock = .{};
        var lock2: RwLock = .{};
        queueScriptRwLockExclusive(&lock2);
        queueScriptRwLockExclusive(&lock1);
        acquire();
        defer release();
    }
}

test "nested acquire exclusive" {
    var lock1: RwLock = .{};
    var lock2: RwLock = .{};
    queueScriptRwLockExclusive(&lock1);
    queueScriptRwLockExclusive(&lock2);
    acquire();
    defer release();
    {
        var lock3: RwLock = .{};
        var lock4: RwLock = .{};
        queueScriptRwLockExclusive(&lock4);
        queueScriptRwLockExclusive(&lock3);
        acquire();
        defer release();
    }
}
