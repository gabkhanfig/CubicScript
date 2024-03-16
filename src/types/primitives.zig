//! Primitive types for script

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

/// In some situations, tagged pointers can be useful. The `PrimitiveType` enum values can be used as ptr tags.
pub const Tag = enum(usize) {
    const PTR_SHIFT = 48;
    pub const TAG_BITMASK = 0xFFFF000000000000;

    Bool = 0,
    Int = @shlExact(1, PTR_SHIFT),
    Float = @shlExact(2, PTR_SHIFT),
    String = @shlExact(3, PTR_SHIFT),
    Array = @shlExact(4, PTR_SHIFT),
    Map = @shlExact(5, PTR_SHIFT),
    Set = @shlExact(6, PTR_SHIFT),
    Vec2i = @shlExact(7, PTR_SHIFT),
    Vec3i = @shlExact(8, PTR_SHIFT),
    Vec4i = @shlExact(9, PTR_SHIFT),
    Vec2f = @shlExact(10, PTR_SHIFT),
    Vec3f = @shlExact(11, PTR_SHIFT),
    Vec4f = @shlExact(12, PTR_SHIFT),
    Class = @shlExact(13, PTR_SHIFT),
};

pub const FALSE: Bool = 0;
pub const TRUE: Bool = 1;

/// true = not 0, false = 0
pub const Bool = i64;
/// Signed 64 bit integer
pub const Int = i64;
/// 64 bit float
pub const Float = f64;

pub const String = @import("string.zig").String;

pub const Array = @import("array.zig").Array;

// Untagged union
pub const Value = extern union {
    boolean: Bool,
    int: Int,
    float: Float,
    string: String,
    array: Array,
    // TODO other primitive types
};
