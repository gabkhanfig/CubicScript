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

    extern fn cubs_array_init(tag: ValueTag) callconv(.C) Array(anyopaque);
    extern fn cubs_array_deinit(self: *Array(anyopaque)) callconv(.C) void;
    extern fn cubs_array_tag(self: *const Array(anyopaque)) callconv(.C) ValueTag;
    extern fn cubs_array_len(self: *const Array(anyopaque)) callconv(.C) usize;
    extern fn cubs_array_push_unchecked(self: *Array(anyopaque), value: *anyopaque) callconv(.C) void;
    extern fn cubs_array_push_raw_unchecked(self: *Array(anyopaque), value: RawValue) callconv(.C) void;
    extern fn cubs_array_push(self: *Array(anyopaque), value: CTaggedValue) callconv(.C) void;
    extern fn cubs_array_at_unchecked(self: *const Array(anyopaque), index: usize) callconv(.C) *const anyopaque;
    extern fn cubs_array_at(out: **const anyopaque, self: *const Array(anyopaque), index: usize) callconv(.C) Err;
    extern fn cubs_array_at_mut_unchecked(self: *Array(anyopaque), index: usize) callconv(.C) *anyopaque;
    extern fn cubs_array_at_mut(out: **anyopaque, self: *Array(anyopaque), index: usize) callconv(.C) Err;
};

/// If `T == anyopaque`, the array is considered to be identical to `CubsArray` in C.
/// Casting to the correct T can be achieved through `Array(...).cast(...)`, `Array(...).castMut(...)`, and `Array(...).into(...)`.
pub fn Array(comptime T: type) type {
    return extern struct {
        const Self = @This();
        /// Helper to generically determine the script value type of `Self`, for example, since this is an `Array`,
        /// it returns `.array`. This is implemented for all script value that are generic.
        pub const SCRIPT_SELF_TAG: ValueTag = .array;
        pub const ValueType = T;

        len: usize,
        _buf: ?*anyopaque,
        _metadata: usize,

        pub const Error = error{
            OutOfRange,
        };

        pub fn init() Self {
            const valueTag = script_value.scriptTypeToTag(T);
            var temp = c.cubs_array_init(valueTag);
            return temp.into(T);
        }

        pub fn deinit(self: *Self) void {
            return c.cubs_array_deinit(self.castMut(anyopaque));
        }

        pub fn tag(self: *const Self) ValueTag {
            return c.cubs_array_tag(self.cast(anyopaque));
        }

        pub fn cast(self: *const Self, comptime OtherT: type) *const Array(OtherT) {
            if (OtherT != anyopaque) {
                script_value.validateTypeMatchesTag(OtherT, self.tag());
            }
            return @ptrCast(self);
        }

        pub fn castMut(self: *Self, comptime OtherT: type) *Array(OtherT) {
            if (OtherT != anyopaque) {
                script_value.validateTypeMatchesTag(OtherT, self.tag());
            }
            return @ptrCast(self);
        }

        /// Converts an array of one type into an array of another type. Currently only works when converting
        /// to and from `anyopaque` arrays.
        pub fn into(self: *Self, comptime OtherT: type) Array(OtherT) {
            const casted = self.castMut(OtherT).*;
            self.* = undefined; // invalidate self
            return casted;
        }

        /// Takes ownership of `value`. Accessing the memory of `value` after this
        /// function is undefined behaviour.
        /// # Debug Asserts
        /// Asserts that the type of `value` matches the tag of `self`.
        pub fn push(self: *Self, value: T) void {
            script_value.validateTypeMatchesTag(T, self.tag());
            var mutValue = value;
            c.cubs_array_push_unchecked(self.castMut(anyopaque), @ptrCast(&mutValue));
        }

        /// Pushes a tagged value onto the end of the array, taking ownership of `value`.
        /// Accessing `value` after this call is undefined behaviour.
        /// # Debug Asserts
        /// Asserts that the tag of `value` matches the tag of `self`.
        pub fn pushTagged(self: *Self, value: TaggedValue) void {
            var mutValue = value;
            const cValue = @call(.always_inline, TaggedValue.intoCRepr, .{&mutValue});
            c.cubs_array_push(self.castMut(anyopaque), cValue);
        }

        /// Pushes a raw script value onto the end of the array, taking ownership of `value`.
        /// Accessing `value` after  this call is undefined behaviour.
        /// Does not assert that `value` has the correct active union.
        pub fn pushRawUnchecked(self: *Self, value: RawValue) void {
            c.cubs_array_push_raw_unchecked(self.castMut(anyopaque), value);
        }

        pub fn atUnchecked(self: *const Self, index: usize) *const T {
            return @ptrCast(@alignCast(c.cubs_array_at_unchecked(self.cast(anyopaque), index)));
        }

        pub fn at(self: *const Self, index: usize) Error!*const T {
            var out: *const anyopaque = undefined;
            switch (c.cubs_array_at(&out, self.cast(anyopaque), index)) {
                .None => {
                    return @ptrCast(@alignCast(out));
                },
                .OutOfRange => {
                    return Error.OutOfRange;
                },
            }
        }

        pub fn atMutUnchecked(self: *Self, index: usize) *T {
            return @ptrCast(@alignCast(c.cubs_array_at_mut_unchecked(self.castMut(anyopaque), index)));
        }

        pub fn atMut(self: *Self, index: usize) Error!*T {
            var out: *anyopaque = undefined;
            switch (c.cubs_array_at_mut(&out, self.castMut(anyopaque), index)) {
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

        test "nested array" {
            var arr1 = Array(Array(i64)).init();
            defer arr1.deinit();

            var arr2 = Array(i64).init();
            arr2.push(1);
            arr1.push(arr2);
        }

        test push {
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

        test pushTagged {
            {
                var arr = Array(i64).init();
                defer arr.deinit();

                arr.pushTagged(TaggedValue{ .int = 6 });
                try expect(arr.len == 1);

                arr.pushTagged(TaggedValue{ .int = 7 });
                try expect(arr.len == 2);
            }
            {
                var arr = Array(String).init();
                defer arr.deinit();

                arr.pushTagged(TaggedValue{ .string = String.initUnchecked("hi") });
                try expect(arr.len == 1);

                arr.pushTagged(TaggedValue{ .string = String.initUnchecked("hi") });
                try expect(arr.len == 2);
            }
        }

        test pushRawUnchecked {
            {
                var arr = Array(i64).init();
                defer arr.deinit();

                arr.pushRawUnchecked(RawValue{ .int = 5 });
                try expect(arr.len == 1);

                arr.pushRawUnchecked(RawValue{ .int = 6 });
                try expect(arr.len == 2);
            }
            {
                var arr = Array(String).init();
                defer arr.deinit();

                arr.pushRawUnchecked(RawValue{ .string = String.initUnchecked("hi") });
                try expect(arr.len == 1);

                arr.pushRawUnchecked(RawValue{ .string = String.initUnchecked("hi") });
                try expect(arr.len == 2);
            }
        }

        test atUnchecked {
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

        test at {
            {
                var arr = Array(i64).init();
                defer arr.deinit();

                arr.push(6);
                try expect((try arr.at(0)).* == 6);
                try std.testing.expectError(Error.OutOfRange, arr.at(1));

                arr.push(7);
                try expect((try arr.at(0)).* == 6);
                try expect((try arr.at(1)).* == 7);
                try std.testing.expectError(Error.OutOfRange, arr.at(2));
            }
            {
                var arr = Array(String).init();
                defer arr.deinit();

                arr.push(String.initUnchecked("hi"));
                try expect((try arr.at(0)).eqlSlice("hi"));
                try std.testing.expectError(Error.OutOfRange, arr.at(1));

                arr.push(String.initUnchecked("hi"));
                try expect((try arr.at(0)).eqlSlice("hi"));
                try expect((try arr.at(1)).eqlSlice("hi"));
                try std.testing.expectError(Error.OutOfRange, arr.at(2));
            }
        }

        test atMutUnchecked {
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

        test atMut {
            {
                var arr = Array(i64).init();
                defer arr.deinit();

                arr.push(6);
                try expect((try arr.atMut(0)).* == 6);
                try std.testing.expectError(Error.OutOfRange, arr.at(1));

                (try arr.atMut(0)).* = 8;

                arr.push(7);
                try expect((try arr.atMut(0)).* == 8);
                try expect((try arr.atMut(1)).* == 7);
                try std.testing.expectError(Error.OutOfRange, arr.at(2));
            }
            {
                var arr = Array(String).init();
                defer arr.deinit();

                arr.push(String.initUnchecked("hi"));
                try expect((try arr.atMut(0)).eqlSlice("hi"));
                try std.testing.expectError(Error.OutOfRange, arr.at(1));

                (try arr.atMut(0)).deinit();
                (try arr.atMut(0)).* = String.initUnchecked("erm");

                arr.push(String.initUnchecked("hi"));
                try expect((try arr.atMut(0)).eqlSlice("erm"));
                try expect((try arr.atMut(1)).eqlSlice("hi"));
                try std.testing.expectError(Error.OutOfRange, arr.at(2));
            }
        }
    };
}
