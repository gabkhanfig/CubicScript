const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Int = @import("primitives.zig").Int;

pub const Array = extern struct {
    const Self = @This();
    const ELEMENT_ALIGN = 8;
    const ARRAY_ALLOC_ALIGN = 32;

    inner: ?*align(ARRAY_ALLOC_ALIGN) anyopaque = null,

    pub fn len(self: *const Self) Int {
        if (self.header()) |h| {
            return h.length;
        } else {
            return 0;
        }
    }

    fn header(self: *const Self) ?*const Header {
        return @ptrCast(self.inner);
    }

    fn headerMut(self: *Self) ?*Header {
        return @ptrCast(self.inner);
    }

    fn arrayData(self: *const Self) ?[*]align(ARRAY_ALLOC_ALIGN) anyopaque {
        const headerData = self.header();
        if (headerData) |h| {
            const asMultiplePtr: [*]const Header = @ptrCast(h);
            return @ptrCast(&asMultiplePtr[1]);
        } else {
            return null;
        }
    }

    fn arrayDataMut(self: *Self) ?[*]align(ARRAY_ALLOC_ALIGN) anyopaque {
        const headerData = self.headerMut();
        if (headerData) |h| {
            const asMultiplePtr: [*]Header = @ptrCast(h);
            return @ptrCast(&asMultiplePtr[1]);
        } else {
            return null;
        }
    }

    const Header = extern struct {
        sizeOfType: Int,
        length: Int,
        capacity: Int,
        typeId: Int,
    };
};

// Tests

test "Header size align" {
    try expect(@sizeOf(Array.Header) == 32);
    try expect(@alignOf(Array.Header) == 8);
}

test "Array default" {
    const arr = Array{};
    try expect(arr.len() == 0);
}
