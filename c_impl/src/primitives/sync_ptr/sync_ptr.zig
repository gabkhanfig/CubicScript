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

        pub fn clone(self: *const Self) Self {
            return @bitCast(CubsUnique.cubs_unique_clone(self.asRaw()));
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
    pub extern fn cubs_unique_clone(self: *const Self) callconv(.C) Self;
    //pub extern fn cubs_unique_take(out: *anyopaque, self: *Self) callconv(.C) void;
};

pub fn Shared(comptime T: type) type {
    return extern struct {
        _inner: *anyopaque,
        context: *const TypeContext,

        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .shared;
        pub const ValueType = T;

        pub fn init(value: T) Self {
            var mutValue = value;
            return @bitCast(CubsShared.cubs_shared_init(@ptrCast(&mutValue), TypeContext.auto(T)));
        }

        pub fn deinit(self: *Self) void {
            CubsShared.cubs_shared_deinit(self.asRawMut());
        }

        pub fn lockShared(self: *const Self) void {
            CubsShared.cubs_shared_lock_shared(self.asRaw());
        }

        pub fn tryLockShared(self: *const Self) bool {
            return CubsShared.cubs_shared_try_lock_shared(self.asRaw());
        }

        pub fn unlockShared(self: *const Self) void {
            CubsShared.cubs_shared_unlock_shared(self.asRaw());
        }

        pub fn lockExclusive(self: *Self) void {
            CubsShared.cubs_shared_lock_exclusive(self.asRawMut());
        }

        pub fn tryLockExclusive(self: *Self) bool {
            return CubsShared.cubs_shared_try_lock_exclusive(self.asRawMut());
        }

        pub fn unlockExclusive(self: *Self) void {
            CubsShared.cubs_shared_unlock_exclusive(self.asRawMut());
        }

        pub fn get(self: *const Self) *const T {
            return @ptrCast(@alignCast(CubsShared.cubs_shared_get(self.asRaw())));
        }

        pub fn getMut(self: *Self) *T {
            return @ptrCast(@alignCast(CubsShared.cubs_shared_get_mut(self.asRawMut())));
        }

        pub fn clone(self: *const Self) Self {
            return @bitCast(CubsShared.cubs_shared_clone(self.asRaw()));
        }

        pub fn eql(self: *const Self, other: Self) bool {
            return CubsShared.cubs_shared_eql(self.asRaw(), other.asRaw());
        }

        pub fn asRaw(self: *const Self) *const CubsShared {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsShared {
            return @ptrCast(self);
        }
    };
}

pub const CubsShared = extern struct {
    _inner: *anyopaque,
    context: *const TypeContext,

    const Self = @This();
    pub const SCRIPT_SELF_TAG: ValueTag = .shared;

    pub extern fn cubs_shared_init(value: *anyopaque, context: *const TypeContext) callconv(.C) Self;
    pub extern fn cubs_shared_deinit(self: *Self) callconv(.C) void;
    pub extern fn cubs_shared_lock_shared(self: *const Self) callconv(.C) void;
    pub extern fn cubs_shared_try_lock_shared(self: *const Self) callconv(.C) bool;
    pub extern fn cubs_shared_unlock_shared(self: *const Self) callconv(.C) void;
    pub extern fn cubs_shared_lock_exclusive(self: *Self) callconv(.C) void;
    pub extern fn cubs_shared_try_lock_exclusive(self: *Self) callconv(.C) bool;
    pub extern fn cubs_shared_unlock_exclusive(self: *Self) callconv(.C) void;
    pub extern fn cubs_shared_get(self: *const Self) callconv(.C) *const anyopaque;
    pub extern fn cubs_shared_get_mut(self: *Self) callconv(.C) *anyopaque;
    pub extern fn cubs_shared_clone(self: *const Self) callconv(.C) Self;
    pub extern fn cubs_shared_eql(self: *const Self, other: *const Self) callconv(.C) bool;
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

test "unique clone" {
    var unique = Unique(i64).init(10);
    defer unique.deinit();

    unique.lockExclusive();
    defer unique.unlockExclusive();

    var clone = unique.clone();
    defer clone.deinit();

    try expect(clone.tryLockExclusive()); // should use different locks
    defer clone.unlockExclusive();

    try expect(clone.get().* == unique.get().*); // same value
    try expect(clone.get() != unique.get()); // different address
}

test "shared init" {
    {
        var shared = Shared(i64).init(10);
        defer shared.deinit();

        try expect(shared.get().* == 10);
    }
    {
        var shared = Shared(String).init(String.initUnchecked("wuh"));
        defer shared.deinit();

        try expect(shared.get().eqlSlice("wuh"));
    }
}

test "shared clone" {
    var shared = Shared(i64).init(10);
    defer shared.deinit();

    var clone = shared.clone();
    defer clone.deinit();

    try expect(clone.get().* == shared.get().*); // same value
    try expect(clone.get() == shared.get()); // same address
}

test "shared shared lock" {
    const Validate = struct {
        fn lock(u: *const Shared(i64), value: i64) void {
            for (0..100000) |_| {
                u.lockShared();
                defer u.unlockShared();

                expect(u.get().* == value) catch unreachable;
            }
        }

        fn tryLock(u: *const Shared(i64), value: i64) void {
            for (0..100000) |_| {
                expect(u.tryLockShared()) catch unreachable; // In this test, its readonly, so should always acquire
                defer u.unlockShared();

                expect(u.get().* == value) catch unreachable;
            }
        }
    };

    var shared = Shared(i64).init(10);
    defer shared.deinit();

    const t1 = try Thread.spawn(.{}, Validate.lock, .{ &shared, 10 });
    const t2 = try Thread.spawn(.{}, Validate.tryLock, .{ &shared, 10 });
    const t3 = try Thread.spawn(.{}, Validate.lock, .{ &shared, 10 });
    const t4 = try Thread.spawn(.{}, Validate.tryLock, .{ &shared, 10 });

    t1.join();
    t2.join();
    t3.join();
    t4.join();
}

test "shared exclusive lock only ref" {
    const Validate = struct {
        fn lock(u: *Shared(i64)) void {
            for (0..100000) |_| {
                u.lockExclusive();
                defer u.unlockExclusive();

                u.getMut().* += 1;
            }
        }

        fn tryLock(u: *Shared(i64)) void {
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

    var shared = Shared(i64).init(10);
    defer shared.deinit();

    const t1 = try Thread.spawn(.{}, Validate.lock, .{&shared});
    const t2 = try Thread.spawn(.{}, Validate.tryLock, .{&shared});
    const t3 = try Thread.spawn(.{}, Validate.lock, .{&shared});
    const t4 = try Thread.spawn(.{}, Validate.tryLock, .{&shared});

    t1.join();
    t2.join();
    t3.join();
    t4.join();

    try expect(shared.get().* == 400010);
}

test "shared exclusive lock clones" {
    const Validate = struct {
        fn lock(u: Shared(i64)) void {
            var s = u;
            for (0..100000) |_| {
                s.lockExclusive();
                defer s.unlockExclusive();

                s.getMut().* += 1;
            }
            s.deinit();
        }

        fn tryLock(u: Shared(i64)) void {
            var s = u;
            for (0..100000) |_| {
                while (true) {
                    if (!s.tryLockExclusive()) { // keep trying until success
                        Thread.yield() catch unreachable;
                        continue;
                    }
                    defer s.unlockExclusive();
                    s.getMut().* += 1;
                    break;
                }
            }
            s.deinit();
        }
    };

    var shared = Shared(i64).init(10);
    defer shared.deinit();

    const t1 = try Thread.spawn(.{}, Validate.lock, .{shared.clone()});
    const t2 = try Thread.spawn(.{}, Validate.tryLock, .{shared.clone()});
    const t3 = try Thread.spawn(.{}, Validate.lock, .{shared.clone()});
    const t4 = try Thread.spawn(.{}, Validate.tryLock, .{shared.clone()});

    t1.join();
    t2.join();
    t3.join();
    t4.join();

    try expect(shared.get().* == 400010);
}

test "shared eql" {
    { // clones equal
        var shared = Shared(i64).init(10);
        defer shared.deinit();

        var clone = shared.clone();
        defer clone.deinit();

        try expect(shared.eql(clone));
    }
    { // different pointers, different value, not equal
        var s1 = Shared(i64).init(10);
        defer s1.deinit();

        var s2 = Shared(i64).init(11);
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // different pointers, same value, not equal
        var s1 = Shared(i64).init(10);
        defer s1.deinit();

        var s2 = Shared(i64).init(10);
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
}
