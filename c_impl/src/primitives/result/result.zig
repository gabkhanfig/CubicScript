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
    extern fn cubs_error_init_unchecked(errorName: String, optionalErrorMetadata: ?*anyopaque, optionalErrorTag: ValueTag) callconv(.C) Error;
    extern fn cubs_error_init_raw_unchecked(errorName: String, optionalErrorMetadata: ?*RawValue, optionalErrorTag: ValueTag) callconv(.C) Error;
    extern fn cubs_error_init(errorName: String, optionalErrorMetadata: ?*CTaggedValue) callconv(.C) Error;
    extern fn cubs_error_deinit(self: *Error) callconv(.C) void;
    extern fn cubs_error_metadata(self: *const Error) callconv(.C) ?*const CTaggedValue;
    extern fn cubs_error_take_metadata_unchecked(self: *Error) callconv(.C) CTaggedValue;
    extern fn cubs_error_take_metadata(out: *CTaggedValue, self: *Error) callconv(.C) bool;

    const Err = enum(c_int) {
        None = 0,
        IsOk = 1,
        IsErr = 2,
    };

    extern fn cubs_result_init_ok_unchecked(okTag: ValueTag, okValue: *anyopaque) callconv(.C) Result(anyopaque);
    extern fn cubs_result_init_ok_raw_unchecked(okTag: ValueTag, okValue: RawValue) callconv(.C) Result(anyopaque);
    extern fn cubs_result_init_ok(okValue: CTaggedValue) callconv(.C) Result(anyopaque);
    extern fn cubs_result_init_err(okTag: ValueTag, err: Error) callconv(.C) Result(anyopaque);
    extern fn cubs_result_deinit(self: *Result(anyopaque)) callconv(.C) void;
    extern fn cubs_result_ok_tag(self: *const Result(anyopaque)) callconv(.C) ValueTag;
    extern fn cubs_result_size_of_ok(self: *const Result(anyopaque)) callconv(.C) usize;
    extern fn cubs_result_is_ok(self: *const Result(anyopaque)) callconv(.C) bool;
    extern fn cubs_result_ok_unchecked(out: *anyopaque, self: *Result(anyopaque)) callconv(.C) void;
    extern fn cubs_result_ok(out: *anyopaque, self: *Result(anyopaque)) callconv(.C) Err;
    extern fn cubs_result_err_unchecked(self: *Result(anyopaque)) callconv(.C) Error;
    extern fn cubs_result_err(out: *Error, self: *Result(anyopaque)) callconv(.C) Err;
};

pub const Error = extern struct {
    const Self = @This();
    pub const SCRIPT_SELF_TAG: ValueTag = .err;

    _metadata: ?*anyopaque,
    name: String,

    /// Takes ownership of `errorMetadata`, so accessing the memory afterwards is invalid.
    pub fn init(name: String, errorMetadata: ?TaggedValue) Self {
        if (errorMetadata) |m| {
            var tagged = script_value.zigToCTaggedValueTemp(m);
            return c.cubs_error_init(name, &tagged);
        }
        return c.cubs_error_init(name, null);
    }

    /// For an error with no metadata, use `ValueTag.none`.
    pub fn initUnchecked(name: String, optionalMetadata: ?*anyopaque, optionalTag: ValueTag) Self {
        return c.cubs_error_init_unchecked(name, optionalMetadata, optionalTag);
    }

    /// For an error with no metadata, use `ValueTag.none`.
    pub fn initRawUnchecked(name: String, optionalMetadata: ?*RawValue, optionalTag: ValueTag) Self {
        return c.cubs_error_init_raw_unchecked(name, optionalMetadata, optionalTag);
    }

    pub fn deinit(self: *Self) void {
        c.cubs_error_deinit(self);
    }

    pub fn metadata(self: *const Self) ?*const CTaggedValue {
        return c.cubs_error_metadata(self);
    }

    pub fn takeMetadata(self: *Self) ?TaggedValue {
        var temp: CTaggedValue = undefined;
        if (c.cubs_error_take_metadata(&temp, self)) {
            return TaggedValue.fromCRepr(temp);
        }
        return null;
    }

    // test init {
    //     {
    //         var err = Self.init(String.initUnchecked("yuh"), null);
    //         defer err.deinit();

    //         try expect(err.name.eqlSlice("yuh"));
    //         try expect(err.metadata() == null);
    //     }
    //     {
    //         const errMetadata = TaggedValue{ .int = 8 };
    //         var err = Self.init(String.initUnchecked("yuh"), errMetadata); // <- takes ownership of `errMetadata` here
    //         defer err.deinit();

    //         try expect(err.name.eqlSlice("yuh"));
    //         if (err.metadata()) |foundMetadata| {
    //             try expect(foundMetadata.tag == .int);
    //             try expect(foundMetadata.value.int == 8);
    //         } else {
    //             try expect(false);
    //         }
    //     }
    // }

    // test takeMetadata {
    //     {
    //         var err = Self.init(String.initUnchecked("example"), null);
    //         defer err.deinit();

    //         if (err.takeMetadata()) |_| {
    //             try expect(false);
    //         }
    //     }
    //     {
    //         var err = Self.init(String.initUnchecked("example"), TaggedValue{ .string = String.initUnchecked("hello world! some metadata for this error idk") });
    //         defer err.deinit();

    //         if (err.takeMetadata()) |taken| {
    //             var mutTake = taken;
    //             defer mutTake.deinit();
    //             try expect(taken.string.eqlSlice("hello world! some metadata for this error idk"));
    //         } else {
    //             try expect(false);
    //         }
    //     }
    // }
};

pub fn Result(comptime T: type) type {
    return extern struct {
        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .result;
        pub const ValueType = T;

        comptime {
            if (T == Error) {
                @compileError("Result Ok type may not be an error type");
            }
        }

        _metadata: [5]?*anyopaque,

        pub fn initOk(inOk: T) Self {
            if (T == anyopaque) {
                @compileError("Use `initOkTagged` to initialize a new Result");
            }
            const valueTag = script_value.scriptTypeToTag(T);
            var mutValue = inOk;
            var temp = c.cubs_result_init_ok_unchecked(valueTag, @ptrCast(&mutValue));
            assert(c.cubs_result_size_of_ok(&temp) == @sizeOf(T));
            assert(temp.okTag() == valueTag);
            return temp.into(T);
        }

        pub fn initOkRawUnchecked(inOk: RawValue) Self {
            if (T == anyopaque) {
                @compileError("Use `initOkTagged` to initialize a new Result");
            }
            const valueTag = script_value.scriptTypeToTag(T);
            var temp = c.cubs_result_init_ok_raw_unchecked(valueTag, inOk);
            assert(c.cubs_result_size_of_ok(&temp) == @sizeOf(T));
            assert(temp.okTag() == valueTag);
            return temp.into(T);
        }

        pub fn initOkTagged(inOk: TaggedValue) Self {
            if (T != anyopaque) {
                const valueTag = script_value.scriptTypeToTag(T);
                assert(inOk.tag() == valueTag);
            }
            const cVal = script_value.zigToCTaggedValueTemp(inOk);
            var temp = c.cubs_result_init_ok(cVal);

            assert(temp.okTag() == inOk.tag());
            if (T != anyopaque) {
                assert(c.cubs_result_size_of_ok(&temp) == @sizeOf(T));
            }

            return temp.into(T);
        }

        pub fn initErr(inErr: Error) Self {
            const valueTag = script_value.scriptTypeToTag(T);
            var temp = c.cubs_result_init_err(valueTag, inErr);
            assert(c.cubs_result_size_of_ok(&temp) == @sizeOf(T));
            assert(temp.okTag() == valueTag);
            return temp.into(T);
        }

        pub fn deinit(self: *Self) void {
            c.cubs_result_deinit(self.castMut(anyopaque));
        }

        pub fn cast(self: *const Self, comptime OtherT: type) *const Result(OtherT) {
            if (OtherT != anyopaque) {
                script_value.validateTypeMatchesTag(OtherT, self.okTag());
            }
            return @ptrCast(self);
        }

        pub fn castMut(self: *Self, comptime OtherT: type) *Result(OtherT) {
            if (OtherT != anyopaque) {
                script_value.validateTypeMatchesTag(OtherT, self.okTag());
            }
            return @ptrCast(self);
        }

        /// Converts a `Result(...)` of one type into a `Result(OtherT)` of another type. Currently only works when converting
        /// to and from `anyopaque` arrays.
        pub fn into(self: *Self, comptime OtherT: type) Result(OtherT) {
            const casted = self.castMut(OtherT).*;
            self.* = undefined; // invalidate self
            return casted;
        }

        pub fn okTag(self: *const Self) ValueTag {
            return c.cubs_result_ok_tag(self.cast(anyopaque));
        }

        pub fn isOk(self: *const Self) bool {
            return c.cubs_result_is_ok(self.cast(anyopaque));
        }

        pub fn isErr(self: *const Self) bool {
            return !self.isOk();
        }

        /// Takes out the ok value from the result, taking ownership of it. Also deinitializes `self`.
        pub fn okUnchecked(self: *Self) T {
            var out: T = undefined;
            c.cubs_result_ok_unchecked(@ptrCast(&out), self.castMut(anyopaque));
            return out;
        }

        /// Takes out the ok value from the result, taking ownership of it. Also deinitializes `self`.
        pub fn ok(self: *Self) error{IsErr}!T {
            var out: T = undefined;
            switch (c.cubs_result_ok(@ptrCast(&out), self.castMut(anyopaque))) {
                .None => {
                    return out;
                },
                .IsErr => {
                    return error.IsErr;
                },
                else => {
                    unreachable;
                },
            }
        }

        /// Takes out the err value from the result, taking ownership of it. Also deinitializes `self`.
        pub fn errUnchecked(self: *Self) Error {
            var out: Error = undefined;
            c.cubs_result_err_unchecked(&out, self.castMut(anyopaque));
            return out;
        }

        /// Takes out the err value from the result, taking ownership of it. Also deinitializes `self`.
        pub fn err(self: *Self) error{IsOk}!Error {
            var out: Error = undefined;
            switch (c.cubs_result_err(&out, self.castMut(anyopaque))) {
                .None => {
                    return out;
                },
                .IsOk => {
                    return error.IsOk;
                },
                else => {
                    unreachable;
                },
            }
        }

        // test initOk {
        //     {
        //         var result = Result(i64).initOk(55);
        //         try expect(result.okTag() == .int);
        //         try expect(result.isOk());
        //         if (result.ok()) |num| {
        //             try expect(num == 55);
        //         } else |_| {
        //             try expect(false);
        //         }
        //     }
        //     {
        //         var result = Result(String).initOk(String.initUnchecked("hello world!"));
        //         try expect(result.okTag() == .string);
        //         try expect(result.isOk());
        //         if (result.ok()) |s| {
        //             try expect(s.eqlSlice("hello world!"));
        //             var mutS = s;
        //             mutS.deinit();
        //         } else |_| {
        //             try expect(false);
        //         }
        //     }
        // }

        // test initOkTagged {
        //     {
        //         var tempResult = Result(anyopaque).initOkTagged(TaggedValue{ .int = 55 });
        //         try expect(tempResult.okTag() == .int);

        //         var result = tempResult.into(i64);
        //         try expect(result.okTag() == .int);
        //         try expect(result.isOk());
        //         if (result.ok()) |num| {
        //             try expect(num == 55);
        //         } else |_| {
        //             try expect(false);
        //         }
        //     }
        //     {
        //         var tempResult = Result(anyopaque).initOkTagged(TaggedValue{ .string = String.initUnchecked("hello world!") });
        //         try expect(tempResult.okTag() == .string);

        //         var result = tempResult.into(String);
        //         try expect(result.okTag() == .string);
        //         try expect(result.isOk());
        //         if (result.ok()) |s| {
        //             try expect(s.eqlSlice("hello world!"));
        //             var mutS = s;
        //             mutS.deinit();
        //         } else |_| {
        //             try expect(false);
        //         }
        //     }
        // }

        // test initErr {
        //     {
        //         var result = Result(i64).initErr(Error.init(String.initUnchecked("example"), null));
        //         try expect(result.okTag() == .int);
        //         try expect(result.isErr());
        //         if (result.err()) |e| {
        //             try expect(e.name.eqlSlice("example"));
        //             var mutE = e;
        //             mutE.deinit();
        //         } else |_| {
        //             try expect(false);
        //         }
        //     }
        // }

        // test deinit {
        //     {
        //         var result = Result(String).initOk(String.initUnchecked("ahoduihaosidhoaisdhoaishdoaihsdoaihsd"));
        //         defer result.deinit();
        //     }
        //     {
        //         var result = Result(String).initOk(String.initUnchecked("ahoduihaosidhoaisdhoaishdoaihsdoaihsd"));
        //         defer result.deinit();

        //         if (result.ok()) |s| {
        //             try expect(s.eqlSlice("ahoduihaosidhoaisdhoaishdoaihsdoaihsd"));
        //             var mutS = s;
        //             mutS.deinit();
        //         } else |_| {
        //             try expect(false);
        //         }
        //     }
        // }
    };
}
