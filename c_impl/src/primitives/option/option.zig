const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;

const c = struct {
    const Err = enum(c_int) {
        None,
        IsNone,
    };

    extern fn cubs_option_init_unchecked(tag: ValueTag, value: *anyopaque) callconv(.C) Option(anyopaque);
    extern fn cubs_option_init_raw_unchecked(tag: ValueTag, value: RawValue) callconv(.C) Option(anyopaque);
    extern fn cubs_option_init(value: CTaggedValue) callconv(.C) Option(anyopaque);
    extern fn cubs_option_deinit(self: *Option(anyopaque)) callconv(.C) void;
    extern fn cubs_option_get_unchecked(self: *const Option(anyopaque)) callconv(.C) *const anyopaque;
    extern fn cubs_option_get_mut_unchecked(self: *Option(anyopaque)) callconv(.C) *anyopaque;
    extern fn cubs_option_get(out: **const anyopaque, self: *const Option(anyopaque)) callconv(.C) Err;
    extern fn cubs_option_get_mut(out: **anyopaque, self: *Option(anyopaque)) callconv(.C) Err;
    extern fn cubs_option_take(out: *anyopaque, self: *Option(anyopaque)) callconv(.C) Err;
};

/// Default initialization makes it a none option
pub fn Option(comptime T: type) type {
    return extern struct {
        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .option;
        pub const ValueType = T;

        tag: ValueTag = script_value.scriptTypeToTag(T),
        isSome: bool = false,
        sizeOfType: u8 = @sizeOf(T),
        metadata: [4]?*anyopaque = std.mem.zeroes([4]?*anyopaque),

        ///
        pub fn init(value: T) Self {
            const valueTag = script_value.scriptTypeToTag(T);
            var mutValue = value;
            var temp = c.cubs_option_init_unchecked(valueTag, @ptrCast(&mutValue));
            return temp.into(T);
        }

        pub fn initRawUnchecked(value: RawValue) Self {
            const valueTag = script_value.scriptTypeToTag(T);
            var temp = c.cubs_option_init_raw_unchecked(valueTag, value);
            return temp.into(T);
        }

        pub fn initTagged(value: TaggedValue) Self {
            assert(value.tag() == script_value.scriptTypeToTag(T));
            var mutValue = value;
            const cValue = @call(.always_inline, TaggedValue.intoCRepr, .{&mutValue});
            return c.cubs_option_init(cValue);
        }

        pub fn deinit(self: *Self) void {
            c.cubs_option_deinit(self.castMut(anyopaque));
        }

        pub fn cast(self: *const Self, comptime OtherT: type) *const Option(OtherT) {
            if (OtherT != anyopaque) {
                script_value.validateTypeMatchesTag(OtherT, self.tag());
            }
            return @ptrCast(self);
        }

        pub fn castMut(self: *Self, comptime OtherT: type) *Option(OtherT) {
            if (OtherT != anyopaque) {
                script_value.validateTypeMatchesTag(OtherT, self.tag());
            }
            return @ptrCast(self);
        }

        /// Converts an option of one type into an option of another type. Currently only works when converting
        /// to and from `anyopaque` arrays.
        pub fn into(self: *Self, comptime OtherT: type) Option(OtherT) {
            const casted = self.castMut(OtherT).*;
            self.* = undefined; // invalidate self
            return casted;
        }

        pub fn getUnchecked(self: *const Self) *const T {
            return @ptrCast(@alignCast(c.cubs_option_get_unchecked(self.cast(anyopaque))));
        }

        pub fn get(self: *const Self) error{IsNone}!*const T {
            var out: *const T = undefined;
            switch (c.cubs_option_get(@ptrCast(&out), self)) {
                .None => {
                    return out;
                },
                .IsNone => {
                    return error.IsNone;
                },
            }
        }

        pub fn getMutUnchecked(self: *Self) *T {
            return @ptrCast(@alignCast(c.cubs_option_get_mut_unchecked(self.castMut(anyopaque))));
        }

        pub fn getMut(self: *Self) error{IsNone}!*T {
            var out: *T = undefined;
            switch (c.cubs_option_get_mut(@ptrCast(&out), self)) {
                .None => {
                    return out;
                },
                .IsNone => {
                    return error.IsNone;
                },
            }
        }

        /// Take ownership of the optional, returning either `null`, or the value `T`.
        /// Deinitializes `self` at the same time.
        pub fn take(self: *Self) ?T {
            var out: T = undefined;
            switch (c.cubs_option_take(@ptrCast(&out), self.castMut(anyopaque))) {
                .None => {
                    return out;
                },
                .IsNone => {
                    return null;
                },
            }
        }

        test "null" {
            {
                var opt = Option(i64){};
                defer opt.deinit();

                try expect(opt.isSome == false);
                try expect(opt.take() == null);
            }
            {
                var opt = Option(String){};
                defer opt.deinit();

                try expect(opt.isSome == false);
                try expect(opt.take() == null);
            }
            {
                var opt = Option(Option(String)){};
                defer opt.deinit();

                try expect(opt.isSome == false);
                try expect(opt.take() == null);
            }
        }
    };
}
