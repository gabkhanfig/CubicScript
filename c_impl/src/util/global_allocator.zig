const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

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

/// Allows changing the allocator used by CubicScript at runtime.
///
/// # SAFETY
///
/// Changing the allocator while objects that have been allocated have NOT been freed
/// still exist is EXTREMELY unsafe and can lead to full application crashes.
pub fn setAllocator(a: Allocator) void {
    globalAllocator = a;
}

export fn cubs_malloc(len: c_ulonglong, ptrAlign: c_ulonglong) callconv(.C) *anyopaque {
    const logAlign: u6 = @intCast(std.math.log2(ptrAlign)); // This is required because of how the allocator alignment is `1 << log2(align)`.
    const mem = globalAllocator.rawAlloc(@intCast(len), logAlign, @returnAddress());
    if (mem == null) {
        @panic("CubicScript failed to allocate memory");
    }
    return @ptrCast(mem);
}

export fn cubs_free(buf: *anyopaque, len: c_ulonglong, ptrAlign: c_ulonglong) callconv(.C) void {
    const logAlign: u6 = @intCast(std.math.log2(ptrAlign)); // This is required because of how the allocator alignment is `1 << log2(align)`.
    const mem: [*]u8 = @ptrCast(buf);
    globalAllocator.rawFree(mem[0..len], logAlign, @returnAddress());
}
