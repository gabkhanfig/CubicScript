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

    pub fn eql(self: *const Self, other: Self) bool {
        return c.cubs_string_eql(@ptrCast(self), @ptrCast(&other));
    }

    pub fn eqlSlice(self: *const Self, literal: []const u8) bool {
        return c.cubs_string_eql_slice(@ptrCast(self), literalToCubsSlice(literal));
    }

    pub fn cmp(self: *const Self, other: Self) Ordering {
        return @enumFromInt(c.cubs_string_cmp(@ptrCast(self), @ptrCast(&other)));
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

    test init {
        // Valid utf8
        var s = try String.init("hello world!");
        defer s.deinit();

        // Invalid utf8
        try std.testing.expectError(String.Error.InvalidUtf8, String.init("erm\xFFFF"));
    }

    test initUnchecked {
        // Valid utf8
        var s = String.initUnchecked("hello world!");
        defer s.deinit();

        // Invalid utf8. In debug, will assert. In non-debug, it's undefined behaviour.
        // _ = String.initUnchecked("erm\xFFFF");
    }

    test clone {
        var s = String.initUnchecked("hello world!");
        defer s.deinit();

        var sClone = s.clone();
        defer sClone.deinit();
    }

    test eql {
        { // empty strings
            var s1 = String{};
            defer s1.deinit();
            var s2 = String{};
            defer s2.deinit();

            try expect(s1.eql(s2));
        }
        { // clones eql
            var s = String.initUnchecked("hello world!");
            defer s.deinit();

            var sClone = s.clone();
            defer sClone.deinit();

            try expect(s.eql(sClone));
        }
        { // not clones, but same string
            var s1 = String.initUnchecked("hello world!");
            defer s1.deinit();
            var s2 = String.initUnchecked("hello world!");
            defer s2.deinit();

            try expect(s1.eql(s2));
        }
        { // different strings
            var s1 = String.initUnchecked("hello world!");
            defer s1.deinit();
            var s2 = String.initUnchecked("hello world! ");
            defer s2.deinit();

            try expect(!s1.eql(s2));
        }
    }

    test cmp {
        var empty1 = String{};
        defer empty1.deinit();
        var empty2 = String{};
        defer empty2.deinit();
        var emptyClone = empty1.clone();
        defer emptyClone.deinit();

        var helloWorld1 = String.initUnchecked("hello world!");
        defer helloWorld1.deinit();
        var helloWorld2 = String.initUnchecked("hello world!");
        defer helloWorld2.deinit();
        var helloWorldClone = helloWorld1.clone();
        defer helloWorldClone.deinit();

        var helloWorldAlt1 = String.initUnchecked("hallo world!");
        defer helloWorldAlt1.deinit();
        var helloWorldAlt2 = String.initUnchecked("hallo world!");
        defer helloWorldAlt2.deinit();
        var helloWorldAltClone = helloWorldAlt1.clone();
        defer helloWorldAltClone.deinit();

        var helloWorldSpace1 = String.initUnchecked("hello world! ");
        defer helloWorldSpace1.deinit();
        var helloWorldSpace2 = String.initUnchecked("hello world! ");
        defer helloWorldSpace2.deinit();
        var helloWorldSpaceClone = helloWorldSpace1.clone();
        defer helloWorldSpaceClone.deinit();

        var helloWorldLong1 = String.initUnchecked("hello to this glorious world!");
        defer helloWorldLong1.deinit();
        var helloWorldLong2 = String.initUnchecked("hello to this glorious world!");
        defer helloWorldLong2.deinit();
        var helloWorldLongClone = helloWorldLong1.clone();
        defer helloWorldLongClone.deinit();

        var helloWorldLongAlt1 = String.initUnchecked("hallo to this glorious world!");
        defer helloWorldLongAlt1.deinit();
        var helloWorldLongAlt2 = String.initUnchecked("hallo to this glorious world!");
        defer helloWorldLongAlt2.deinit();
        var helloWorldLongAltClone = helloWorldLongAlt1.clone();
        defer helloWorldLongAltClone.deinit();

        var helloWorldLongSpace1 = String.initUnchecked("hello to this glorious world! ");
        defer helloWorldLongSpace1.deinit();
        var helloWorldLongSpace2 = String.initUnchecked("hello to this glorious world! ");
        defer helloWorldLongSpace2.deinit();
        var helloWorldLongSpaceClone = helloWorldLongSpace1.clone();
        defer helloWorldLongSpaceClone.deinit();

        try expect(empty1.cmp(empty2) == .Equal);
        try expect(empty1.cmp(emptyClone) == .Equal);
        try expect(empty2.cmp(emptyClone) == .Equal);

        try expect(helloWorld1.cmp(helloWorld2) == .Equal);
        try expect(helloWorld1.cmp(helloWorldClone) == .Equal);
        try expect(helloWorld2.cmp(helloWorldClone) == .Equal);

        try expect(helloWorldAlt1.cmp(helloWorldAlt2) == .Equal);
        try expect(helloWorldAlt1.cmp(helloWorldAltClone) == .Equal);
        try expect(helloWorldAlt2.cmp(helloWorldAltClone) == .Equal);

        try expect(helloWorldSpace1.cmp(helloWorldSpace2) == .Equal);
        try expect(helloWorldSpace1.cmp(helloWorldSpaceClone) == .Equal);
        try expect(helloWorldSpace2.cmp(helloWorldSpaceClone) == .Equal);

        try expect(helloWorldLong1.cmp(helloWorldLong2) == .Equal);
        try expect(helloWorldLong1.cmp(helloWorldLongClone) == .Equal);
        try expect(helloWorldLong2.cmp(helloWorldLongClone) == .Equal);

        try expect(helloWorldLongAlt1.cmp(helloWorldLongAlt2) == .Equal);
        try expect(helloWorldLongAlt1.cmp(helloWorldLongAltClone) == .Equal);
        try expect(helloWorldLongAlt2.cmp(helloWorldLongAltClone) == .Equal);

        try expect(helloWorldLongSpace1.cmp(helloWorldLongSpace2) == .Equal);
        try expect(helloWorldLongSpace1.cmp(helloWorldLongSpaceClone) == .Equal);
        try expect(helloWorldLongSpace2.cmp(helloWorldLongSpaceClone) == .Equal);

        try expect(helloWorld1.cmp(helloWorldAlt1) == .Greater);
        try expect(helloWorldAlt1.cmp(helloWorld1) == .Less);

        try expect(helloWorld1.cmp(helloWorldSpace1) == .Less);
        try expect(helloWorldSpace1.cmp(helloWorld1) == .Greater);

        try expect(helloWorldLong1.cmp(helloWorldLongAlt1) == .Greater);
        try expect(helloWorldLongAlt1.cmp(helloWorldLong1) == .Less);

        try expect(helloWorldLong1.cmp(helloWorldLongSpace1) == .Less);
        try expect(helloWorldLongSpace1.cmp(helloWorldLong1) == .Greater);

        try expect(helloWorld1.cmp(helloWorldLong1) == .Greater);
        try expect(helloWorldLong1.cmp(helloWorld1) == .Less);
    }
};
