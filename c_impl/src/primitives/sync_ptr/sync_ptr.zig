const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const String = script_value.String;
const TypeContext = script_value.TypeContext;

pub fn Unique(comptime T: type) type {
    return extern struct {
        _inner: *anyopaque,
        context: *const TypeContext,

        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .unique;
        pub const ValueType = T;

        pub fn init(value: T) Self {
            var mutValue = value;
            return @bitCast(CubsUnique.cubs_unique_init_user_class(@ptrCast(&mutValue), TypeContext.auto(T)));
        }

        pub fn deinit(self: *Self) void {
            CubsUnique.cubs_unique_deinit(self.asRawMut());
        }

        pub fn lockShared(self: *const Self) void {
            CubsUnique.cubs_unique_lock_shared(self.asRaw());
        }

        pub fn tryLockShared(self: *const Self) bool {
            return CubsUnique.cubs_unique_try_lock_shared(self.asRaw());
        }

        pub fn unlockShared(self: *const Self) void {
            CubsUnique.cubs_unique_unlock_shared(self.asRaw());
        }

        pub fn lockExclusive(self: *Self) void {
            CubsUnique.cubs_unique_lock_exclusive(self.asRawMut());
        }

        pub fn tryLockExclusive(self: *Self) bool {
            return CubsUnique.cubs_unique_try_lock_exclusive(self.asRawMut());
        }

        pub fn unlockExclusive(self: *Self) void {
            CubsUnique.cubs_unique_unlock_exclusive(self.asRawMut());
        }

        pub fn get(self: *const Self) *const T {
            return @ptrCast(@alignCast(CubsUnique.cubs_unique_get(self.asRaw())));
        }

        pub fn getMut(self: *Self) *T {
            return @ptrCast(@alignCast(CubsUnique.cubs_unique_get_mut(self.asRawMut())));
        }

        pub fn asRaw(self: *const Self) *const CubsUnique {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsUnique {
            return @ptrCast(self);
        }
    };
}

pub const CubsUnique = extern struct {
    _inner: *anyopaque,
    context: *const TypeContext,

    const Self = @This();
    pub const SCRIPT_SELF_TAG: ValueTag = .unique;

    pub extern fn cubs_unique_init_user_class(value: *anyopaque, context: *const TypeContext) callconv(.C) Self;
    pub extern fn cubs_unique_deinit(self: *Self) callconv(.C) void;
    pub extern fn cubs_unique_lock_shared(self: *const Self) callconv(.C) void;
    pub extern fn cubs_unique_try_lock_shared(self: *const Self) callconv(.C) bool;
    pub extern fn cubs_unique_unlock_shared(self: *const Self) callconv(.C) void;
    pub extern fn cubs_unique_lock_exclusive(self: *Self) callconv(.C) void;
    pub extern fn cubs_unique_try_lock_exclusive(self: *Self) callconv(.C) bool;
    pub extern fn cubs_unique_unlock_exclusive(self: *Self) callconv(.C) void;
    pub extern fn cubs_unique_get(self: *const Self) callconv(.C) *const anyopaque;
    pub extern fn cubs_unique_get_mut(self: *Self) callconv(.C) *anyopaque;
    //pub extern fn cubs_unique_take(out: *anyopaque, self: *Self) callconv(.C) void;
};

test "unique init" {
    {
        var unique = Unique(i64).init(10);
        defer unique.deinit();

        try expect(unique.get().* == 10);
    }
    {
        var unique = Unique(String).init(String.initUnchecked("wuh"));
        defer unique.deinit();

        try expect(unique.get().eqlSlice("wuh"));
    }
}

const Thread = std.Thread;

test "unique shared lock" {
    const Validate = struct {
        fn lock(u: *const Unique(i64), value: i64) void {
            for (0..100000) |_| {
                u.lockShared();
                defer u.unlockShared();

                expect(u.get().* == value) catch unreachable;
            }
        }

        fn tryLock(u: *const Unique(i64), value: i64) void {
            for (0..100000) |_| {
                expect(u.tryLockShared()) catch unreachable; // In this test, its readonly, so should always acquire
                defer u.unlockShared();

                expect(u.get().* == value) catch unreachable;
            }
        }
    };

    var unique = Unique(i64).init(10);
    defer unique.deinit();

    const t1 = try Thread.spawn(.{}, Validate.lock, .{ &unique, 10 });
    const t2 = try Thread.spawn(.{}, Validate.tryLock, .{ &unique, 10 });
    const t3 = try Thread.spawn(.{}, Validate.lock, .{ &unique, 10 });
    const t4 = try Thread.spawn(.{}, Validate.tryLock, .{ &unique, 10 });

    t1.join();
    t2.join();
    t3.join();
    t4.join();
}

test "unique exclusive lock" {
    const Validate = struct {
        fn lock(u: *Unique(i64)) void {
            for (0..100000) |_| {
                u.lockExclusive();
                defer u.unlockExclusive();

                u.getMut().* += 1;
            }
        }

        fn tryLock(u: *Unique(i64)) void {
            for (0..100000) |_| {
                while (true) {
                    if (!u.tryLockExclusive()) { // keep trying until success
                        Thread.yield() catch unreachable;
                        continue;
                    }
                    defer u.unlockExclusive();
                    u.getMut().* += 1;
                    break;
                }
            }
        }
    };

    var unique = Unique(i64).init(10);
    defer unique.deinit();

    const t1 = try Thread.spawn(.{}, Validate.lock, .{&unique});
    const t2 = try Thread.spawn(.{}, Validate.tryLock, .{&unique});
    const t3 = try Thread.spawn(.{}, Validate.lock, .{&unique});
    const t4 = try Thread.spawn(.{}, Validate.tryLock, .{&unique});

    t1.join();
    t2.join();
    t3.join();
    t4.join();

    try expect(unique.get().* == 400010);
}
