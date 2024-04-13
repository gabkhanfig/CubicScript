const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const TaggedValue = root.TaggedValue;
const AtomicRefCount = @import("atomic_ref_count.zig").AtomicRefCount;
const RwLock = @import("RwLock.zig");
const allocator = @import("../state/global_allocator.zig").allocator;
const sync_queue = @import("../state/sync_queue.zig");

pub const Shared = extern struct {
    const Self = @This();
    const ELEMENT_ALIGN = 8;
    const PTR_BITMASK = 0xFFFFFFFFFFFF;
    const TAG_BITMASK: usize = ~@as(usize, PTR_BITMASK);

    inner: *anyopaque,

    pub fn init(value: TaggedValue) Self {
        const tagInt: usize = @shlExact(value.tag.asUsize(), 48);
        const newInner = allocator().create(Inner) catch {
            @panic("Script out of memory");
        };
        newInner.* = .{ .value = value.value };
        return Self{ .inner = @ptrFromInt(tagInt | @intFromPtr(newInner)) };
    }

    pub fn clone(self: *const Self) Self {
        const refCount: *AtomicRefCount = @constCast(&self.asInner().refCount);
        refCount.addRef();
        return Self{ .inner = self.inner };
    }

    pub fn deinit(self: *Self) void {
        const valueTag = self.tag();
        const inner = self.asInnerMut();
        self.inner = undefined;
        if (inner.refCount.removeRef()) {
            inner.value.deinit(valueTag);
            allocator().destroy(inner);
        }
    }

    pub fn tag(self: *const Self) ValueTag {
        return @enumFromInt(@shrExact(@intFromPtr(self.inner) & TAG_BITMASK, 48));
    }

    pub fn write(self: *Self) callconv(.C) void {
        self.asInnerMut().lock.write();
    }

    pub fn tryWrite(self: *Self) callconv(.C) bool {
        return self.asInnerMut().lock.tryWrite();
    }

    pub fn unlockWrite(self: *Self) callconv(.C) void {
        self.asInnerMut().lock.unlockWrite();
    }

    pub fn read(self: *const Self) callconv(.C) void {
        self.asInner().lock.read();
    }

    pub fn tryRead(self: *const Self) callconv(.C) bool {
        return self.asInner().lock.tryRead();
    }

    pub fn unlockRead(self: *const Self) callconv(.C) void {
        self.asInner().lock.unlockRead();
    }

    pub fn getUnchecked(self: *const Self) *const RawValue {
        return &self.asInner().value;
    }

    pub fn getUncheckedMut(self: *Self) *RawValue {
        return &self.asInnerMut().value;
    }

    fn asInner(self: *const Self) *const Inner {
        const num: usize = @intFromPtr(self.inner);
        const ptr: *anyopaque = @ptrFromInt(num & PTR_BITMASK);
        return @ptrCast(@alignCast(ptr));
    }

    fn asInnerMut(self: *Self) *Inner {
        const num: usize = @intFromPtr(self.inner);
        const ptr: *anyopaque = @ptrFromInt(num & PTR_BITMASK);
        return @ptrCast(@alignCast(ptr));
    }
};

const Inner = struct {
    refCount: AtomicRefCount = .{ .count = std.atomic.Value(usize).init(1) },
    lock: RwLock = .{},
    value: RawValue,
};

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
