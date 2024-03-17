//! Primitive types for script

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

/// In some situations, tagged pointers can be useful. The `PrimitiveType` enum values can be used as ptr tags.
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

pub const FALSE: Bool = 0;
pub const TRUE: Bool = 1;

/// true = not 0, false = 0
pub const Bool = usize;
/// Signed 64 bit integer
pub const Int = i64;
/// 64 bit float
pub const Float = f64;

pub const String = @import("string.zig").String;

pub const Array = @import("array.zig").Array;

pub const Map = @import("map.zig").Map;

/// Untagged union representing all primitive value types and classes.
pub const Value = extern union {
    boolean: Bool,
    int: Int,
    float: Float,
    string: String,
    array: Array,
    map: Map,
    // TODO other primitive types

    /// In some cases, it's more convenient to just deinit here.
    pub fn deinit(self: *Value, tag: ValueTag, allocator: Allocator) void {
        switch (tag) {
            .Bool, .Int, .Float => {},
            .String => {
                self.string.deinit(allocator);
            },
            .Array => {
                self.array.deinit(allocator);
            },
            .Map => {
                self.map.deinit(allocator);
            },
            else => {
                @panic("Unsupported");
            },
        }
    }
};

/// Compatible with C
pub const TaggedValue = extern struct {
    value: Value,
    tag: ValueTag,

    /// For zig/c compatibility
    pub fn initBool(inBool: Bool) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Bool, .value = Value{ .boolean = inBool } };
    }
    /// For zig/c compatibility
    pub fn initInt(inInt: Int) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Int, .value = Value{ .int = inInt } };
    }

    /// For zig/c compatibility
    pub fn initFloat(inFloat: Float) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Float, .value = Value{ .float = inFloat } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inString`.
    pub fn initString(inString: String) TaggedValue {
        return TaggedValue{ .tag = ValueTag.String, .value = Value{ .string = inString } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inArray`.
    pub fn initArray(inArray: Array) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Array, .value = Value{ .array = inArray } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inMap`.
    pub fn initMap(inMap: Map) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Map, .value = Value{ .map = inMap } };
    }

    pub fn deinit(self: *TaggedValue, allocator: Allocator) void {
        self.value.deinit(self.tag, allocator);
    }
};

pub const TaggedValueMutRef = extern struct {
    value: *Value,
    tag: ValueTag,
};

pub const TaggedValueConstRef = extern struct {
    value: *const Value,
    tag: ValueTag,
};
