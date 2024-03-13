//! Primitive types for script

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

/// true = not 0, false = 0
pub const Bool = i64;
/// Signed 64 bit integer
pub const Int = i64;
/// 64 bit float
pub const Float = f64;

/// Immutable, ref counted string.
pub const String = extern struct {
    const Self = @This();

    /// If null, is just an empty string. This makes 0 initization viable.
    /// TODO does this need to be atomic? It's possible one thread reads while another deinits on the same String reference (not inner reference)?
    inner: ?*anyopaque = null,

    pub fn initSlice(slice: [:0]const u8, allocator: Allocator) Allocator.Error!Self {
        assert(slice.len != 0);

        const inner = try Inner.initSlice(slice, allocator);
        return Self{ .inner = @ptrCast(inner) };
    }

    pub fn clone(self: Self) Self {
        if (self.inner == null) {
            return Self{ .inner = null };
        } else {
            var selfCopy = self; // should be optimized by LLVM
            selfCopy.asInnerMut().incrementRefCount();
            return Self{ .inner = self.inner };
        }
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.inner != null) {
            const inner = self.asInnerMut(); // Use this ordering in the event of weird synchronization issues.
            self.inner = null;
            inner.decrementRefCount(allocator);
        }
    }

    pub fn len(self: *const Self) Int {
        if (self.inner == null) {
            return 0;
        } else {
            return @intCast(self.asInner().lenAndFlag & ~Inner.FLAG_BIT);
        }
    }

    pub fn toSlice(self: *const Self) [:0]const u8 {
        if (self.inner == null) {
            return "";
        } else {
            const length = self.asInner().lenAndFlag & ~Inner.FLAG_BIT;
            if (self.asInner().isSso()) {
                return self.asInner().rep.sso.chars[0..length :0];
            } else {
                return self.asInner().rep.heap.data[0..length :0];
            }
        }
    }

    fn asInner(self: Self) *const Inner {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asInnerMut(self: *Self) *Inner {
        return @ptrCast(@alignCast(self.inner));
    }

    const Inner = extern struct {
        const FLAG_BIT: usize = @shlExact(1, 63);

        refCount: AtomicRefCount = AtomicRefCount{},
        lenAndFlag: usize,
        rep: StringRep = undefined,

        fn incrementRefCount(self: *Inner) void {
            self.refCount.addRef();
        }

        fn decrementRefCount(self: *Inner, allocator: Allocator) void {
            if (!self.refCount.removeRef()) {
                return;
            }

            if (!self.isSso()) {
                allocator.free(self.rep.heap.data[0..(self.rep.heap.allocationSize - 1) :0]);
                self.rep.heap.data = undefined;
                self.rep.heap.allocationSize = 0;
            }
            allocator.destroy(self);
        }

        fn isSso(self: *const Inner) bool {
            return self.lenAndFlag & FLAG_BIT == 0;
        }

        fn initSlice(slice: [:0]const u8, allocator: Allocator) Allocator.Error!*Inner {
            const self = try allocator.create(Inner);

            self.* = Inner{ .lenAndFlag = slice.len };
            self.refCount.addRef();
            try self.ensureTotalCapacity(allocator, slice.len + 1);

            if (self.isSso()) {
                for (0..slice.len) |i| {
                    self.rep.sso.chars[i] = slice[i];
                }
            } else {
                for (0..slice.len) |i| {
                    self.rep.heap.data[i] = slice[i];
                }
            }
            return self;
        }

        /// Can only be executed once per instance.
        fn ensureTotalCapacity(self: *Inner, allocator: Allocator, minCapacity: usize) Allocator.Error!void {
            // The strings are immutable, so cannot override.
            // This check ensures long strings don't get overridden, which can be caught by tests.
            //assert(!self.isSso());

            if (minCapacity < SsoRep.MAX_LEN) {
                self.rep = StringRep.default();
                return;
            }

            var mallocCapacity = minCapacity;
            const remainder = @mod(mallocCapacity, 64);
            if (remainder != 0) {
                mallocCapacity = mallocCapacity + (64 - remainder);
            }
            const newSlice: []align(64) u8 = try allocator.alignedAlloc(u8, 64, mallocCapacity);
            @memset(newSlice, 0);
            self.rep.heap.data = @ptrCast(newSlice.ptr);
            self.rep.heap.allocationSize = mallocCapacity;
            self.lenAndFlag |= FLAG_BIT;
            assert(!self.isSso());
        }

        const StringRep = extern union {
            sso: SsoRep,
            heap: HeapRep,

            fn default() StringRep {
                return StringRep{ .sso = SsoRep{} };
            }
        };

        const SsoRep = extern struct {
            const MAX_LEN = 15;

            chars: [16:0]u8 = std.mem.zeroes([16:0]u8),
        };

        const HeapRep = extern struct {
            data: [*:0]align(64) u8,
            allocationSize: usize,
        };
    };
};

const AtomicOrder = std.builtin.AtomicOrder;

const AtomicRefCount = extern struct {
    const Self = @This();

    count: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    pub fn addRef(self: *Self) void {
        const old = self.count.fetchAdd(1, AtomicOrder.Release);
        assert(old != std.math.maxInt(usize));
    }

    /// Returns true if the ref count is 0, and there are no more references.
    pub fn removeRef(self: *Self) bool {
        const old = self.count.fetchSub(1, AtomicOrder.Release);
        assert(old != 0);
        return old == 1;
    }
};

// Tests

test "atomic ref count" {
    {
        var c = AtomicRefCount{};
        c.addRef();
        try expect(c.removeRef());
    }
    {
        var c = AtomicRefCount{};
        c.addRef();
        c.addRef();
        try expect(!c.removeRef());
        try expect(c.removeRef());
    }
    {
        const TestThreadHandler = struct {
            fn incrementRefCountNTimes(ref: *AtomicRefCount, n: usize) void {
                for (0..n) |_| {
                    ref.addRef();
                }
            }

            fn decrementRefCountNTimes(ref: *AtomicRefCount, n: usize) void {
                for (0..n) |_| {
                    _ = ref.removeRef();
                }
            }
        };

        var c = AtomicRefCount{};
        {
            const t1 = try std.Thread.spawn(.{}, TestThreadHandler.incrementRefCountNTimes, .{ &c, 10000 });
            const t2 = try std.Thread.spawn(.{}, TestThreadHandler.incrementRefCountNTimes, .{ &c, 10000 });
            const t3 = try std.Thread.spawn(.{}, TestThreadHandler.incrementRefCountNTimes, .{ &c, 10000 });
            const t4 = try std.Thread.spawn(.{}, TestThreadHandler.incrementRefCountNTimes, .{ &c, 10000 });

            t1.join();
            t2.join();
            t3.join();
            t4.join();
        }

        try expect(c.count.load(AtomicOrder.Acquire) == 40000);

        {
            const t1 = try std.Thread.spawn(.{}, TestThreadHandler.incrementRefCountNTimes, .{ &c, 10000 });
            const t2 = try std.Thread.spawn(.{}, TestThreadHandler.decrementRefCountNTimes, .{ &c, 10000 });
            const t3 = try std.Thread.spawn(.{}, TestThreadHandler.incrementRefCountNTimes, .{ &c, 10000 });
            const t4 = try std.Thread.spawn(.{}, TestThreadHandler.decrementRefCountNTimes, .{ &c, 10000 });

            t1.join();
            t2.join();
            t3.join();
            t4.join();
        }

        try expect(c.count.load(AtomicOrder.Acquire) == 40000);

        {
            const t1 = try std.Thread.spawn(.{}, TestThreadHandler.decrementRefCountNTimes, .{ &c, 10000 });
            const t2 = try std.Thread.spawn(.{}, TestThreadHandler.decrementRefCountNTimes, .{ &c, 10000 });
            const t3 = try std.Thread.spawn(.{}, TestThreadHandler.decrementRefCountNTimes, .{ &c, 10000 });
            const t4 = try std.Thread.spawn(.{}, TestThreadHandler.decrementRefCountNTimes, .{ &c, 10000 });

            t1.join();
            t2.join();
            t3.join();
            t4.join();
        }

        try expect(c.count.load(AtomicOrder.Acquire) == 0);
    }
}

test "String default init" {
    const s = String{};
    try expect(s.len() == 0);
    try expect(std.mem.eql(u8, s.toSlice(), ""));
}

test "String from slice" {
    const allocator = std.testing.allocator;
    {
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.len() == 12);
        try expect(std.mem.eql(u8, s.toSlice(), "hello world!"));
    }
    {
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.len() == 29);
        try expect(std.mem.eql(u8, s.toSlice(), "hello to this glorious world!"));
    }
}

test "String clone" {
    const allocator = std.testing.allocator;
    {
        var s1 = try String.initSlice("hello world!", allocator);
        defer s1.deinit(allocator);

        var s2 = s1.clone();
        defer s2.deinit(allocator);

        try expect(s1.inner == s2.inner);
        try expect(std.mem.eql(u8, s1.toSlice(), "hello world!"));
        try expect(std.mem.eql(u8, s2.toSlice(), "hello world!"));
    }
    {
        var s1 = try String.initSlice("hello to this glorious world!", allocator);
        defer s1.deinit(allocator);

        var s2 = s1.clone();
        defer s2.deinit(allocator);

        try expect(s1.inner == s2.inner);
        try expect(std.mem.eql(u8, s1.toSlice(), "hello to this glorious world!"));
        try expect(std.mem.eql(u8, s2.toSlice(), "hello to this glorious world!"));
    }
}

test "String clone thread safety" {
    const allocator = std.testing.allocator;

    const TestThreadHandler = struct {
        fn makeClonesNTimes(ref: *String, n: usize, a: Allocator) void {
            for (0..n) |_| {
                var s1 = ref.clone();
                defer s1.deinit(a);
                var s2 = ref.clone();
                defer s2.deinit(a);
                var s3 = ref.clone();
                defer s3.deinit(a);
                var s4 = ref.clone();
                defer s4.deinit(a);
            }
        }
    };

    {
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        const t1 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t2 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t3 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t4 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });

        t1.join();
        t2.join();
        t3.join();
        t4.join();
    }
    {
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        const t1 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t2 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t3 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t4 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });

        t1.join();
        t2.join();
        t3.join();
        t4.join();
    }
}
