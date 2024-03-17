const std = @import("std");
const expect = std.testing.expect;
const primitives = @import("primitives.zig");
const ValueTag = primitives.ValueTag;
const Value = primitives.Value;

pub const TEST_SEED_VALUE = 0x4857372859619FA;

pub fn computeHash(value: *const Value, tag: ValueTag, seed: usize) usize {
    var hashCombine: usize = seed;
    switch (tag) {
        .Bool, .Float, .Int => { // simply cast to a usize ptr, and dereference. Maybe change this behaviour for ints?
            combineHash(&hashCombine, @as(*const usize, @ptrCast(value)).*);
        },
        .String => {
            combineHash(&hashCombine, value.string.hash());
        },
        .Array => {
            const slice = value.array.asSlice();
            for (slice) |val| {
                combineHash(&hashCombine, computeHash(&val, value.array.tag(), seed));
            }
        },
        else => {
            @panic("unsupported type");
        },
    }
    return hashCombine;
}

pub fn combineHash(lhs: *usize, rhs: usize) void {
    comptime {
        if (@sizeOf(usize) != 8) {
            @compileError("expected usize to be 8 bytes in size");
        }
    }
    // c++ boost hash combine for 64 bit
    lhs.* ^= @addWithOverflow(
        @addWithOverflow(@addWithOverflow(rhs, 0x517cc1b727220a95).@"0", @shlExact(lhs.* & ~@as(usize, 0xFC00000000000000), 6)).@"0",
        @shrExact(lhs.* & ~@as(usize, 0b11), 2),
    ).@"0";
}

pub const HashGroupBitmask = struct {
    const BITMASK = 18446744073709551488; // ~0b1111111 as usize

    value: usize,

    pub fn init(hashCode: usize) HashGroupBitmask {
        return HashGroupBitmask{ .value = @shrExact(hashCode & BITMASK, 7) };
    }
};

pub const HashPairBitmask = struct {
    const BITMASK = 127; // 0b1111111
    const SET_FLAG = 0b10000000;

    value: u8,

    pub fn init(hashCode: usize) HashPairBitmask {
        return HashPairBitmask{ .value = @intCast((hashCode & BITMASK) | SET_FLAG) };
    }
};

test "hash bool" {
    {
        const value1 = Value{ .boolean = primitives.TRUE };
        const value2 = Value{ .boolean = primitives.TRUE };

        const h1 = computeHash(&value1, ValueTag.Bool, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Bool, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = Value{ .boolean = primitives.FALSE };
        const value2 = Value{ .boolean = primitives.FALSE };

        const h1 = computeHash(&value1, ValueTag.Bool, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Bool, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = Value{ .boolean = primitives.FALSE };
        const value2 = Value{ .boolean = primitives.TRUE };

        const h1 = computeHash(&value1, ValueTag.Bool, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Bool, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}

test "hash int" {
    {
        const value1 = Value{ .int = 100 };
        const value2 = Value{ .int = 100 };

        const h1 = computeHash(&value1, ValueTag.Int, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Int, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = Value{ .int = 101 };
        const value2 = Value{ .int = 101 };

        const h1 = computeHash(&value1, ValueTag.Int, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Int, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = Value{ .int = 100 };
        const value2 = Value{ .int = 101 };

        const h1 = computeHash(&value1, ValueTag.Int, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Int, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}

test "hash float" {
    {
        const value1 = Value{ .float = 999.51 };
        const value2 = Value{ .float = 999.51 };

        const h1 = computeHash(&value1, ValueTag.Float, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Float, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = Value{ .float = 1000.51 };
        const value2 = Value{ .float = 1000.51 };

        const h1 = computeHash(&value1, ValueTag.Float, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Float, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = Value{ .float = 999.51 };
        const value2 = Value{ .float = 1000.51 };

        const h1 = computeHash(&value1, ValueTag.Float, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Float, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}

test "hash string" {
    const allocator = std.testing.allocator;
    {
        const value1 = Value{ .string = primitives.String{} };
        const value2 = Value{ .string = primitives.String{} };

        const h1 = computeHash(&value1, ValueTag.String, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.String, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        var value1 = Value{ .string = try primitives.String.initSlice("hello world!", allocator) };
        defer value1.string.deinit(allocator);
        var value2 = Value{ .string = try primitives.String.initSlice("hello world!", allocator) };
        defer value2.string.deinit(allocator);

        const h1 = computeHash(&value1, ValueTag.String, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.String, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        var value1 = Value{ .string = try primitives.String.initSlice("hello to this truly wonderful and amazing world holy moly canoly!", allocator) };
        defer value1.string.deinit(allocator);
        var value2 = Value{ .string = try primitives.String.initSlice("hello to this truly wonderful and amazing world holy moly canoly!", allocator) };
        defer value2.string.deinit(allocator);

        const h1 = computeHash(&value1, ValueTag.String, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.String, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        var value1 = Value{ .string = try primitives.String.initSlice("hello to this truly wonderful and amazing world holy moly canoly !", allocator) };
        defer value1.string.deinit(allocator);
        var value2 = Value{ .string = try primitives.String.initSlice("hello to this truly wonderful and amazing world holy moly canoly!", allocator) };
        defer value2.string.deinit(allocator);

        const h1 = computeHash(&value1, ValueTag.String, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.String, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}

test "hash array" {
    const makeArraysForTest = struct {
        fn makeArray1(a: std.mem.Allocator) Value {
            var array = primitives.Array.init(ValueTag.Float);
            var pushValue1 = primitives.Value{ .float = -1.0 };
            var pushValue2 = primitives.Value{ .float = 1005.6 };

            array.add(&pushValue1, ValueTag.Float, a) catch unreachable;
            array.add(&pushValue2, ValueTag.Float, a) catch unreachable;
            return Value{ .array = array };
        }

        fn makeArray2(a: std.mem.Allocator) Value {
            var array = primitives.Array.init(ValueTag.Float);
            var pushValue1 = primitives.Value{ .float = -1.0 };
            var pushValue2 = primitives.Value{ .float = 1005.6 };
            var pushValue3 = primitives.Value{ .float = 0 };

            array.add(&pushValue1, ValueTag.Float, a) catch unreachable;
            array.add(&pushValue2, ValueTag.Float, a) catch unreachable;
            array.add(&pushValue3, ValueTag.Float, a) catch unreachable;
            return Value{ .array = array };
        }
    };

    const allocator = std.testing.allocator;
    var arrEmpty1 = Value{ .array = primitives.Array.init(ValueTag.Float) };
    defer arrEmpty1.array.deinit(allocator);
    var arrEmpty2 = Value{ .array = primitives.Array.init(ValueTag.Float) };
    defer arrEmpty1.array.deinit(allocator);
    var arrContains1: Value = makeArraysForTest.makeArray1(allocator);
    defer arrContains1.array.deinit(allocator);
    var arrContains2: Value = makeArraysForTest.makeArray1(allocator);
    defer arrContains2.array.deinit(allocator);
    var arrContains3: Value = makeArraysForTest.makeArray2(allocator);
    defer arrContains3.array.deinit(allocator);
    var arrContains4: Value = makeArraysForTest.makeArray2(allocator);
    defer arrContains4.array.deinit(allocator);

    {
        const h1 = computeHash(&arrEmpty1, ValueTag.Array, TEST_SEED_VALUE);
        const h2 = computeHash(&arrEmpty2, ValueTag.Array, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const h1 = computeHash(&arrContains1, ValueTag.Array, TEST_SEED_VALUE);
        const h2 = computeHash(&arrContains2, ValueTag.Array, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const h1 = computeHash(&arrContains3, ValueTag.Array, TEST_SEED_VALUE);
        const h2 = computeHash(&arrContains4, ValueTag.Array, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const h1 = computeHash(&arrEmpty1, ValueTag.Array, TEST_SEED_VALUE);
        const h2 = computeHash(&arrContains1, ValueTag.Array, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
    {
        const h1 = computeHash(&arrEmpty1, ValueTag.Array, TEST_SEED_VALUE);
        const h2 = computeHash(&arrContains3, ValueTag.Array, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
    {
        const h1 = computeHash(&arrContains1, ValueTag.Array, TEST_SEED_VALUE);
        const h2 = computeHash(&arrContains3, ValueTag.Array, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}
