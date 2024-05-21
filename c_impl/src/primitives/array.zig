const std = @import("std");
const expect = std.testing.expect;
const ValueTag = @import("values.zig").ValueTag;

const c = struct {
    const Err = enum(c_int) {
        None = 0,
    };

    const CUBS_ARRAY_N_POS: usize = @bitCast(@as(i64, -1));

    extern fn cubs_array_init(tag: ValueTag) callconv(.C) Array;
    extern fn cubs_array_deinit(self: *Array) callconv(.C) void;
    extern fn cubs_array_tag(self: *const Array) callconv(.C) ValueTag;
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

    test init {
        inline for (@typeInfo(ValueTag).Enum.fields) |f| {
            var arr = Array.init(@enumFromInt(f.value));
            defer arr.deinit();

            try expect(arr.tag() == @as(ValueTag, @enumFromInt(f.value)));
        }
    }
};
