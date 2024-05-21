const std = @import("std");
const expect = std.testing.expect;
const value_types = @import("values.zig");
const ValueTag = value_types.ValueTag;
const RawValue = value_types.RawValue;
const TaggedValue = value_types.TaggedValue;
const String = @import("string.zig").String;

const c = struct {
    const Err = enum(c_int) {
        None = 0,
    };

    const CUBS_ARRAY_N_POS: usize = @bitCast(@as(i64, -1));

    extern fn cubs_array_init(tag: ValueTag) callconv(.C) Array;
    extern fn cubs_array_deinit(self: *Array) callconv(.C) void;
    extern fn cubs_array_tag(self: *const Array) callconv(.C) ValueTag;
    extern fn cubs_array_len(self: *const Array) callconv(.C) usize;
    extern fn cubs_array_push_unchecked(self: *Array, value: RawValue) callconv(.C) void;
    extern fn cubs_array_push(self: *Array, value: TaggedValue) callconv(.C) void;
};

pub const Array = extern struct {
    const Self = @This();

    _inner: ?*anyopaque,

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

    pub fn push(self: *Self, value: TaggedValue) void {
        c.cubs_array_push(self, value);
    }

    // test init {
    //     inline for (@typeInfo(ValueTag).Enum.fields) |f| {
    //         var arr = Array.init(@enumFromInt(f.value));
    //         defer arr.deinit();

    //         try expect(arr.tag() == @as(ValueTag, @enumFromInt(f.value)));
    //     }
    // }

    test pushUnchecked {
        {
            var arr = Array.init(.Int);
            defer arr.deinit();

            arr.pushUnchecked(RawValue{ .int = 5 });
            try expect(arr.len() == 1);

            arr.pushUnchecked(RawValue{ .int = 6 });
            try expect(arr.len() == 2);
        }
        {
            var arr = Array.init(.String);
            defer arr.deinit();

            arr.pushUnchecked(RawValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len() == 1);

            arr.pushUnchecked(RawValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len() == 2);
        }
    }
};
