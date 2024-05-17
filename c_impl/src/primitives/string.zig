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

    fn literalToCubsSlice(literal: []const u8) c.CubsStringSlice {
        return c.CubsStringSlice{ .str = literal.ptr, .len = literal.len };
    }
};

test "erm" {
    var s = String.initUnchecked("hello world!");
    defer s.deinit();

    var clone = s.clone();
    defer clone.deinit();
}
