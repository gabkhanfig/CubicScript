const std = @import("std");
const expect = std.testing.expect;
const Ordering = @import("../util/ordering.zig").Ordering;

const c = @cImport({
    @cInclude("primitives/string.h");
});

pub const String = extern struct {
    const Self = @This();

    inner: ?*anyopaque = null,

    pub const Error = error{
        InvalidUtf8,
        IndexOutOfBounds,
    };

    pub fn init(literal: []const u8) Error!Self {
        var cubsString: c.CubsString = undefined;
        const result = c.cubs_string_init(&cubsString, literalToCubsSlice(literal));
        switch (result) {
            c.cubsStringErrorNone => {
                return Self{ .inner = cubsString._inner };
            },
            c.cubsStringErrorInvalidUtf8 => {
                return Error.InvalidUtf8;
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn initUnchecked(literal: []const u8) Self {
        return Self{ .inner = c.cubs_string_init_unchecked(literalToCubsSlice(literal))._inner };
    }

    pub fn deinit(self: *Self) void {
        c.cubs_string_deinit(@ptrCast(self));
    }

    pub fn clone(self: *const Self) Self {
        return Self{ .inner = c.cubs_string_clone(@ptrCast(self))._inner };
    }

    pub fn find(self: *const Self, literal: []const u8, startIndex: usize) ?usize {
        const result: usize = c.cubs_string_find(@ptrCast(self), literalToCubsSlice(literal), @intCast(startIndex));
        if (result == c.CUBS_STRING_N_POS) {
            return null;
        }
        return @intCast(result);
    }

    fn literalToCubsSlice(literal: []const u8) c.CubsStringSlice {
        return c.CubsStringSlice{ .str = literal.ptr, .len = literal.len };
    }
};

test "init" {
    {
        var s = try String.init("hello world!");
        defer s.deinit();
    }
    { // invalid utf8
        try std.testing.expectError(String.Error.InvalidUtf8, String.init("erm\xFFFF"));
    }
    {
        var s = String.initUnchecked("hello world!");
        defer s.deinit();
    }
}

test "clone" {
    var s = String.initUnchecked("hello world!");
    defer s.deinit();

    var clone = s.clone();
    defer clone.deinit();
}
