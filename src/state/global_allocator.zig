const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

/// Gets the global allocator instance. This should NOT be used for compile time variables,
/// as it's possible for the allocator to change. To change the allocator, call `setAllocator()`.
/// Changing the allocator has potential safety issues, so see the comment on the function.
pub inline fn allocator() Allocator {
    return globalAllocator;
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var globalAllocator: Allocator = blk: {
    if (@import("builtin").is_test)
        break :blk std.testing.allocator
    else {
        if (std.debug.runtime_safety)
            break :blk gpa.allocator()
        else
            break :blk std.heap.c_allocator;
    }
};
/// Allows using this global variable as an address for a zig allocator.
pub var externAllocator: ScriptExternAllocator = undefined;

/// Allows changing the allocator used by CubicScript at runtime.
///
/// # SAFETY
///
/// Changing the allocator while objects that have been allocated have NOT been freed
/// still exist is EXTREMELY unsafe and can lead to full application crashes.
pub fn setAllocator(a: Allocator) void {
    globalAllocator = a;
}

pub const ScriptExternAllocator = struct {
    const Self = @This();

    externAllocatorPtr: *anyopaque,
    externVTable: *const ExternVTable,

    const ExternVTable = extern struct {
        alloc: *const fn (ctx: *anyopaque, len: usize, ptrAlign: u8) callconv(.C) ?*anyopaque,
        resize: *const fn (ctx: *anyopaque, bufPtr: *anyopaque, bufLen: usize, newLen: usize) callconv(.C) bool,
        free: *const fn (ctx: *anyopaque, bufPtr: ?*anyopaque, bufLen: usize, bufAlign: u8) callconv(.C) void,
        deinit: ?*const fn (ctx: *anyopaque) callconv(.C) void,
    };

    pub fn externAlloc(ctx: *anyopaque, len: usize, ptrAlign: u8, retAddr: usize) ?[*]u8 {
        _ = retAddr;
        assert(len > 0);
        const self: *Self = @ptrCast(@alignCast(ctx));
        const ptr = self.externVTable.alloc(self.externAllocatorPtr, len, ptrAlign);
        if (ptr) |allocation| {
            return @ptrCast(allocation);
        } else {
            return null;
        }
    }

    pub fn externResize(ctx: *anyopaque, buf: []u8, bufAlign: u8, newLen: usize, retAddr: usize) bool {
        _ = retAddr;
        _ = bufAlign;
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.externVTable.resize(
            self.externAllocatorPtr,
            buf.ptr,
            buf.len,
            newLen,
        );
    }

    pub fn externFree(ctx: *anyopaque, buf: []u8, bufAlign: u8, retAddr: usize) void {
        _ = retAddr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.externVTable.free(self.externAllocatorPtr, buf.ptr, buf.len, bufAlign);
    }

    pub fn deinit(self: *Self) void {
        if (self.externVTable.deinit) |deinitFunc| {
            deinitFunc(self.externAllocatorPtr);
        }
    }
};

test "test actually uses testing allocator" {
    try std.testing.expect(allocator().ptr == std.testing.allocator.ptr);
}
