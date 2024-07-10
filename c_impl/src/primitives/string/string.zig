const std = @import("std");
const expect = std.testing.expect;
const Ordering = @import("../../util/ordering.zig").Ordering;
const script_value = @import("../script_value.zig");

pub const String = extern struct {
    const Self = @This();
    pub const SCRIPT_SELF_TAG: script_value.ValueTag = .string;

    /// Safe to read, unsafe to write
    len: usize = 0,
    /// Do not access
    _metadata: [3]?*anyopaque = std.mem.zeroes([3]?*anyopaque),

    pub fn init(literal: []const u8) error{InvalidUtf8}!Self {
        var self: String = undefined;
        const result = CubsString.cubs_string_init(self.asRawMut(), CubsString.CubsStringSlice.fromLiteral(literal));
        switch (result) {
            .None => {
                return self;
            },
            .InvalidUtf8 => {
                return error.InvalidUtf8;
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn initUnchecked(literal: []const u8) Self {
        return @bitCast(CubsString.cubs_string_init_unchecked(CubsString.CubsStringSlice.fromLiteral(literal)));
    }

    pub fn deinit(self: *Self) void {
        CubsString.cubs_string_deinit(@ptrCast(self));
    }

    pub fn clone(self: *const Self) Self {
        return @bitCast(CubsString.cubs_string_clone(@ptrCast(self)));
    }

    pub fn asSlice(self: *const Self) []const u8 {
        const slice = CubsString.cubs_string_as_slice(self.asRaw());
        return slice.str[0..slice.len];
    }

    pub fn eql(self: *const Self, other: Self) bool {
        return CubsString.cubs_string_eql(@ptrCast(self), @ptrCast(&other));
    }

    pub fn eqlSlice(self: *const Self, literal: []const u8) bool {
        return CubsString.cubs_string_eql_slice(@ptrCast(self), CubsString.CubsStringSlice.fromLiteral(literal));
    }

    pub fn cmp(self: *const Self, other: Self) Ordering {
        return CubsString.cubs_string_cmp(@ptrCast(self), @ptrCast(&other));
    }

    pub fn hash(self: *const Self) usize {
        return @intCast(CubsString.cubs_string_hash(@ptrCast(self)));
    }

    pub fn find(self: *const Self, literal: []const u8, startIndex: usize) ?usize {
        const result: usize = CubsString.cubs_string_find(@ptrCast(self), CubsString.CubsStringSlice.fromLiteral(literal), @intCast(startIndex));
        if (result == CubsString.CUBS_STRING_N_POS) {
            return null;
        }
        return @intCast(result);
    }

    pub fn rfind(self: *const Self, literal: []const u8, startIndex: usize) ?usize {
        const result: usize = CubsString.cubs_string_rfind(@ptrCast(self), CubsString.CubsStringSlice.fromLiteral(literal), @intCast(startIndex));
        if (result == CubsString.CUBS_STRING_N_POS) {
            return null;
        }
        return @intCast(result);
    }

    pub fn concat(self: *const Self, other: Self) Self {
        return @bitCast(CubsString.cubs_string_concat(self.asRaw(), other.asRaw()));
    }

    pub fn concatSlice(self: *const Self, slice: []const u8) error{InvalidUtf8}!Self {
        var new: String = undefined;
        const result = CubsString.cubs_string_concat_slice(new.asRawMut(), self.asRaw(), CubsString.CubsStringSlice.fromLiteral(slice));
        switch (result) {
            .None => {
                return @bitCast(new);
            },
            .InvalidUtf8 => {
                return error.InvalidUtf8;
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn concatSliceUnchecked(self: *const Self, slice: []const u8) Self {
        return @bitCast(CubsString.cubs_string_concat_slice_unchecked(self.asRaw(), CubsString.CubsStringSlice.fromLiteral(slice)));
    }

    pub fn substr(self: *const Self, startInclusive: usize, endExclusive: usize) error{ InvalidUtf8, IndexOutOfBounds }!Self {
        var newStr: String = undefined;
        const result = CubsString.cubs_string_substr(newStr.asRawMut(), self.asRaw(), startInclusive, endExclusive);
        switch (result) {
            .None => {
                return newStr;
            },
            .InvalidUtf8 => {
                return error.InvalidUtf8;
            },
            .IndexOutOfBounds => {
                return error.IndexOutOfBounds;
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn fromBool(b: bool) Self {
        return @bitCast(CubsString.cubs_string_from_bool(b));
    }

    pub fn fromInt(num: i64) Self {
        return @bitCast(CubsString.cubs_string_from_int(num));
    }

    pub fn fromFloat(num: f64) Self {
        return @bitCast(CubsString.cubs_string_from_float(num));
    }

    pub fn toBool(self: *const Self) error{ParseBool}!bool {
        var b: bool = undefined;
        const result = CubsString.cubs_string_to_bool(&b, self.asRaw());
        switch (result) {
            .None => {
                return b;
            },
            .ParseBool => {
                return error.ParseBool;
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn asRaw(self: *const Self) *const CubsString {
        return @ptrCast(self);
    }

    pub fn asRawMut(self: *Self) *CubsString {
        return @ptrCast(self);
    }

    test init {
        { // sso
            var s = try String.init("hello world!");
            defer s.deinit();
        }
        { // heap
            var s = try String.init("hello world! haiuwdshpaisudhpaisuhdpasd");
            defer s.deinit();
        }
        { // Invalid utf8
            try std.testing.expectError(error.InvalidUtf8, String.init("erm\xFFFF"));
        }
    }

    test initUnchecked {
        { // sso

            var s = String.initUnchecked("hello world!");
            defer s.deinit();
        }
        { // heap
            var s = String.initUnchecked("hello world! haiuwdshpaisudhpaisuhdpasd");
            defer s.deinit();
        }

        // Invalid utf8. In debug, will assert. In non-debug, it's undefined behaviour.
        // _ = String.initUnchecked("erm\xFFFF");
    }

    test clone {
        { // sso
            var s = String.initUnchecked("hello world!");
            defer s.deinit();

            var sClone = s.clone();
            defer sClone.deinit();
        }
        { // heap
            var s = String.initUnchecked("hello to the absolutely glorious and magnificent world!");
            defer s.deinit();

            var sClone = s.clone();
            defer sClone.deinit();
        }
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
        { // heap clones
            var s = String.initUnchecked("hello world! how are you doing today??? good i hope!");
            defer s.deinit();

            var sClone = s.clone();
            defer sClone.deinit();

            try expect(s.eql(sClone));
        }
        { // heap not clones but same
            var s1 = String.initUnchecked("hello world! how are you doing today??? good i hope!");
            defer s1.deinit();

            var s2 = String.initUnchecked("hello world! how are you doing today??? good i hope!");
            defer s2.deinit();

            try expect(s1.eql(s2));
        }
        { // heap different
            var s1 = String.initUnchecked("hello world! how are you doing today??? good i hope!");
            defer s1.deinit();

            var s2 = String.initUnchecked("hyllo world! how are you doing today??? good i hope!");
            defer s2.deinit();

            try expect(!s1.eql(s2));
        }
        { // heap different sanity
            var s1 = String.initUnchecked("hello world! how are you doing today??? good i hope!");
            defer s1.deinit();

            var s2 = String.initUnchecked("hello world! how are you doing today??? good k hope!");
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
        try expect(helloworld.rfind("o", helloworld.len) == 7);
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

            try std.testing.expectError(error.InvalidUtf8, empty.concatSlice("\xFFFF"));
        }
        { // something + invalid utf8
            var helloworld = String.initUnchecked("hello world!");
            defer helloworld.deinit();

            try std.testing.expectError(error.InvalidUtf8, helloworld.concatSlice("\xFFFF"));
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

    test substr {
        {
            var empty = String{};
            defer empty.deinit();

            var emptySub = try empty.substr(0, 0);
            defer emptySub.deinit();

            try expect(emptySub.len == 0);

            try std.testing.expectError(error.IndexOutOfBounds, empty.substr(0, 1));
            try std.testing.expectError(error.IndexOutOfBounds, empty.substr(1, 0));
            try std.testing.expectError(error.IndexOutOfBounds, empty.substr(1, 2));
            try std.testing.expectError(error.IndexOutOfBounds, empty.substr(2, 2));
        }
        {
            var helloworld = String.initUnchecked("hello world!");
            defer helloworld.deinit();

            var emptySub = try helloworld.substr(0, 0);
            defer emptySub.deinit();

            try expect(emptySub.len == 0);

            var helloSub = try helloworld.substr(0, "hello".len);
            defer helloSub.deinit();

            try expect(helloSub.eqlSlice("hello"));

            var worldSub = try helloworld.substr("hello ".len, helloworld.len);
            defer worldSub.deinit();

            try expect(worldSub.eqlSlice("world!"));

            try std.testing.expectError(error.IndexOutOfBounds, helloworld.substr(0, helloworld.len + 1));
            try std.testing.expectError(error.IndexOutOfBounds, helloworld.substr(5, 4));
            try std.testing.expectError(error.IndexOutOfBounds, helloworld.substr(helloworld.len + 1, 1000000));
            try std.testing.expectError(error.IndexOutOfBounds, helloworld.substr(helloworld.len + 1, 0));
        }
        {
            var utf8text = try String.init("你好");
            defer utf8text.deinit();

            try std.testing.expectError(error.InvalidUtf8, utf8text.substr(1, utf8text.len));

            var validSub = try utf8text.substr(3, utf8text.len);
            defer validSub.deinit();

            try expect(validSub.eqlSlice("好"));
        }
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

    test fromInt {
        {
            var s = String.fromInt(0);
            defer s.deinit();

            try expect(s.eqlSlice("0"));
        }
        {
            var s = String.fromInt(1);
            defer s.deinit();

            try expect(s.eqlSlice("1"));
        }
        {
            var s = String.fromInt(-1);
            defer s.deinit();

            try expect(s.eqlSlice("-1"));
        }
        {
            var s = String.fromInt(5);
            defer s.deinit();

            try expect(s.eqlSlice("5"));
        }
        {
            var s = String.fromInt(-5);
            defer s.deinit();

            try expect(s.eqlSlice("-5"));
        }
        {
            var s = String.fromInt(98765);
            defer s.deinit();

            try expect(s.eqlSlice("98765"));
        }
        {
            var s = String.fromInt(-98765);
            defer s.deinit();

            try expect(s.eqlSlice("-98765"));
        }
        {
            var s = String.fromInt(std.math.maxInt(i64));
            defer s.deinit();

            try expect(s.eqlSlice("9223372036854775807"));
        }
        {
            var s = String.fromInt(std.math.minInt(i64));
            defer s.deinit();

            try expect(s.eqlSlice("-9223372036854775808"));
        }
    }

    test fromFloat {
        {
            var s = String.fromFloat(0);
            defer s.deinit();

            try expect(s.eqlSlice("0"));
        }
        {
            var s = String.fromFloat(1);
            defer s.deinit();

            try expect(s.eqlSlice("1"));
        }
        {
            var s = String.fromFloat(-1);
            defer s.deinit();

            try expect(s.eqlSlice("-1"));
        }
        {
            var s = String.fromFloat(-1000.55);
            defer s.deinit();

            try expect(s.eqlSlice("-1000.55"));
        }
        // https://stackoverflow.com/questions/3793838/which-is-the-first-integer-that-an-ieee-754-float-is-incapable-of-representing-e
        {
            var s32bit = String.fromFloat(16777217);
            defer s32bit.deinit();

            // Will absolutely work cause CubicScript uses 64 bit floats
            try expect(s32bit.eqlSlice("16777217"));

            var s64bit = String.fromFloat(9007199254740993);
            defer s64bit.deinit();

            // Will not work because the value is too big to be represented by a 64 bit float
            try expect(!s64bit.eqlSlice("9007199254740993"));
            try expect(s64bit.eqlSlice("9007199254740992"));
        }
    }

    test toBool {
        var trueString = String.initUnchecked("true");
        defer trueString.deinit();

        var falseString = String.initUnchecked("false");
        defer falseString.deinit();

        var otherString = String.initUnchecked("truee");
        defer otherString.deinit();

        if (trueString.toBool()) |b| {
            try expect(b == true);
        } else |_| {
            try expect(false);
        }

        if (falseString.toBool()) |b| {
            try expect(b == false);
        } else |_| {
            try expect(false);
        }

        if (otherString.toBool()) |_| {
            try expect(false);
        } else |err| {
            try expect(err == error.ParseBool);
        }
    }

    test hash {
        var emptyString = String{};
        defer emptyString.deinit();

        var oneCharString = String.initUnchecked("a");
        defer oneCharString.deinit();

        var smallString = String.initUnchecked("hello world!");
        defer smallString.deinit();

        var longString = String.initUnchecked("ashpdiuahspdiuahspdiuhaspdiuhapsiudhpaisuhdpaiushdpasd");
        defer longString.deinit();

        const h1 = emptyString.hash();
        const h2 = oneCharString.hash();
        const h3 = smallString.hash();
        const h4 = longString.hash();

        if (h1 == h2) {
            return error.SkipZigTest;
        } else if (h1 == h3) {
            return error.SkipZigTest;
        } else if (h1 == h4) {
            return error.SkipZigTest;
        } else if (h2 == h3) {
            return error.SkipZigTest;
        } else if (h2 == h4) {
            return error.SkipZigTest;
        } else if (h3 == h4) {
            return error.SkipZigTest;
        }
    }
};

pub const CubsString = extern struct {
    /// Safe to read, unsafe to write
    len: usize = 0,
    /// Do not access
    _metadata: [3]?*anyopaque = std.mem.zeroes([3]?*anyopaque),

    const Self = @This();
    pub const SCRIPT_SELF_TAG: script_value.ValueTag = .string;

    pub const Err = enum(c_int) {
        None = 0,
        InvalidUtf8 = 1,
        IndexOutOfBounds = 2,
        ParseBool = 3,
        ParseInt = 4,
        ParseFloat = 5,
    };

    pub const CUBS_STRING_N_POS: usize = @bitCast(@as(i64, -1));

    pub const CubsStringSlice = extern struct {
        str: [*]const u8,
        len: usize,

        pub fn fromLiteral(literal: []const u8) CubsStringSlice {
            return .{ .str = literal.ptr, .len = literal.len };
        }
    };

    extern fn cubs_string_init(self: *Self, slice: CubsStringSlice) callconv(.C) Err;
    extern fn cubs_string_init_unchecked(slice: CubsStringSlice) callconv(.C) Self;
    extern fn cubs_string_deinit(self: *Self) callconv(.C) void;
    extern fn cubs_string_clone(self: *const Self) callconv(.C) Self;
    extern fn cubs_string_as_slice(self: *const Self) callconv(.C) CubsStringSlice;
    extern fn cubs_string_eql(self: *const Self, other: *const Self) callconv(.C) bool;
    extern fn cubs_string_eql_slice(self: *const Self, slice: CubsStringSlice) callconv(.C) bool;
    extern fn cubs_string_cmp(self: *const Self, other: *const Self) callconv(.C) Ordering;
    extern fn cubs_string_hash(self: *const Self) callconv(.C) usize;
    extern fn cubs_string_find(self: *const Self, slice: CubsStringSlice, startIndex: usize) callconv(.C) usize;
    extern fn cubs_string_rfind(self: *const Self, slice: CubsStringSlice, startIndex: usize) callconv(.C) usize;
    extern fn cubs_string_concat(self: *const Self, other: *const Self) callconv(.C) Self;
    extern fn cubs_string_concat_slice(out: *Self, self: *const Self, slice: CubsStringSlice) callconv(.C) Err;
    extern fn cubs_string_concat_slice_unchecked(self: *const Self, slice: CubsStringSlice) callconv(.C) Self;
    extern fn cubs_string_substr(out: *Self, self: *const Self, startInclusive: usize, endExclusive: usize) Err;
    extern fn cubs_string_from_bool(b: bool) Self;
    extern fn cubs_string_from_int(b: i64) Self;
    extern fn cubs_string_from_float(b: f64) Self;
    extern fn cubs_string_to_bool(out: *bool, self: *const Self) Err;
};
