const std = @import("std");
const expect = std.testing.expect;
const value_types = @import("values.zig");
const ValueTag = value_types.ValueTag;
const RawValue = value_types.RawValue;
const CTaggedValue = value_types.CTaggedValue;
const TaggedValue = value_types.TaggedValue;
const String = @import("string.zig").String;

const c = struct {
    const Err = enum(c_int) {
        None = 0,
        OutOfRange = 1,
    };

    const CUBS_ARRAY_N_POS: usize = @bitCast(@as(i64, -1));

    extern fn cubs_array_init(tag: ValueTag) callconv(.C) Array;
    extern fn cubs_array_deinit(self: *Array) callconv(.C) void;
    extern fn cubs_array_tag(self: *const Array) callconv(.C) ValueTag;
    extern fn cubs_array_len(self: *const Array) callconv(.C) usize;
    extern fn cubs_array_push_unchecked(self: *Array, value: RawValue) callconv(.C) void;
    extern fn cubs_array_push(self: *Array, value: CTaggedValue) callconv(.C) void;
    extern fn cubs_array_at_unchecked(self: *const Array, index: usize) callconv(.C) *const RawValue;
    extern fn cubs_array_at(out: **const RawValue, self: *const Array, index: usize) callconv(.C) Err;
    extern fn cubs_array_at_mut_unchecked(self: *Array, index: usize) callconv(.C) *RawValue;
    extern fn cubs_array_at_mut(out: **RawValue, self: *Array, index: usize) callconv(.C) Err;
};

pub const Array = extern struct {
    const Self = @This();

    _inner: ?*anyopaque,

    pub const Error = error{
        OutOfRange,
    };

    pub fn init(inTag: ValueTag) Self {
        return c.cubs_array_init(inTag);
    }

    pub fn deinit(self: *Self) void {
        return c.cubs_array_deinit(self);
    }

    pub fn tag(self: *const Self) ValueTag {
        return c.cubs_array_tag(self);
    }

    pub fn len(self: *const Self) usize {
        return c.cubs_array_len(self);
    }

    pub fn pushUnchecked(self: *Self, value: RawValue) void {
        c.cubs_array_push_unchecked(self, value);
    }

    pub fn push(self: *Self, value: CTaggedValue) void {
        c.cubs_array_push(self, value);
    }

    pub fn atUnchecked(self: *const Self, index: usize) *const RawValue {
        return c.cubs_array_at_unchecked(self, index);
    }

    pub fn at(self: *const Self, index: usize) Error!*const RawValue {
        var out: *const RawValue = undefined;
        switch (c.cubs_array_at(&out, self, index)) {
            .None => {
                return out;
            },
            .OutOfRange => {
                return Error.OutOfRange;
            },
        }
    }

    pub fn atMutUnchecked(self: *Self, index: usize) *RawValue {
        return c.cubs_array_at_mut_unchecked(self, index);
    }

    pub fn atMut(self: *Self, index: usize) Error!*RawValue {
        var out: *RawValue = undefined;
        switch (c.cubs_array_at_mut(&out, self, index)) {
            .None => {
                return out;
            },
            .OutOfRange => {
                return Error.OutOfRange;
            },
        }
    }

    test init {
        inline for (@typeInfo(ValueTag).Enum.fields) |f| {
            var arr = Array.init(@enumFromInt(f.value));
            defer arr.deinit();

            try expect(arr.tag() == @as(ValueTag, @enumFromInt(f.value)));
        }
    }

    test pushUnchecked {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.pushUnchecked(RawValue{ .int = 5 });
            try expect(arr.len() == 1);

            arr.pushUnchecked(RawValue{ .int = 6 });
            try expect(arr.len() == 2);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.pushUnchecked(RawValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len() == 1);

            arr.pushUnchecked(RawValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len() == 2);
        }
    }

    test push {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 6 } });
            try expect(arr.len() == 1);

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 7 } });
            try expect(arr.len() == 2);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect(arr.len() == 1);

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect(arr.len() == 2);
        }
    }

    test atUnchecked {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 6 } });
            try expect(arr.atUnchecked(0).int == 6);

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 7 } });
            try expect(arr.atUnchecked(0).int == 6);
            try expect(arr.atUnchecked(1).int == 7);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect(arr.atUnchecked(0).string.eqlSlice("hi"));

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect(arr.atUnchecked(0).string.eqlSlice("hi"));
            try expect(arr.atUnchecked(1).string.eqlSlice("hi"));
        }
    }

    test at {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 6 } });
            try expect((try arr.at(0)).int == 6);
            try std.testing.expectError(Error.OutOfRange, arr.at(1));

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 7 } });
            try expect((try arr.at(0)).int == 6);
            try expect((try arr.at(1)).int == 7);
            try std.testing.expectError(Error.OutOfRange, arr.at(2));
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect((try arr.at(0)).string.eqlSlice("hi"));
            try std.testing.expectError(Error.OutOfRange, arr.at(1));

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect((try arr.at(0)).string.eqlSlice("hi"));
            try expect((try arr.at(1)).string.eqlSlice("hi"));
            try std.testing.expectError(Error.OutOfRange, arr.at(2));
        }
    }

    test atMutUnchecked {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 6 } });
            try expect(arr.atMutUnchecked(0).int == 6);

            arr.atMutUnchecked(0).int = 8;

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 7 } });
            try expect(arr.atMutUnchecked(0).int == 8);
            try expect(arr.atMutUnchecked(1).int == 7);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect(arr.atMutUnchecked(0).string.eqlSlice("hi"));

            arr.atMutUnchecked(0).string.deinit();
            arr.atMutUnchecked(0).string = String.initUnchecked("erm");

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect(arr.atMutUnchecked(0).string.eqlSlice("erm"));
            try expect(arr.atMutUnchecked(1).string.eqlSlice("hi"));
        }
    }

    test atMut {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 6 } });
            try expect((try arr.atMut(0)).int == 6);
            try std.testing.expectError(Error.OutOfRange, arr.at(1));

            (try arr.atMut(0)).int = 8;

            arr.push(CTaggedValue{ .tag = .int, .value = RawValue{ .int = 7 } });
            try expect((try arr.atMut(0)).int == 8);
            try expect((try arr.atMut(1)).int == 7);
            try std.testing.expectError(Error.OutOfRange, arr.at(2));
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect((try arr.atMut(0)).string.eqlSlice("hi"));
            try std.testing.expectError(Error.OutOfRange, arr.at(1));

            (try arr.atMut(0)).string.deinit();
            (try arr.atMut(0)).string = String.initUnchecked("erm");

            arr.push(CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hi") } });
            try expect((try arr.atMut(0)).string.eqlSlice("erm"));
            try expect((try arr.atMut(1)).string.eqlSlice("hi"));
            try std.testing.expectError(Error.OutOfRange, arr.at(2));
        }
    }
};
