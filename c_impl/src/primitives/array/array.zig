const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;
const StructContext = script_value.StructContext;

pub fn Array(comptime T: type) type {
    return extern struct {
        const Self = @This();
        /// Helper to generically determine the script value type of `Self`, for example, since this is an `Array`,
        /// it returns `.array`. This is implemented for all script value that are generic.
        pub const SCRIPT_SELF_TAG: ValueTag = .array;
        pub const ValueType = T;

        len: usize = 0,
        buf: ?*T = null,
        capacity: usize = 0,
        context: *const StructContext,

        pub const Error = error{
            OutOfRange,
        };

        /// For all primitive script types, creates the array.
        /// For user defined types, attemps to generate one.
        /// Alternatively, one can be passed in manually through creating a struct instance. For example
        /// ```
        /// const arr = Array(UserStruct){.context = ...};
        /// ```
        pub fn init() Self {
            const valueTag = comptime script_value.scriptTypeToTag(T);
            if (valueTag != .userStruct) {
                const raw = RawArray.cubs_array_init_primitive(valueTag);
                return @bitCast(raw);
            } else {
                const raw = RawArray.cubs_array_init_user_struct(StructContext.auto(T));
                return raw;
            }
        }

        pub fn deinit(self: *Self) void {
            return RawArray.cubs_array_deinit(self.asRawMut());
        }

        pub fn clone(self: *const Self) Self {
            return @bitCast(RawArray.cubs_array_clone(self.asRaw()));
        }

        /// Takes ownership of `value`. Accessing the memory of `value` after this
        /// function is undefined behaviour.
        pub fn push(self: *Self, value: T) void {
            var mutValue = value;
            RawArray.cubs_array_push_unchecked(self.asRawMut(), @ptrCast(&mutValue));
        }

        pub fn slice(self: *const Self) []const T {
            if (self.buf) |buf| {
                return @as([*]const T, @ptrCast(buf))[0..self.len];
            } else {
                return {};
            }
        }

        pub fn sliceMut(self: *Self) []T {
            if (self.buf) |buf| {
                return @as([*]T, @ptrCast(buf))[0..self.len];
            } else {
                return {};
            }
        }

        pub fn atUnchecked(self: *const Self, index: usize) *const T {
            return @ptrCast(@alignCast(RawArray.cubs_array_at_unchecked(self.asRaw(), index)));
        }

        pub fn at(self: *const Self, index: usize) Error!*const T {
            var out: *const anyopaque = undefined;
            switch (RawArray.cubs_array_at(&out, self.asRaw(), index)) {
                .None => {
                    return @ptrCast(@alignCast(out));
                },
                .OutOfRange => {
                    return Error.OutOfRange;
                },
            }
        }

        pub fn atMutUnchecked(self: *Self, index: usize) *T {
            return @ptrCast(@alignCast(RawArray.cubs_array_at_mut_unchecked(self.asRawMut(), index)));
        }

        pub fn atMut(self: *Self, index: usize) Error!*T {
            var out: *anyopaque = undefined;
            switch (RawArray.cubs_array_at_mut(&out, self.asRawMut(), index)) {
                .None => {
                    return @ptrCast(@alignCast(out));
                },
                .OutOfRange => {
                    return Error.OutOfRange;
                },
            }
        }

        pub fn asRaw(self: *const Self) *const RawArray {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *RawArray {
            return @ptrCast(self);
        }
    };
}

pub const RawArray = extern struct {
    len: usize,
    buf: ?*anyopaque,
    capacity: usize,
    context: *const StructContext,

    pub const Err = enum(c_int) {
        None = 0,
        OutOfRange = 1,
    };

    pub const CUBS_ARRAY_N_POS: usize = @bitCast(@as(i64, -1));
    pub const SCRIPT_SELF_TAG: ValueTag = .array;

    pub extern fn cubs_array_init_primitive(tag: ValueTag) callconv(.C) RawArray;
    pub extern fn cubs_array_init_user_struct(rtti: *const StructContext) callconv(.C) RawArray;
    pub extern fn cubs_array_deinit(self: *RawArray) callconv(.C) void;
    pub extern fn cubs_array_clone(self: *const RawArray) callconv(.C) RawArray;
    pub extern fn cubs_array_tag(self: *const RawArray) callconv(.C) ValueTag;
    pub extern fn cubs_array_len(self: *const RawArray) callconv(.C) usize;
    pub extern fn cubs_array_push_unchecked(self: *RawArray, value: *anyopaque) callconv(.C) void;
    pub extern fn cubs_array_at_unchecked(self: *const RawArray, index: usize) callconv(.C) *const anyopaque;
    pub extern fn cubs_array_at(out: **const anyopaque, self: *const RawArray, index: usize) callconv(.C) Err;
    pub extern fn cubs_array_at_mut_unchecked(self: *RawArray, index: usize) callconv(.C) *anyopaque;
    pub extern fn cubs_array_at_mut(out: **anyopaque, self: *RawArray, index: usize) callconv(.C) Err;
};

test "nested array" {
    var arr1 = Array(Array(i64)).init();
    defer arr1.deinit();

    var arr2 = Array(i64).init();
    arr2.push(1);
    arr1.push(arr2);
}

test "push" {
    {
        var arr = Array(i64).init();
        defer arr.deinit();

        arr.push(6);
        try expect(arr.len == 1);

        arr.push(7);
        try expect(arr.len == 2);
    }
    {
        var arr = Array(String).init();
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect(arr.len == 1);

        arr.push(String.initUnchecked("hi"));
        try expect(arr.len == 2);
    }
}

test "atUnchecked" {
    {
        var arr = Array(i64).init();
        defer arr.deinit();

        arr.push(6);
        try expect(arr.atUnchecked(0).* == 6);

        arr.push(7);
        try expect(arr.atUnchecked(0).* == 6);
        try expect(arr.atUnchecked(1).* == 7);
    }
    {
        var arr = Array(String).init();
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect(arr.atUnchecked(0).eqlSlice("hi"));

        arr.push(String.initUnchecked("hi"));
        try expect(arr.atUnchecked(0).eqlSlice("hi"));
        try expect(arr.atUnchecked(1).eqlSlice("hi"));
    }
}

test "at" {
    {
        var arr = Array(i64).init();
        defer arr.deinit();

        arr.push(6);
        try expect((try arr.at(0)).* == 6);
        try std.testing.expectError(error.OutOfRange, arr.at(1));

        arr.push(7);
        try expect((try arr.at(0)).* == 6);
        try expect((try arr.at(1)).* == 7);
        try std.testing.expectError(error.OutOfRange, arr.at(2));
    }
    {
        var arr = Array(String).init();
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect((try arr.at(0)).eqlSlice("hi"));
        try std.testing.expectError(error.OutOfRange, arr.at(1));

        arr.push(String.initUnchecked("hi"));
        try expect((try arr.at(0)).eqlSlice("hi"));
        try expect((try arr.at(1)).eqlSlice("hi"));
        try std.testing.expectError(error.OutOfRange, arr.at(2));
    }
}

test "atMutUnchecked" {
    {
        var arr = Array(i64).init();
        defer arr.deinit();

        arr.push(6);
        try expect(arr.atMutUnchecked(0).* == 6);

        arr.atMutUnchecked(0).* = 8;

        arr.push(7);
        try expect(arr.atMutUnchecked(0).* == 8);
        try expect(arr.atMutUnchecked(1).* == 7);
    }
    {
        var arr = Array(String).init();
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect(arr.atMutUnchecked(0).eqlSlice("hi"));

        arr.atMutUnchecked(0).deinit();
        arr.atMutUnchecked(0).* = String.initUnchecked("erm");

        arr.push(String.initUnchecked("hi"));
        try expect(arr.atMutUnchecked(0).eqlSlice("erm"));
        try expect(arr.atMutUnchecked(1).eqlSlice("hi"));
    }
}

test "atMut" {
    {
        var arr = Array(i64).init();
        defer arr.deinit();

        arr.push(6);
        try expect((try arr.atMut(0)).* == 6);
        try std.testing.expectError(error.OutOfRange, arr.at(1));

        (try arr.atMut(0)).* = 8;

        arr.push(7);
        try expect((try arr.atMut(0)).* == 8);
        try expect((try arr.atMut(1)).* == 7);
        try std.testing.expectError(error.OutOfRange, arr.at(2));
    }
    {
        var arr = Array(String).init();
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect((try arr.atMut(0)).eqlSlice("hi"));
        try std.testing.expectError(error.OutOfRange, arr.at(1));

        (try arr.atMut(0)).deinit();
        (try arr.atMut(0)).* = String.initUnchecked("erm");

        arr.push(String.initUnchecked("hi"));
        try expect((try arr.atMut(0)).eqlSlice("erm"));
        try expect((try arr.atMut(1)).eqlSlice("hi"));
        try std.testing.expectError(error.OutOfRange, arr.at(2));
    }
}

test "clone" {
    {
        var arr = Array(i64).init();
        defer arr.deinit();

        for (0..6) |i| {
            arr.push(@intCast(i));
        }

        var clone = arr.clone();
        defer clone.deinit();

        try expect(clone.len == 6);
        for (0..6) |i| {
            try expect(clone.atUnchecked(i).* == @as(i64, @intCast(i)));
        }
    }
    {
        var arr = Array(String).init();
        defer arr.deinit();

        for (0..6) |i| {
            arr.push(String.fromInt(@intCast(i)));
        }

        var clone = arr.clone();
        defer clone.deinit();

        try expect(clone.len == 6);
        try expect(clone.atUnchecked(0).eqlSlice("0"));
        try expect(clone.atUnchecked(1).eqlSlice("1"));
        try expect(clone.atUnchecked(2).eqlSlice("2"));
        try expect(clone.atUnchecked(3).eqlSlice("3"));
        try expect(clone.atUnchecked(4).eqlSlice("4"));
        try expect(clone.atUnchecked(5).eqlSlice("5"));
    }
}
