const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const TaggedValue = root.TaggedValue;
const AtomicRefCount = @import("atomic_ref_count.zig").AtomicRefCount;
const AtomicOrder = std.builtin.AtomicOrder;
const AtomicValue = std.atomic.Value;
const RwLock = @import("RwLock.zig");
const allocator = @import("../state/global_allocator.zig").allocator;
const sync_queue = @import("../state/sync_queue.zig");

const PTR_BITMASK = 0xFFFFFFFFFFFF;
const TAG_BITMASK: usize = ~@as(usize, PTR_BITMASK);

// TODO combine into one allocation rather than two for the weak ref container. When the shared ref is destroyed,
// but a weak ref still exists, deinit the raw value, but dont free the allocated memory for the shared object itself.
pub const Shared = extern struct {
    const Self = @This();

    inner: usize,

    /// Takes ownership of `value`.
    pub fn init(value: TaggedValue) Self {
        const tagInt: usize = @shlExact(value.tag.asUsize(), 48);
        const newInner = allocator().create(Inner) catch {
            @panic("Script out of memory");
        };
        const newWeakContainer = allocator().create(WeakRefContainer) catch {
            @panic("Script out of memory");
        };
        newWeakContainer.* = WeakRefContainer{ .shared = AtomicValue(?*RawValue).init(&newInner.value) };
        newInner.* = Inner{ .value = value.value, .weakRef = newWeakContainer };
        return Self{ .inner = tagInt | @intFromPtr(newInner) };
    }

    pub fn clone(self: *const Self) Self {
        const refCount: *AtomicRefCount = @constCast(&self.asInner().refCount);
        refCount.addRef();
        return Self{ .inner = self.inner };
    }

    pub fn deinit(self: *Self) void {
        const valueTag = self.tag();
        if (self.inner == 0) {
            return;
        }

        const inner = self.asInnerMut();
        self.inner = 0;
        if (inner.refCount.removeRef()) {
            inner.weakRef.lock.write(); // a weak reference could be currently read/write
            inner.weakRef.shared.store(null, AtomicOrder.release);
            const shouldDestroyWeak = inner.weakRef.refCount.count.load(AtomicOrder.acquire) == 0;
            inner.value.deinit(valueTag);
            inner.weakRef.lock.unlockWrite();
            if (shouldDestroyWeak) {
                allocator().destroy(inner.weakRef);
            }
            allocator().destroy(inner);
        }
    }

    pub fn tag(self: *const Self) ValueTag {
        return @enumFromInt(@shrExact(self.inner & TAG_BITMASK, 48));
    }

    pub fn write(self: *Self) callconv(.C) void {
        self.asInnerMut().weakRef.lock.write();
    }

    pub fn tryWrite(self: *Self) callconv(.C) bool {
        return self.asInnerMut().weakRef.lock.tryWrite();
    }

    pub fn unlockWrite(self: *Self) callconv(.C) void {
        self.asInnerMut().weakRef.lock.unlockWrite();
    }

    pub fn read(self: *const Self) callconv(.C) void {
        self.asInner().weakRef.lock.read();
    }

    pub fn tryRead(self: *const Self) callconv(.C) bool {
        return self.asInner().weakRef.lock.tryRead();
    }

    pub fn unlockRead(self: *const Self) callconv(.C) void {
        self.asInner().weakRef.lock.unlockRead();
    }

    pub fn getUnchecked(self: *const Self) *const RawValue {
        return &self.asInner().value;
    }

    pub fn getUncheckedMut(self: *Self) *RawValue {
        return &self.asInnerMut().value;
    }

    pub fn makeWeak(self: *Self) WeakShared {
        const inner = self.asInnerMut();
        inner.weakRef.refCount.addRef();
        return WeakShared{ .inner = (self.inner & TAG_BITMASK) | @intFromPtr(inner.weakRef) };
    }

    fn asInner(self: *const Self) *const Inner {
        const ptr: *anyopaque = @ptrFromInt(self.inner & PTR_BITMASK);
        return @ptrCast(@alignCast(ptr));
    }

    fn asInnerMut(self: *Self) *Inner {
        const ptr: *anyopaque = @ptrFromInt(self.inner & PTR_BITMASK);
        return @ptrCast(@alignCast(ptr));
    }

    const Inner = struct {
        refCount: AtomicRefCount = .{ .count = std.atomic.Value(usize).init(1) },
        value: RawValue,
        /// This holds the actual lock
        weakRef: *WeakRefContainer,
    };
};

/// Is created from a `Shared` object. See `Shared.makeWeak()`.
pub const WeakShared = extern struct {
    const Self = @This();

    inner: usize,

    pub fn deinit(self: *Self) void {
        if (self.inner == 0) {
            return;
        }
        const inner = self.asInner();
        self.inner = 0;
        if (inner.shared.load(AtomicOrder.acquire) != null) {
            _ = inner.refCount.removeRef();
        } else {
            if (inner.refCount.removeRef()) {
                allocator().destroy(inner);
            }
        }
    }

    pub fn tag(self: *const Self) ValueTag {
        return @enumFromInt(@shrExact(self.inner & TAG_BITMASK, 48));
    }

    pub fn write(self: *Self) callconv(.C) void {
        const inner = self.asInner();
        inner.lock.write();
    }

    pub fn tryWrite(self: *Self) callconv(.C) bool {
        const inner = self.asInner();
        return inner.lock.tryWrite();
    }

    pub fn unlockWrite(self: *Self) callconv(.C) void {
        const inner = self.asInner();
        inner.lock.unlockWrite();
    }

    pub fn read(self: *const Self) callconv(.C) void {
        const inner = self.asInner();
        inner.lock.read();
    }

    pub fn tryRead(self: *const Self) callconv(.C) bool {
        const inner = self.asInner();
        return inner.lock.tryRead();
    }

    pub fn unlockRead(self: *const Self) callconv(.C) void {
        const inner = self.asInner();
        inner.lock.unlockRead();
    }

    pub fn get(self: *const Self) *const RawValue {
        return self.asInner().shared.raw.?;
    }

    pub fn getMut(self: *Self) *RawValue {
        return self.asInner().shared.raw.?;
    }

    /// This should only be called while a lock is acquired.
    pub fn expired(self: *const Self) bool {
        if (self.inner == 0) {
            return true;
        } else {
            const inner = self.asInner();
            const load = inner.shared.load(AtomicOrder.acquire);
            return load == null;
        }
    }

    fn asInner(self: Self) *WeakRefContainer {
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }
};

const WeakRefContainer = struct {
    shared: AtomicValue(?*RawValue),
    /// The shared object ALSO uses this lock. `sync_queue` allows trying to acquire the same lock.
    lock: RwLock = .{},
    refCount: AtomicRefCount = AtomicRefCount{ .count = AtomicValue(usize).init(0) },
};

pub fn getSharedLock(shared: Shared) *RwLock {
    return &shared.asInner().weakRef.lock;
}

pub fn getWeakLock(weak: WeakShared) *RwLock {
    return &weak.asInner().lock;
}

test "shared init deinit" {
    var shared = Shared.init(TaggedValue.initInt(10));
    defer shared.deinit();

    try expect(shared.tag() == .Int);
    try expect(shared.getUnchecked().int == 10);
}

test "shared free memory on deinit" {
    var shared = Shared.init(TaggedValue.initString(root.String.initSliceUnchecked("erm...")));
    defer shared.deinit();
}

test "shared acquire locks manually" {
    var shared = Shared.init(TaggedValue.initInt(10));
    defer shared.deinit();
    {
        shared.read();
        defer shared.unlockRead();
        try expect(shared.getUnchecked().int == 10);
    }
    {
        try expect(shared.tryRead());
        defer shared.unlockRead();
        try expect(shared.getUnchecked().int == 10);
    }
    {
        shared.write();
        defer shared.unlockWrite();
        shared.getUncheckedMut().int += 10;
    }
    {
        try expect(shared.tryWrite());
        defer shared.unlockWrite();
        shared.getUncheckedMut().int += 10;
    }
    try expect(shared.getUnchecked().int == 30);
}

test "shared acquire in sync queue" {
    var shared = Shared.init(TaggedValue.initInt(10));
    defer shared.deinit();
    {
        sync_queue.queueScriptSharedRefExclusive(&shared);
        sync_queue.acquire();
        defer sync_queue.release();
        shared.getUncheckedMut().int += 10;
    }
    {
        sync_queue.queueScriptSharedRefShared(&shared);
        sync_queue.acquire();
        defer sync_queue.release();
        try expect(shared.getUnchecked().int == 20);
    }
}

test "shared make one weak ref" {
    { // deinit shared BEFORE weak
        var shared = Shared.init(TaggedValue.initInt(10));
        defer shared.deinit();
        var weak = shared.makeWeak();
        defer weak.deinit();
    }
    { // deinit shared AFTER weak

        var shared = Shared.init(TaggedValue.initInt(10));
        var weak = shared.makeWeak();
        weak.deinit();
        shared.deinit();
    }
}

test "shared make two weak ref" {
    { // deinit shared BEFIRE both weak
        var shared = Shared.init(TaggedValue.initInt(10));
        defer shared.deinit();
        var weak1 = shared.makeWeak();
        defer weak1.deinit();
        var weak2 = shared.makeWeak();
        defer weak2.deinit();
    }
    { // deinit shared BEFORE 1 weak and AFTER another
        var shared = Shared.init(TaggedValue.initInt(10));
        var weak1 = shared.makeWeak();
        var weak2 = shared.makeWeak();
        weak1.deinit();
        shared.deinit();
        weak2.deinit();
    }
    { // deinit shared AFTER both weak
        var shared = Shared.init(TaggedValue.initInt(10));
        var weak1 = shared.makeWeak();
        var weak2 = shared.makeWeak();
        weak1.deinit();
        weak2.deinit();
        shared.deinit();
    }
}

test "two shared make two weak ref" {
    { // deinit both shared BEFORE both weak
        var shared1 = Shared.init(TaggedValue.initInt(10));
        defer shared1.deinit();
        var shared2 = shared1.clone();
        defer shared2.deinit();
        var weak1 = shared1.makeWeak();
        defer weak1.deinit();
        var weak2 = shared1.makeWeak();
        defer weak2.deinit();
    }
    { // deinit both shared BEFORE 1 weak and AFTER another
        var shared1 = Shared.init(TaggedValue.initInt(10));
        var shared2 = shared1.clone();
        var weak1 = shared1.makeWeak();
        var weak2 = shared1.makeWeak();
        weak1.deinit();
        shared1.deinit();
        shared2.deinit();
        weak2.deinit();
    }
    { // deinit both shared AFTER both weak
        var shared1 = Shared.init(TaggedValue.initInt(10));
        var shared2 = shared1.clone();
        var weak1 = shared1.makeWeak();
        var weak2 = shared1.makeWeak();
        weak1.deinit();
        weak2.deinit();
        shared1.deinit();
        shared2.deinit();
    }
    { // deinit mixed
        var shared1 = Shared.init(TaggedValue.initInt(10));
        var shared2 = shared1.clone();
        var weak1 = shared1.makeWeak();
        var weak2 = shared1.makeWeak();
        shared1.deinit();
        weak1.deinit();
        shared2.deinit();
        weak2.deinit();
    }
    { // deinit mixed sanity
        var shared1 = Shared.init(TaggedValue.initInt(10));
        var shared2 = shared1.clone();
        var weak1 = shared1.makeWeak();
        var weak2 = shared1.makeWeak();
        weak1.deinit();
        shared1.deinit();
        weak2.deinit();
        shared2.deinit();
    }
}

test "thread safe" {
    for (0..10) |_| { // do a few times for pseudo-random scheduling
        var shared1 = Shared.init(TaggedValue.initInt(10));
        var shared2 = shared1.clone();
        var weak1 = shared1.makeWeak();
        var weak2 = shared1.makeWeak();

        const ThreadExecute = struct {
            fn shared(sharedObj: *Shared) void {
                sharedObj.write();
                sharedObj.getUncheckedMut().int += 1;
                sharedObj.unlockWrite();
                sharedObj.deinit();
            }

            fn weak(weakObj: *WeakShared) void {
                weakObj.write();
                if (weakObj.expired()) {
                    weakObj.unlockWrite();
                    weakObj.deinit();
                } else {
                    weakObj.getMut().int += 1;
                    weakObj.unlockWrite();
                    weakObj.deinit();
                }
            }
        };

        const t1 = try std.Thread.spawn(.{}, ThreadExecute.shared, .{&shared1});
        const t2 = try std.Thread.spawn(.{}, ThreadExecute.shared, .{&shared2});
        const t3 = try std.Thread.spawn(.{}, ThreadExecute.weak, .{&weak1});
        const t4 = try std.Thread.spawn(.{}, ThreadExecute.weak, .{&weak2});

        t1.join();
        t2.join();
        t3.join();
        t4.join();
    }
}
