const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

pub const CubicScriptState = @import("state/CubicScriptState.zig");

pub const FALSE: Bool = 0;
pub const TRUE: Bool = 1;

/// true = 1, false = 0. Corresponds with `CubsBool` in `cubic_script.h`.
pub const Bool = usize;
/// Signed 64 bit integer. Corresponds with `CubsInt` in `cubic_script.h`.
pub const Int = i64;
/// 64 bit float. Corresponds with `CubsFloat` in `cubic_script.h`.
pub const Float = f64;

pub const String = @import("types/string.zig").String;

pub const Array = @import("types/array.zig").Array;

pub const Map = @import("types/map.zig").Map;

pub const ValueTag = enum(usize) {
    Bool = 0,
    Int = 1,
    Float = 2,
    String = 3,
    Array = 4,
    Map = 5,
    Set = 6,
    Vec2i = 7,
    Vec3i = 8,
    Vec4i = 9,
    Vec2f = 10,
    Vec3f = 11,
    Vec4f = 12,
    Class = 13,
};

/// Untagged union representing all primitive value types and classes.
pub const RawValue = extern union {
    boolean: Bool,
    int: Int,
    float: Float,
    string: String,
    array: Array,
    map: Map,
    // TODO other primitive types

    /// In some cases, it's more convenient to just deinit here.
    pub fn deinit(self: *RawValue, tag: ValueTag, state: *const CubicScriptState) void {
        switch (tag) {
            .Bool, .Int, .Float => {},
            .String => {
                self.string.deinit(state);
            },
            .Array => {
                self.array.deinit(state);
            },
            .Map => {
                self.map.deinit(state);
            },
            else => {
                @panic("Unsupported");
            },
        }
    }
};

/// Compatible with C
pub const TaggedValue = extern struct {
    value: RawValue,
    tag: ValueTag,

    /// For zig/c compatibility
    pub fn initBool(inBool: Bool) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Bool, .value = .{ .boolean = inBool } };
    }
    /// For zig/c compatibility
    pub fn initInt(inInt: Int) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Int, .value = .{ .int = inInt } };
    }

    /// For zig/c compatibility
    pub fn initFloat(inFloat: Float) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Float, .value = .{ .float = inFloat } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inString`.
    pub fn initString(inString: String) TaggedValue {
        return TaggedValue{ .tag = ValueTag.String, .value = .{ .string = inString } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inArray`.
    pub fn initArray(inArray: Array) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Array, .value = .{ .array = inArray } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inMap`.
    pub fn initMap(inMap: Map) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Map, .value = .{ .map = inMap } };
    }

    pub fn deinit(self: *TaggedValue, state: *const CubicScriptState) void {
        self.value.deinit(self.tag, state);
    }
};

pub const TaggedValueMutRef = extern struct {
    value: *RawValue,
    tag: ValueTag,
};

pub const TaggedValueConstRef = extern struct {
    value: *const RawValue,
    tag: ValueTag,
};
