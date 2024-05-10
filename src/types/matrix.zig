const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const math = @import("math.zig");
const allocator = @import("../state/global_allocator.zig").allocator;

// https://www.khronos.org/opengl/wiki/Data_Type_(GLSL)
// For pratical purposes, 3x3 and 4x4 should be the only useful ones, for 2D and 3D math respectively.

/// 3x3 64 bit float matrix
pub const Mat3f = extern struct {
    const Self = @This();
    const DIM = 3;
    const LEN: comptime_int = DIM * DIM;

    inner: ?[*]f64 = null,

    pub fn deinit(self: *Self) void {
        if (self.inner) |inner| {
            allocator().free(inner[0..LEN]);
            self.inner = null;
        }
    }
};

/// 4x4 64 bit float matrix
pub const Mat4f = extern struct {
    const Self = @This();
    const DIM = 4;
    const LEN: comptime_int = DIM * DIM;

    inner: ?[*]align(64) f64 = null,

    pub fn deinit(self: *Self) void {
        if (self.inner) |inner| {
            const alignedInner: [*]align(64) f64 = @alignCast(inner);
            allocator().free(alignedInner[0..LEN]);
            self.inner = null;
        }
    }
};
