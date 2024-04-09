const std = @import("std");
const expect = std.testing.expect;
const root = @import("../root.zig");
const ValueTag = root.ValueTag;
const RawValue = root.RawValue;
const CubicScriptState = @import("../state/CubicScriptState.zig");
const allocator = @import("../state/global_allocator.zig").allocator;

pub const TEST_SEED_VALUE = 0x4857372859619FA;

pub fn computeHash(value: *const RawValue, tag: ValueTag, seed: usize) usize {
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
        const value1 = RawValue{ .boolean = true };
        const value2 = RawValue{ .boolean = true };

        const h1 = computeHash(&value1, ValueTag.Bool, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Bool, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = RawValue{ .boolean = false };
        const value2 = RawValue{ .boolean = false };

        const h1 = computeHash(&value1, ValueTag.Bool, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Bool, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = RawValue{ .boolean = false };
        const value2 = RawValue{ .boolean = true };

        const h1 = computeHash(&value1, ValueTag.Bool, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Bool, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}

test "hash int" {
    {
        const value1 = RawValue{ .int = 100 };
        const value2 = RawValue{ .int = 100 };

        const h1 = computeHash(&value1, ValueTag.Int, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Int, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = RawValue{ .int = 101 };
        const value2 = RawValue{ .int = 101 };

        const h1 = computeHash(&value1, ValueTag.Int, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Int, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = RawValue{ .int = 100 };
        const value2 = RawValue{ .int = 101 };

        const h1 = computeHash(&value1, ValueTag.Int, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Int, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}

test "hash float" {
    {
        const value1 = RawValue{ .float = 999.51 };
        const value2 = RawValue{ .float = 999.51 };

        const h1 = computeHash(&value1, ValueTag.Float, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Float, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = RawValue{ .float = 1000.51 };
        const value2 = RawValue{ .float = 1000.51 };

        const h1 = computeHash(&value1, ValueTag.Float, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Float, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        const value1 = RawValue{ .float = 999.51 };
        const value2 = RawValue{ .float = 1000.51 };

        const h1 = computeHash(&value1, ValueTag.Float, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.Float, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}

test "hash string" {
    var state = try CubicScriptState.init(std.testing.allocator, null);
    defer state.deinit();
    {
        const value1 = RawValue{ .string = root.String{} };
        const value2 = RawValue{ .string = root.String{} };

        const h1 = computeHash(&value1, ValueTag.String, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.String, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        var value1 = RawValue{ .string = root.String.initSlice("hello world!") };
        defer value1.string.deinit();
        var value2 = RawValue{ .string = root.String.initSlice("hello world!") };
        defer value2.string.deinit();

        const h1 = computeHash(&value1, ValueTag.String, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.String, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        var value1 = RawValue{ .string = root.String.initSlice("hello to this truly wonderful and amazing world holy moly canoly!") };
        defer value1.string.deinit();
        var value2 = RawValue{ .string = root.String.initSlice("hello to this truly wonderful and amazing world holy moly canoly!") };
        defer value2.string.deinit();

        const h1 = computeHash(&value1, ValueTag.String, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.String, TEST_SEED_VALUE);

        try expect(h1 == h2);
    }
    {
        var value1 = RawValue{ .string = root.String.initSlice("hello to this truly wonderful and amazing world holy moly canoly !") };
        defer value1.string.deinit();
        var value2 = RawValue{ .string = root.String.initSlice("hello to this truly wonderful and amazing world holy moly canoly!") };
        defer value2.string.deinit();

        const h1 = computeHash(&value1, ValueTag.String, TEST_SEED_VALUE);
        const h2 = computeHash(&value2, ValueTag.String, TEST_SEED_VALUE);

        try expect(h1 != h2);
    }
}

test "hash array" {
    var state = try CubicScriptState.init(std.testing.allocator, null);
    defer state.deinit();

    const makeArraysForTest = struct {
        fn makeArray1(s: *const CubicScriptState) RawValue {
            var array = root.Array.init(ValueTag.Float);
            var pushValue1 = root.RawValue{ .float = -1.0 };
            var pushValue2 = root.RawValue{ .float = 1005.6 };

            array.add(&pushValue1, ValueTag.Float, s) catch unreachable;
            array.add(&pushValue2, ValueTag.Float, s) catch unreachable;
            return RawValue{ .array = array };
        }

        fn makeArray2(s: *const CubicScriptState) RawValue {
            var array = root.Array.init(ValueTag.Float);
            var pushValue1 = root.RawValue{ .float = -1.0 };
            var pushValue2 = root.RawValue{ .float = 1005.6 };
            var pushValue3 = root.RawValue{ .float = 0 };

            array.add(&pushValue1, ValueTag.Float, s) catch unreachable;
            array.add(&pushValue2, ValueTag.Float, s) catch unreachable;
            array.add(&pushValue3, ValueTag.Float, s) catch unreachable;
            return RawValue{ .array = array };
        }
    };

    var arrEmpty1 = RawValue{ .array = root.Array.init(ValueTag.Float) };
    defer arrEmpty1.array.deinit(state);
    var arrEmpty2 = RawValue{ .array = root.Array.init(ValueTag.Float) };
    defer arrEmpty1.array.deinit(state);
    var arrContains1 = makeArraysForTest.makeArray1(state);
    defer arrContains1.array.deinit(state);
    var arrContains2 = makeArraysForTest.makeArray1(state);
    defer arrContains2.array.deinit(state);
    var arrContains3 = makeArraysForTest.makeArray2(state);
    defer arrContains3.array.deinit(state);
    var arrContains4 = makeArraysForTest.makeArray2(state);
    defer arrContains4.array.deinit(state);

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
