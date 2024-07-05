const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;
const StructContext = script_value.StructContext;

/// Default initialization makes it a none option
pub fn Option(comptime T: type) type {
    return extern struct {
        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .option;
        pub const ValueType = T;

        isSome: bool = false,
        _metadata: [4]?*anyopaque = std.mem.zeroes([4]?*anyopaque),
        context: *const StructContext,

        ///
        pub fn init(value: ?T) Self {
            const valueTag = script_value.scriptTypeToTag(T);
            if (value) |v| {
                var mutValue = v;
                const opt = blk: {
                    if (valueTag != .userClass) {
                        break :blk CubsOption.cubs_option_init_primitive(valueTag, &mutValue);
                    } else {
                        break :blk CubsOption.cubs_option_init_user_class(StructContext.auto(T), &mutValue);
                    }
                };
                return @bitCast(opt);
            } else {
                const opt = blk: {
                    if (valueTag != .userClass) {
                        break :blk CubsOption.cubs_option_init_primitive(valueTag, null);
                    } else {
                        break :blk CubsOption.cubs_option_init_user_class(StructContext.auto(T), null);
                    }
                };
                return @bitCast(opt);
            }
        }

        pub fn deinit(self: *Self) void {
            CubsOption.cubs_option_deinit(self.asRawMut());
        }

        pub fn get(self: *const Self) *const T {
            return @ptrCast(@alignCast(CubsOption.cubs_option_get(self.asRaw())));
        }

        pub fn getMut(self: *Self) *T {
            return @ptrCast(@alignCast(CubsOption.cubs_option_get_mut(self.asRawMut())));
        }

        /// Take ownership of the some optional value.
        /// Deinitializes `self` at the same time.
        pub fn take(self: *Self) T {
            var out: T = undefined;
            CubsOption.cubs_option_take(@ptrCast(&out), self.asRawMut());
            return out;
        }

        pub fn asRaw(self: *const Self) *const CubsOption {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsOption {
            return @ptrCast(self);
        }
    };
}

pub const CubsOption = extern struct {
    isSome: bool = false,
    _metadata: [4]?*anyopaque = std.mem.zeroes([4]?*anyopaque),
    context: *const StructContext,

    const Self = @This();
    pub const SCRIPT_SELF_TAG: ValueTag = .option;

    pub extern fn cubs_option_init_primitive(tag: ValueTag, optionalValue: ?*anyopaque) callconv(.C) Self;
    pub extern fn cubs_option_init_user_class(context: *const StructContext, optionalValue: ?*anyopaque) callconv(.C) Self;
    pub extern fn cubs_option_deinit(self: *Self) callconv(.C) void;
    pub extern fn cubs_option_get(self: *const Self) callconv(.C) *const anyopaque;
    pub extern fn cubs_option_get_mut(self: *Self) callconv(.C) *anyopaque;
    pub extern fn cubs_option_take(out: *anyopaque, self: *Self) callconv(.C) void;
};

test "null" {
    {
        var opt = Option(i64).init(null);
        defer opt.deinit();

        try expect(opt.isSome == false);
    }
    {
        var opt = Option(String).init(null);
        defer opt.deinit();

        try expect(opt.isSome == false);
    }
    // {
    //     var opt = Option(Option(String)).init(null);
    //     defer opt.deinit();

    //     try expect(opt.isSome == false);
    // }
}

test "some" {
    {
        var opt = Option(i64).init(4);
        defer opt.deinit();

        try expect(opt.isSome);

        try expect(opt.get().* == 4);
        try expect(opt.getMut().* == 4);

        opt.getMut().* = 5;

        try expect(opt.get().* == 5);
        try expect(opt.getMut().* == 5);
    }
}

test "take" {
    {
        var opt = Option(i64).init(4);
        defer opt.deinit();

        try expect(opt.isSome);

        const took = opt.take();
        try expect(took == 4);
        try expect(opt.isSome == false);
    }
}
