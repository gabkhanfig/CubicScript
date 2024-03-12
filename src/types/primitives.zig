//! Primitive types for script

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

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
