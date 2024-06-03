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
};

pub const Error = extern struct {
    const Self = @This();

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

    test init {
        {
            var err = Self.init(String.initUnchecked("yuh"), null);
            defer err.deinit();

            try expect(err.name.eqlSlice("yuh"));
            try expect(err.metadata() == null);
        }
        {
            const errMetadata = TaggedValue{ .int = 8 };
            var err = Self.init(String.initUnchecked("yuh"), errMetadata); // <- takes ownership of `errMetadata` here
            defer err.deinit();

            try expect(err.name.eqlSlice("yuh"));
            if (err.metadata()) |foundMetadata| {
                try expect(foundMetadata.tag == .int);
                try expect(foundMetadata.value.int == 8);
            } else {
                try expect(false);
            }
        }
    }

    test takeMetadata {
        {
            var err = Self.init(String.initUnchecked("example"), null);
            defer err.deinit();

            if (err.takeMetadata()) |_| {
                try expect(false);
            }
        }
        {
            var err = Self.init(String.initUnchecked("example"), TaggedValue{ .string = String.initUnchecked("hello world! some metadata for this error idk") });
            defer err.deinit();

            if (err.takeMetadata()) |taken| {
                var mutTake = taken;
                defer mutTake.deinit();
                try expect(taken.string.eqlSlice("hello world! some metadata for this error idk"));
            } else {
                try expect(false);
            }
        }
    }
};
