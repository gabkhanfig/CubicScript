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

// Untagged union

/// Untagged union representing all primitive value types and classes.
pub const Value = extern union {
    boolean: Bool,
    int: Int,
    float: Float,
    string: String,
    array: Array,
    // TODO other primitive types
    tag: ValueTag,
    value: *const Value,
};
