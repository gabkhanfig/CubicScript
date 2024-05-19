const std = @import("std");
const expect = std.testing.expect;
const Ordering = @import("../util/ordering.zig").Ordering;

// const c = @cImport({
//     @cInclude("primitives/string.h");
// });

// Importing the header directly really messes with the language server, so this is simpler
const c = struct {
    const Err = enum(c_int) {
        None = 0,
        InvalidUtf8 = 1,
        IndexOutOfBounds = 2,
    };

    const CUBS_STRING_N_POS: usize = @bitCast(@as(i64, -1));

    const Slice = extern struct {
        str: [*]const u8,
        len: usize,

        fn fromLiteral(literal: []const u8) Slice {
            return .{ .str = literal.ptr, .len = literal.len };
        }
    };

    extern fn cubs_string_init(self: *String, slice: Slice) callconv(.C) c.Err;
    extern fn cubs_string_init_unchecked(slice: Slice) callconv(.C) String;
    extern fn cubs_string_deinit(self: *String) callconv(.C) void;
    extern fn cubs_string_clone(self: *const String) callconv(.C) String;
    extern fn cubs_string_len(self: *const String) callconv(.C) usize;
    extern fn cubs_string_as_slice(self: *const String) callconv(.C) Slice;
    extern fn cubs_string_eql(self: *const String, other: *const String) callconv(.C) bool;
    extern fn cubs_string_eql_slice(self: *const String, slice: Slice) callconv(.C) bool;
    extern fn cubs_string_cmp(self: *const String, other: *const String) callconv(.C) Ordering;
    extern fn cubs_string_hash(self: *const String) callconv(.C) usize;
    extern fn cubs_string_find(self: *const String, slice: Slice, startIndex: usize) callconv(.C) usize;
    extern fn cubs_string_rfind(self: *const String, slice: Slice, startIndex: usize) callconv(.C) usize;
    extern fn cubs_string_concat(self: *const String, other: *const String) callconv(.C) String;
    extern fn cubs_string_concat_slice(out: *String, self: *const String, slice: Slice) callconv(.C) c.Err;
    extern fn cubs_string_concat_slice_unchecked(self: *const String, slice: Slice) callconv(.C) String;
    extern fn cubs_string_from_bool(b: bool) String;
};

pub const String = extern struct {
    const Self = @This();

    inner: ?*anyopaque = null,

    pub const Error = error{
        InvalidUtf8,
        IndexOutOfBounds,
    };

    pub fn init(literal: []const u8) Error!Self {
        var self: String = undefined;
        const result = c.cubs_string_init(&self, c.Slice.fromLiteral(literal));
        switch (result) {
            .None => {
                return self;
            },
            .InvalidUtf8 => {
                return Error.InvalidUtf8;
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn initUnchecked(literal: []const u8) Self {
        return c.cubs_string_init_unchecked(c.Slice.fromLiteral(literal));
    }

    pub fn deinit(self: *Self) void {
        c.cubs_string_deinit(@ptrCast(self));
    }

    pub fn clone(self: *const Self) Self {
        return c.cubs_string_clone(@ptrCast(self));
    }

    pub fn len(self: *const Self) usize {
        return c.cubs_string_len(self);
    }

    pub fn asSlice(self: *const Self) []const u8 {
        const slice = c.cubs_string_as_slice(self);
        return slice.str[0..slice.len];
    }

    pub fn eql(self: *const Self, other: Self) bool {
        return c.cubs_string_eql(@ptrCast(self), @ptrCast(&other));
    }

    pub fn eqlSlice(self: *const Self, literal: []const u8) bool {
        return c.cubs_string_eql_slice(@ptrCast(self), c.Slice.fromLiteral(literal));
    }

    pub fn cmp(self: *const Self, other: Self) Ordering {
        return c.cubs_string_cmp(@ptrCast(self), @ptrCast(&other));
    }

    pub fn hash(self: *const Self) usize {
        return @intCast(c.cubs_string_hash(@ptrCast(self)));
    }

    pub fn find(self: *const Self, literal: []const u8, startIndex: usize) ?usize {
        const result: usize = c.cubs_string_find(@ptrCast(self), c.Slice.fromLiteral(literal), @intCast(startIndex));
        if (result == c.CUBS_STRING_N_POS) {
            return null;
        }
        return @intCast(result);
    }

    pub fn rfind(self: *const Self, literal: []const u8, startIndex: usize) ?usize {
        const result: usize = c.cubs_string_rfind(@ptrCast(self), c.Slice.fromLiteral(literal), @intCast(startIndex));
        if (result == c.CUBS_STRING_N_POS) {
            return null;
        }
        return @intCast(result);
    }

    pub fn concat(self: *const Self, other: Self) Self {
        return c.cubs_string_concat(self, &other);
    }

    pub fn concatSlice(self: *const Self, slice: []const u8) Error!Self {
        var new: String = undefined;
        const result = c.cubs_string_concat_slice(&new, self, c.Slice.fromLiteral(slice));
        switch (result) {
            .None => {
                return new;
            },
            .InvalidUtf8 => {
                return Error.InvalidUtf8;
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn concatSliceUnchecked(self: *const Self, slice: []const u8) Self {
        return c.cubs_string_concat_slice_unchecked(self, c.Slice.fromLiteral(slice));
    }

    pub fn fromBool(b: bool) Self {
        return c.cubs_string_from_bool(b);
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

        try expect(empty1.cmp(empty2) == .Equal);
        try expect(empty1.cmp(emptyClone) == .Equal);
        try expect(empty2.cmp(emptyClone) == .Equal);

        var helloWorld1 = String.initUnchecked("hello world!");
        defer helloWorld1.deinit();
        var helloWorld2 = String.initUnchecked("hello world!");
        defer helloWorld2.deinit();
        var helloWorldClone = helloWorld1.clone();
        defer helloWorldClone.deinit();

        try expect(helloWorld1.cmp(helloWorld2) == .Equal);
        try expect(helloWorld1.cmp(helloWorldClone) == .Equal);
        try expect(helloWorld2.cmp(helloWorldClone) == .Equal);

        var helloWorldAlt1 = String.initUnchecked("hallo world!");
        defer helloWorldAlt1.deinit();
        var helloWorldAlt2 = String.initUnchecked("hallo world!");
        defer helloWorldAlt2.deinit();
        var helloWorldAltClone = helloWorldAlt1.clone();
        defer helloWorldAltClone.deinit();

        try expect(helloWorldAlt1.cmp(helloWorldAlt2) == .Equal);
        try expect(helloWorldAlt1.cmp(helloWorldAltClone) == .Equal);
        try expect(helloWorldAlt2.cmp(helloWorldAltClone) == .Equal);

        try expect(helloWorld1.cmp(helloWorldAlt1) == .Greater);
        try expect(helloWorldAlt1.cmp(helloWorld1) == .Less);

        var helloWorldSpace1 = String.initUnchecked("hello world! ");
        defer helloWorldSpace1.deinit();
        var helloWorldSpace2 = String.initUnchecked("hello world! ");
        defer helloWorldSpace2.deinit();
        var helloWorldSpaceClone = helloWorldSpace1.clone();
        defer helloWorldSpaceClone.deinit();

        try expect(helloWorldSpace1.cmp(helloWorldSpace2) == .Equal);
        try expect(helloWorldSpace1.cmp(helloWorldSpaceClone) == .Equal);
        try expect(helloWorldSpace2.cmp(helloWorldSpaceClone) == .Equal);

        try expect(helloWorld1.cmp(helloWorldSpace1) == .Less);
        try expect(helloWorldSpace1.cmp(helloWorld1) == .Greater);
    }

    test find {
        var empty = String{};
        defer empty.deinit();

        try expect(empty.find("", 0) == null);
        try expect(empty.find("", 1) == null);
        try expect(empty.find("A", 0) == null);
        try expect(empty.find("A", 1) == null);

        var helloworld = String.initUnchecked("hello world!");
        defer helloworld.deinit();

        try expect(helloworld.find("", 0) == null);
        try expect(helloworld.find("", 1) == null);
        try expect(helloworld.find("o", 0) == 4);
        try expect(helloworld.find("o", 5) == 7);
        try expect(helloworld.find("o", 8) == null);
    }

    test rfind {
        var empty = String{};
        defer empty.deinit();

        try expect(empty.rfind("", 0) == null);
        try expect(empty.rfind("", 1) == null);
        try expect(empty.rfind("A", 0) == null);
        try expect(empty.rfind("A", 1) == null);

        var helloworld = String.initUnchecked("hello world!");
        defer helloworld.deinit();

        try expect(helloworld.rfind("", 0) == null);
        try expect(helloworld.rfind("", 1) == null);
        try expect(helloworld.rfind("o", helloworld.len()) == 7);
        try expect(helloworld.rfind("o", 5) == 4);
        try expect(helloworld.rfind("o", 1) == null);
    }

    test concat {
        var empty = String{};
        defer empty.deinit();
        var helloworld = String.initUnchecked("hello world!");
        defer helloworld.deinit();
        var erm = String.initUnchecked("erm... ");
        defer erm.deinit();

        { // empty + something
            var concatenated = empty.concat(helloworld);
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "hello world!"));
        }
        { // something + empty
            var concatenated = helloworld.concat(empty);
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "hello world!"));
        }
        { // something + something
            var concatenated = erm.concat(helloworld);
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "erm... hello world!"));
        }
    }

    test concatSlice {
        { // empty + something
            var empty = String{};
            defer empty.deinit();

            var concatenated = try empty.concatSlice("hello world!");
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "hello world!"));
        }
        { // something + empty
            var helloworld = String.initUnchecked("hello world!");
            defer helloworld.deinit();

            var concatenated = try helloworld.concatSlice("");
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "hello world!"));
        }
        { // something + something
            var erm = String.initUnchecked("erm... ");
            defer erm.deinit();

            var concatenated = try erm.concatSlice("hello world!");
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "erm... hello world!"));
        }
        { // empty + invalid utf8
            var empty = String{};
            defer empty.deinit();

            try std.testing.expectError(String.Error.InvalidUtf8, empty.concatSlice("\xFFFF"));
        }
        { // something + invalid utf8
            var helloworld = String.initUnchecked("hello world!");
            defer helloworld.deinit();

            try std.testing.expectError(String.Error.InvalidUtf8, helloworld.concatSlice("\xFFFF"));
        }
    }

    test concatSliceUnchecked {
        { // empty + something
            var empty = String{};
            defer empty.deinit();

            var concatenated = empty.concatSliceUnchecked("hello world!");
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "hello world!"));
        }
        { // something + empty
            var helloworld = String.initUnchecked("hello world!");
            defer helloworld.deinit();

            var concatenated = helloworld.concatSliceUnchecked("");
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "hello world!"));
        }
        { // something + something
            var erm = String.initUnchecked("erm... ");
            defer erm.deinit();

            var concatenated = erm.concatSliceUnchecked("hello world!");
            defer concatenated.deinit();

            try expect(std.mem.eql(u8, concatenated.asSlice(), "erm... hello world!"));
        }
        // doing invalid utf8 will result in a panic
    }

    test fromBool {
        var strTrue = String.fromBool(true);
        defer strTrue.deinit();

        try expect(std.mem.eql(u8, strTrue.asSlice(), "true"));

        var strFalse = String.fromBool(false);
        defer strFalse.deinit();

        try expect(std.mem.eql(u8, strFalse.asSlice(), "false"));
        { // validate equal to normally created
            var trueTest = String.initUnchecked("true");
            defer trueTest.deinit();

            try expect(strTrue.eql(trueTest));

            var falseTest = String.initUnchecked("false");
            defer falseTest.deinit();

            try expect(strFalse.eql(falseTest));
        }
    }
};
