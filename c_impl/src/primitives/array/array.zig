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
        None = 0,
        OutOfRange = 1,
    };

    const CUBS_ARRAY_N_POS: usize = @bitCast(@as(i64, -1));

    extern fn cubs_array_init(tag: ValueTag) callconv(.C) Array;
    extern fn cubs_array_deinit(self: *Array) callconv(.C) void;
    extern fn cubs_array_tag(self: *const Array) callconv(.C) ValueTag;
    extern fn cubs_array_len(self: *const Array) callconv(.C) usize;
    extern fn cubs_array_push_unchecked(self: *Array, value: *const anyopaque) callconv(.C) void;
    extern fn cubs_array_push_raw_unchecked(self: *Array, value: RawValue) callconv(.C) void;
    extern fn cubs_array_push(self: *Array, value: CTaggedValue) callconv(.C) void;
    extern fn cubs_array_at_unchecked(self: *const Array, index: usize) callconv(.C) *const RawValue;
    extern fn cubs_array_at(out: **const anyopaque, self: *const Array, index: usize) callconv(.C) Err;
    extern fn cubs_array_at_mut_unchecked(self: *Array, index: usize) callconv(.C) *RawValue;
    extern fn cubs_array_at_mut(out: **anyopaque, self: *Array, index: usize) callconv(.C) Err;
};

pub const Array = extern struct {
    const Self = @This();

    len: usize,
    _buf: ?*anyopaque,
    _metadata: usize,

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

    /// Takes ownership of `value`. Accessing the memory of `value` after this
    /// function is undefined behaviour.
    /// # Debug Asserts
    /// Asserts that the type of `value` matches the tag of `self`.
    pub fn push(self: *Self, value: anytype) void {
        const T = @TypeOf(value);
        if (T == TaggedValue) {
            self.pushTagged(value);
        } else if (T == RawValue) {
            @compileError("Cannot validate that union RawValue is using the correct active union. Use cubic_script.Array.pushRawUnchecked(...) instead");
        } else if (T == comptime_int) {
            script_value.validateTypeMatchesTag(i64, self.tag());
            const num: i64 = value;
            c.cubs_array_push_unchecked(self, @ptrCast(&num));
        } else if (T == comptime_float) {
            script_value.validateTypeMatchesTag(f64, self.tag());
            const num: f64 = value;
            c.cubs_array_push_unchecked(self, @ptrCast(&num));
        } else {
            script_value.validateTypeMatchesTag(T, self.tag());
            c.cubs_array_push_unchecked(self, @ptrCast(&value));
        }
    }

    /// Pushes a tagged value onto the end of the array, taking ownership of `value`.
    /// Accessing `value` after this call is undefined behaviour.
    /// # Debug Asserts
    /// Asserts that the tag of `value` matches the tag of `self`.
    pub fn pushTagged(self: *Self, value: TaggedValue) void {
        var mutValue = value;
        const cValue = @call(.always_inline, TaggedValue.intoCRepr, .{&mutValue});
        c.cubs_array_push(self, cValue);
    }

    /// Pushes a raw script value onto the end of the array, taking ownership of `value`.
    /// Accessing `value` after  this call is undefined behaviour.
    /// Does not assert that `value` has the correct active union.
    pub fn pushRawUnchecked(self: *Self, value: RawValue) void {
        c.cubs_array_push_raw_unchecked(self, value);
    }

    /// Copy the memory at `value`, pushing the copy onto the end of the array, taking ownership
    /// of the memory at `value`. Does not validate that the memory at `value` is the same as the tag of `self`.
    /// It is up to the programmer to ensure this is the case. In most situations simply calling `self.push(...)`
    /// is preferred.
    pub fn pushMemUnchecked(self: *Self, value: *const anyopaque) void {
        c.cubs_array_push_unchecked(self, value);
    }

    pub fn atUnchecked(self: *const Self, comptime T: type, index: usize) *const T {
        return @ptrCast(@alignCast(c.cubs_array_at_unchecked(self, index)));
    }

    pub fn at(self: *const Self, comptime T: type, index: usize) Error!*const T {
        var out: *const anyopaque = undefined;
        switch (c.cubs_array_at(&out, self, index)) {
            .None => {
                return @ptrCast(@alignCast(out));
            },
            .OutOfRange => {
                return Error.OutOfRange;
            },
        }
    }

    pub fn atMutUnchecked(self: *Self, comptime T: type, index: usize) *T {
        return @ptrCast(@alignCast(c.cubs_array_at_mut_unchecked(self, index)));
    }

    pub fn atMut(self: *Self, comptime T: type, index: usize) Error!*T {
        var out: *anyopaque = undefined;
        switch (c.cubs_array_at_mut(&out, self, index)) {
            .None => {
                return @ptrCast(@alignCast(out));
            },
            .OutOfRange => {
                return Error.OutOfRange;
            },
        }
    }

    // test init {
    //     inline for (@typeInfo(ValueTag).Enum.fields) |f| {
    //         var arr = Array.init(@enumFromInt(f.value));
    //         defer arr.deinit();

    //         try expect(arr.tag() == @as(ValueTag, @enumFromInt(f.value)));
    //     }
    // }

    test push {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(6);
            try expect(arr.len == 1);

            arr.push(7);
            try expect(arr.len == 2);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(String.initUnchecked("hi"));
            try expect(arr.len == 1);

            arr.push(String.initUnchecked("hi"));
            try expect(arr.len == 2);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(TaggedValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len == 1);

            arr.push(TaggedValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len == 2);
        }
    }

    test pushTagged {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.pushTagged(TaggedValue{ .int = 6 });
            try expect(arr.len == 1);

            arr.pushTagged(TaggedValue{ .int = 7 });
            try expect(arr.len == 2);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.pushTagged(TaggedValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len == 1);

            arr.pushTagged(TaggedValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len == 2);
        }
    }

    test pushRawUnchecked {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.pushRawUnchecked(RawValue{ .int = 5 });
            try expect(arr.len == 1);

            arr.pushRawUnchecked(RawValue{ .int = 6 });
            try expect(arr.len == 2);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.pushRawUnchecked(RawValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len == 1);

            arr.pushRawUnchecked(RawValue{ .string = String.initUnchecked("hi") });
            try expect(arr.len == 2);
        }
    }

    test pushMemUnchecked {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            var v: i64 = 6;
            arr.pushMemUnchecked(@ptrCast(&v));
            try expect(arr.len == 1);

            v = 7;
            arr.pushMemUnchecked(@ptrCast(&v));
            try expect(arr.len == 2);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            const s1 = String.initUnchecked("ajshdpiaushdpiuahspdiuahsdpiuahspdiuahspdiuahspd");
            // DO NOT deinit the push values because their ownership is moved
            arr.pushMemUnchecked(@ptrCast(&s1));
            try expect(arr.len == 1);

            const s2 = String.initUnchecked("ajshdpiaushdpiuahspdiuahsdpiuahspdiuahspdiuahspd");
            arr.pushMemUnchecked(@ptrCast(&s2));
            try expect(arr.len == 2);
        }
    }

    test atUnchecked {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(TaggedValue{ .int = 6 });
            try expect(arr.atUnchecked(i64, 0).* == 6);

            arr.push(TaggedValue{ .int = 7 });
            try expect(arr.atUnchecked(i64, 0).* == 6);
            try expect(arr.atUnchecked(i64, 1).* == 7);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(TaggedValue{ .string = String.initUnchecked("hi") });
            try expect(arr.atUnchecked(String, 0).eqlSlice("hi"));

            arr.push(TaggedValue{ .string = String.initUnchecked("hi") });
            try expect(arr.atUnchecked(String, 0).eqlSlice("hi"));
            try expect(arr.atUnchecked(String, 1).eqlSlice("hi"));
        }
    }

    test at {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(6);
            try expect((try arr.at(i64, 0)).* == 6);
            try std.testing.expectError(Error.OutOfRange, arr.at(i64, 1));

            arr.push(7);
            try expect((try arr.at(i64, 0)).* == 6);
            try expect((try arr.at(i64, 1)).* == 7);
            try std.testing.expectError(Error.OutOfRange, arr.at(i64, 2));
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(String.initUnchecked("hi"));
            try expect((try arr.at(String, 0)).eqlSlice("hi"));
            try std.testing.expectError(Error.OutOfRange, arr.at(String, 1));

            arr.push(String.initUnchecked("hi"));
            try expect((try arr.at(String, 0)).eqlSlice("hi"));
            try expect((try arr.at(String, 1)).eqlSlice("hi"));
            try std.testing.expectError(Error.OutOfRange, arr.at(String, 2));
        }
    }

    test atMutUnchecked {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(6);
            try expect(arr.atMutUnchecked(i64, 0).* == 6);

            arr.atMutUnchecked(i64, 0).* = 8;

            arr.push(7);
            try expect(arr.atMutUnchecked(i64, 0).* == 8);
            try expect(arr.atMutUnchecked(i64, 1).* == 7);
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(String.initUnchecked("hi"));
            try expect(arr.atMutUnchecked(String, 0).eqlSlice("hi"));

            arr.atMutUnchecked(String, 0).deinit();
            arr.atMutUnchecked(String, 0).* = String.initUnchecked("erm");

            arr.push(String.initUnchecked("hi"));
            try expect(arr.atMutUnchecked(String, 0).eqlSlice("erm"));
            try expect(arr.atMutUnchecked(String, 1).eqlSlice("hi"));
        }
    }

    test atMut {
        {
            var arr = Array.init(.int);
            defer arr.deinit();

            arr.push(6);
            try expect((try arr.atMut(i64, 0)).* == 6);
            try std.testing.expectError(Error.OutOfRange, arr.at(i64, 1));

            (try arr.atMut(i64, 0)).* = 8;

            arr.push(7);
            try expect((try arr.atMut(i64, 0)).* == 8);
            try expect((try arr.atMut(i64, 1)).* == 7);
            try std.testing.expectError(Error.OutOfRange, arr.at(i64, 2));
        }
        {
            var arr = Array.init(.string);
            defer arr.deinit();

            arr.push(String.initUnchecked("hi"));
            try expect((try arr.atMut(String, 0)).eqlSlice("hi"));
            try std.testing.expectError(Error.OutOfRange, arr.at(String, 1));

            (try arr.atMut(String, 0)).deinit();
            (try arr.atMut(String, 0)).* = String.initUnchecked("erm");

            arr.push(String.initUnchecked("hi"));
            try expect((try arr.atMut(String, 0)).eqlSlice("erm"));
            try expect((try arr.atMut(String, 1)).eqlSlice("hi"));
            try std.testing.expectError(Error.OutOfRange, arr.at(String, 2));
        }
    }
};
