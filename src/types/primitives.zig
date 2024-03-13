//! Primitive types for script

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

/// true = not 0, false = 0
pub const Bool = i64;
/// Signed 64 bit integer
pub const Int = i64;
/// 64 bit float
pub const Float = f64;

pub const String = @import("string.zig").String;
