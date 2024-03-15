const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Int = @import("primitives.zig").Int;

pub const Array = extern struct {
    const Self = @This();
    const ELEMENT_ALIGN = 8;

    inner: ?*anyopaque = null,

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
        return @ptrCast(@alignCast(self.inner));
    }

    fn arrayData(self: *const Self) ?[*]const anyopaque {
        const headerData = self.header();
        if (headerData) |h| {
            const asMultiplePtr: [*]const Header = @ptrCast(h);
            return @ptrCast(&asMultiplePtr[1]);
        } else {
            return null;
        }
    }

    fn arrayDataMut(self: *Self) ?[*]anyopaque {
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
    };
};

// Tests

test "Array default" {
    const arr = Array{};
    try expect(arr.len() == 0);
}
