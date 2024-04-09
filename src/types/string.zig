const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const AtomicRefCount = @import("atomic_ref_count.zig").AtomicRefCount;
const root = @import("../root.zig");
const Int = i64;
const ValueTag = root.ValueTag;
const CubicScriptState = @import("../state/CubicScriptState.zig");
const allocator = @import("../state/global_allocator.zig").allocator;

/// Immutable, ref counted string. This is the string implementation for scripts.
/// Corresponds with the struct `CubsString` in `cubic_script.h`.
pub const String = extern struct {
    const Self = @This();

    /// If null, is just an empty string. This makes 0 initization viable.
    /// TODO does this need to be atomic? It's possible one thread reads while another deinits on the same String reference (not inner reference)?
    inner: ?*anyopaque = null,

    pub fn initSlice(slice: []const u8) Self {
        assert(slice.len != 0);

        const inner = Inner.initSlice(slice);
        return Self{ .inner = @ptrCast(inner) };
    }

    pub fn clone(self: Self) Self {
        if (self.inner == null) {
            return Self{ .inner = null };
        } else {
            var selfCopy = self; // should be optimized by LLVM
            selfCopy.asInnerMut().incrementRefCount();
            return Self{ .inner = self.inner };
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.inner != null) {
            const inner = self.asInnerMut();
            self.inner = null;
            inner.decrementRefCount();
        }
    }

    pub fn len(self: *const Self) Int {
        if (self.inner == null) {
            return 0;
        } else {
            return @intCast(self.asInner().lenAndFlag & ~Inner.FLAG_BIT);
        }
    }

    pub fn toSlice(self: *const Self) [:0]const u8 {
        if (self.inner == null) {
            return "";
        } else {
            const length = self.asInner().lenAndFlag & ~Inner.FLAG_BIT;
            if (self.asInner().isSso()) {
                return self.asInner().rep.sso.chars[0..length :0];
            } else {
                return self.asInner().rep.heap.data[0..length :0];
            }
        }
    }

    pub fn eql(self: *const Self, other: Self) bool {
        if (self.inner == other.inner) {
            return true;
        }

        if (self.inner == null) { // other must not be null.
            return other.len() == 0;
        }

        // Both are validated as non-null now
        if (!self.asInner().isSso() and !other.asInner().isSso()) {
            const selfLength = self.len();
            const otherLength = other.len();
            if (selfLength != otherLength) {
                return false;
            }

            const Optimal = struct {
                var func: *const fn (selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) callconv(.C) bool = undefined;
                var once = std.once(@This().assignFunc);

                fn assignFunc() void {
                    func = blk: {
                        if (string_simd_x86.is_avx512f_supported()) {
                            break :blk string_simd_x86.avx512CompareEqualStringAndString;
                        } else if (string_simd_x86.is_avx2_supported()) {
                            break :blk string_simd_x86.avx2CompareEqualStringAndString;
                        } else {
                            @panic("Required AVX-512 or AVX-2");
                        }
                    };
                }
            };

            Optimal.once.call();

            return Optimal.func(
                @ptrCast(self.asInner().rep.heap.data),
                @ptrCast(other.asInner().rep.heap.data),
                @intCast(selfLength),
            );
        }
        return std.mem.eql(u8, self.toSlice(), other.toSlice());
    }

    pub fn eqlSlice(self: *const Self, other: [:0]const u8) bool {
        if (self.inner == null) {
            return other.len == 0;
        }

        if (!self.asInner().isSso()) {
            if (self.len() != other.len) {
                return false;
            }

            const Optimal = struct {
                var func: *const fn (selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) callconv(.C) bool = undefined;
                var once = std.once(@This().assignFunc);

                fn assignFunc() void {
                    func = blk: {
                        if (string_simd_x86.is_avx512f_supported()) {
                            break :blk string_simd_x86.avx512CompareEqualStringAndSlice;
                        } else if (string_simd_x86.is_avx2_supported()) {
                            break :blk string_simd_x86.avx2CompareEqualStringAndSlice;
                        } else {
                            @panic("Required AVX-512 or AVX-2");
                        }
                    };
                }
            };

            Optimal.once.call();

            return Optimal.func(
                @ptrCast(self.asInner().rep.heap.data),
                @ptrCast(other.ptr),
                @intCast(other.len),
            );
        }

        return std.mem.eql(u8, self.toSlice(), other);
    }

    pub fn cmp(self: *const Self, other: Self) root.Ordering {
        if (self.inner == other.inner) {
            return .Equal;
        }

        if (self.inner == null and other.len() == 0) { // other must not be null.
            return .Equal;
        }

        // Now both are non-null
        // TODO simd
        const selfSlice = self.toSlice();
        const otherSlice = other.toSlice();
        if (selfSlice.len == otherSlice.len) {
            for (selfSlice, otherSlice) |selfChar, otherChar| {
                if (selfChar == otherChar) {
                    continue;
                } else if (selfChar < otherChar) {
                    return .Less;
                } else {
                    return .Greater;
                }
            }
            return .Equal;
        } else {
            const lengthToCheck = @max(selfSlice.len, otherSlice.len);
            for (0..lengthToCheck) |i| {
                const selfChar: u8 = blk: {
                    if (i >= selfSlice.len) {
                        break :blk 0;
                    } else {
                        break :blk selfSlice[i];
                    }
                };
                const otherChar: u8 = blk: {
                    if (i >= otherSlice.len) {
                        break :blk 0;
                    } else {
                        break :blk otherSlice[i];
                    }
                };
                if (selfChar == otherChar) {
                    continue;
                } else if (selfChar < otherChar) {
                    return .Less;
                } else {
                    return .Greater;
                }
            }
            return .Equal;
        }
    }

    pub fn hash(self: *const Self) usize {
        const slice = self.toSlice();
        return string_simd_x86.cubs_string_compute_hash_simd(@ptrCast(slice.ptr), @intCast(slice.len));
    }

    pub fn find(self: *const Self, literal: [:0]const u8) ?Int {
        if (self.inner == null or literal.len == 0) {
            return null;
        } else {
            const selfBuffer = self.toSlice();
            if (self.asInner().isSso()) {
                const index = std.mem.indexOf(u8, selfBuffer, literal);
                if (index) |i| {
                    return @intCast(i);
                } else {
                    return null;
                }
            } else {
                const Optimal = struct {
                    var func: *const fn (selfBuffer: [*c]const u8, selfLength: c_ulonglong, sliceBuffer: [*c]const u8, sliceLength: c_ulonglong) callconv(.C) c_ulonglong = string_simd_x86.avx512FindStrSliceInString;
                };

                const result = Optimal.func(
                    @ptrCast(selfBuffer.ptr),
                    @intCast(selfBuffer.len),
                    @ptrCast(literal.ptr),
                    @intCast(literal.len),
                );
                const NOT_FOUND = ~@as(c_ulonglong, 0);
                if (result == NOT_FOUND) {
                    return null;
                } else {
                    return @intCast(result);
                }
            }
        }
    }

    pub fn rfind(self: *const Self, literal: [:0]const u8) ?usize {
        if (self.inner == null or literal.len == 0) {
            return null;
        } else {
            const selfBuffer = self.toSlice();
            const index = std.mem.lastIndexOf(u8, selfBuffer, literal);
            if (index) |i| {
                return i;
            } else {
                return null;
            }
        }
    }

    pub fn fromScriptValue(value: root.TaggedValueConstRef) Self {
        switch (value.tag) {
            .Bool => {
                return Self.fromBool(value.value.boolean);
            },
            .Int => {
                return Self.fromInt(value.value.int);
            },
            .Float => {},
            else => {
                @panic("unsupported");
            },
        }
    }

    // append
    // substr
    // split
    // insert
    // remove
    // toInt
    // toFloat
    // fromInt
    // fromFloat

    pub fn fromBool(boolean: bool) Self {
        if (boolean) {
            return Self.initSlice("true");
        } else {
            return Self.initSlice("false");
        }
    }

    pub fn fromInt(num: Int) Self {
        if (num == 0) {
            return Self.initSlice("0"); // TODO can the 0 string become a global?
        }

        var numLocal = num;

        //onst digits = "9876543210123456789";
        const digits = "1234567890123456789";
        const zeroDigit = 9;
        const maxChars = 20;

        var tempNums: [maxChars]u8 = undefined;
        var tempAt: usize = maxChars;

        while (numLocal != 0) {
            tempAt -= 1;
            const index: usize = @intCast(@mod(numLocal, 10));
            if (num < 0) { // can this conditional be avoided? maybe
                tempNums[tempAt] = digits[zeroDigit - index];
            } else {
                tempNums[tempAt] = digits[zeroDigit + index];
            }
            numLocal = @divTrunc(numLocal, 10);
        }
        if (num < 0) {
            tempAt -= 1;
            tempNums[tempAt] = '-';
        }

        const length: usize = maxChars - tempAt;
        return Self.initSlice(tempNums[tempAt..][0..length]);
    }

    fn asInner(self: Self) *const Inner {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asInnerMut(self: *Self) *Inner {
        return @ptrCast(@alignCast(self.inner));
    }

    const Inner = extern struct {
        const FLAG_BIT: usize = @shlExact(1, 63);

        refCount: AtomicRefCount = AtomicRefCount{},
        lenAndFlag: usize,
        rep: StringRep = undefined,

        fn incrementRefCount(self: *Inner) void {
            self.refCount.addRef();
        }

        fn decrementRefCount(self: *Inner) void {
            if (!self.refCount.removeRef()) {
                return;
            }

            if (!self.isSso()) {
                allocator().free(self.rep.heap.data[0..(self.rep.heap.allocationSize - 1) :0]);
                self.rep.heap.data = undefined;
                self.rep.heap.allocationSize = 0;
            }
            allocator().destroy(self);
        }

        fn isSso(self: *const Inner) bool {
            return self.lenAndFlag & FLAG_BIT == 0;
        }

        fn initSlice(slice: []const u8) *Inner {
            const self = allocator().create(Inner) catch {
                @panic("Script out of memory");
            };

            self.* = Inner{ .lenAndFlag = slice.len };
            self.refCount.addRef();
            self.ensureTotalCapacity(slice.len + 1);

            if (self.isSso()) {
                for (0..slice.len) |i| {
                    self.rep.sso.chars[i] = slice[i];
                }
            } else {
                for (0..slice.len) |i| {
                    self.rep.heap.data[i] = slice[i];
                }
            }
            return self;
        }

        /// Can only be executed once per instance.
        fn ensureTotalCapacity(self: *Inner, minCapacity: usize) void {
            // The strings are immutable, so cannot override.
            // This check ensures long strings don't get overridden, which can be caught by tests.
            //assert(!self.isSso());

            if (minCapacity < SsoRep.MAX_LEN) {
                self.rep = StringRep.default();
                return;
            }

            var mallocCapacity = minCapacity;
            const remainder = @mod(mallocCapacity, 64);
            if (remainder != 0) {
                mallocCapacity = mallocCapacity + (64 - remainder);
            }
            const newSlice: []align(64) u8 = allocator().alignedAlloc(u8, 64, mallocCapacity) catch {
                @panic("Script out of memory");
            };
            @memset(newSlice, 0);
            self.rep.heap.data = @ptrCast(newSlice.ptr);
            self.rep.heap.allocationSize = mallocCapacity;
            self.lenAndFlag |= FLAG_BIT;
            assert(!self.isSso());
        }

        const StringRep = extern union {
            sso: SsoRep,
            heap: HeapRep,

            fn default() StringRep {
                return StringRep{ .sso = SsoRep{} };
            }
        };

        const SsoRep = extern struct {
            const MAX_LEN = 15;

            chars: [16:0]u8 = std.mem.zeroes([16:0]u8),
        };

        const HeapRep = extern struct {
            data: [*:0]align(64) u8,
            allocationSize: usize,
        };
    };

    // /// See string_simd.cpp
    const string_simd_x86 = struct {
        extern fn is_avx512f_supported() callconv(.C) bool;
        extern fn is_avx2_supported() callconv(.C) bool;
        extern fn avx512CompareEqualStringAndString(selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) callconv(.C) bool;
        extern fn avx2CompareEqualStringAndString(selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) callconv(.C) bool;
        extern fn avx512CompareEqualStringAndSlice(selfBuffer: [*c]const u8, sliceBuffer: [*c]const u8, sliceLength: c_ulonglong) callconv(.C) bool;
        extern fn avx2CompareEqualStringAndSlice(selfBuffer: [*c]const u8, sliceBuffer: [*c]const u8, sliceLength: c_ulonglong) callconv(.C) bool;
        // extern fn cubs_string_compare_equal_strings_simd_heap_rep(selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) bool;
        // extern fn cubs_string_compare_equal_string_and_slice_simd_heap_rep(selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) bool;
        extern fn cubs_string_compute_hash_simd(selfBuffer: [*c]const u8, len: c_ulonglong) callconv(.C) c_ulonglong;
        extern fn avx512FindStrSliceInString(selfBuffer: [*c]const u8, selfLength: c_ulonglong, sliceBuffer: [*c]const u8, sliceLength: c_ulonglong) callconv(.C) c_ulonglong;
        //extern fn cubs_string_find_str_slice(selfBuffer: [*c]const u8, selfLength: c_ulonglong, sliceBuffer: [*c]const u8, sliceLength: c_ulonglong) c_ulonglong;
    };
};

test "String default init" {
    const s = String{};
    try expect(s.len() == 0);
    try expect(std.mem.eql(u8, s.toSlice(), ""));
}

test "String from slice" {
    var state = try CubicScriptState.init(std.testing.allocator, null);
    defer state.deinit();
    {
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.len() == 12);
        try expect(std.mem.eql(u8, s.toSlice(), "hello world!"));
    }
    {
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.len() == 29);
        try expect(std.mem.eql(u8, s.toSlice(), "hello to this glorious world!"));
    }
}

test "String clone" {
    var state = try CubicScriptState.init(std.testing.allocator, null);
    defer state.deinit();
    {
        var s1 = String.initSlice("hello world!");
        defer s1.deinit();

        var s2 = s1.clone();
        defer s2.deinit();

        try expect(s1.inner == s2.inner);
        try expect(std.mem.eql(u8, s1.toSlice(), "hello world!"));
        try expect(std.mem.eql(u8, s2.toSlice(), "hello world!"));
    }
    {
        var s1 = String.initSlice("hello to this glorious world!");
        defer s1.deinit();

        var s2 = s1.clone();
        defer s2.deinit();

        try expect(s1.inner == s2.inner);
        try expect(std.mem.eql(u8, s1.toSlice(), "hello to this glorious world!"));
        try expect(std.mem.eql(u8, s2.toSlice(), "hello to this glorious world!"));
    }
}

test "String clone thread safety" {
    var state = try CubicScriptState.init(std.testing.allocator, null);
    defer state.deinit();

    const TestThreadHandler = struct {
        fn makeClonesNTimes(ref: *String, n: usize) void {
            for (0..n) |_| {
                var s1 = ref.clone();
                defer s1.deinit();
                var s2 = ref.clone();
                defer s2.deinit();
                var s3 = ref.clone();
                defer s3.deinit();
                var s4 = ref.clone();
                defer s4.deinit();
            }
        }
    };

    {
        var s = String.initSlice("hello world!");
        defer s.deinit();

        const t1 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000 });
        const t2 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000 });
        const t3 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000 });
        const t4 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000 });

        t1.join();
        t2.join();
        t3.join();
        t4.join();
    }
    {
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        const t1 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000 });
        const t2 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000 });
        const t3 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000 });
        const t4 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000 });

        t1.join();
        t2.join();
        t3.join();
        t4.join();
    }
}

test "String equal" {
    { // null
        var s1 = String{};
        defer s1.deinit();
        var s2 = String{};
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // shared reference sso
        var s1 = String.initSlice("hello world!");
        defer s1.deinit();

        var s2 = s1.clone();
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // different reference sso
        var s1 = String.initSlice("hello world!");
        defer s1.deinit();

        var s2 = String.initSlice("hello world!");
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // shared reference heap
        var s1 = String.initSlice("hello to this glorious world!");
        defer s1.deinit();

        var s2 = s1.clone();
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // different reference heap
        var s1 = String.initSlice("hello to this glorious world!");
        defer s1.deinit();

        var s2 = String.initSlice("hello to this glorious world!");
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // not equal one null
        var s1 = String.initSlice("hello world!");
        defer s1.deinit();

        var s2 = String{};
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal one null sanity
        var s1 = String{};
        defer s1.deinit();

        var s2 = String.initSlice("hello world!");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal both sso
        var s1 = String.initSlice("hello world!");
        defer s1.deinit();

        var s2 = String.initSlice("hello warld!");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal both sso sanity
        var s1 = String.initSlice("hello world!");
        defer s1.deinit();

        var s2 = String.initSlice("hello world! ");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal both heap
        var s1 = String.initSlice("hello to this glorious world!");
        defer s1.deinit();

        var s2 = String.initSlice("hello to this glarious world!");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal both heap sanity
        var s1 = String.initSlice("hello to this glorious world!");
        defer s1.deinit();

        var s2 = String.initSlice("hello to this glorious world! ");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal mix
        var s1 = String.initSlice("hello world!");
        defer s1.deinit();

        var s2 = String.initSlice("hello to this glorious world! ");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
}

test "String equal slice" {
    { // null
        var s = String{};
        defer s.deinit();

        try expect(s.eqlSlice(""));
    }
    { // sso
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.eqlSlice("hello world!"));
    }
    { // heap
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.eqlSlice("hello to this glorious world!"));
    }
    { // not equal empty
        var s = String{};
        defer s.deinit();

        try expect(!s.eqlSlice("!"));
    }
    { // not equal empty sanity
        var s = String{};
        defer s.deinit();

        try expect(!s.eqlSlice("!"));
    }
    { // not equal sso
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(!s.eqlSlice("hello warld!"));
    }
    { // not equal sso sanity
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(!s.eqlSlice("hello world! "));
    }
    { // not equal heap
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        var s2 = String.initSlice("hello to this glarious world!");
        defer s2.deinit();

        try expect(!s.eqlSlice("hello to this glarious world!"));
    }
    { // not equal heap sanity
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(!s.eqlSlice("hello to this glorious world! "));
    }
}

test "String find" {
    { // null
        var s = String{};
        defer s.deinit();

        try expect(s.find("") == null);
    }
    { // sso valid, cant find empty
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.find("") == null);
    }
    { // heap valid, cant find empty
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("") == null);
    }
    { // sso valid, find at beginning 1 character
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.find("h") == 0);
    }
    { // heap valid, find at beginning 1 character
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("h") == 0);
    }
    { // sso valid, find in middle 1 character
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.find("o") == 4);
    }
    { // heap valid, find in middle 1 character
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("o") == 4);
    }
    { // sso valid, find at end 1 character
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.find("!") == 11);
    }
    { // heap valid, find at end 1 character
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("!") == 28);
    }
    { // sso valid, find at beginning multiple characters
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.find("hel") == 0);
    }
    { // heap valid, find at beginning multiple characters
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("hel") == 0);
    }
    { // sso valid, find in middle multiple characters
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.find("o wo") == 4);
    }
    { // heap valid, find in middle multiple characters
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("o to") == 4);
    }
    { // sso valid, find at end multiple characters
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.find("ld!") == 9);
    }
    { // heap valid, find at end multiple characters
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("ld!") == 26);
    }
    { // sso, find longer null
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.find("hello world! ") == null);
    }
    { // heap, find longer null
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("hello to this glorious world! ") == null);
    }
}

test "String reverse find" {
    { // null
        var s = String{};
        defer s.deinit();

        try expect(s.rfind("") == null);
    }
    { // sso valid, cant find empty
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.rfind("") == null);
    }
    { // heap valid, cant find empty
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("") == null);
    }
    { // sso valid, find at beginning 1 character
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.rfind("h") == 0);
    }
    { // heap valid, find at beginning 1 character
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("h") == 10);
    }
    { // sso valid, find in middle 1 character
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.rfind("o") == 7);
    }
    { // heap valid, find in middle 1 character
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("o") == 24);
    }
    { // sso valid, find at end 1 character
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.rfind("!") == 11);
    }
    { // heap valid, find at end 1 character
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("!") == 28);
    }
    { // sso valid, find at beginning multiple characters
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.rfind("hel") == 0);
    }
    { // heap valid, find at beginning multiple characters
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("hel") == 0);
    }
    { // sso valid, find in middle multiple characters
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.rfind("o wo") == 4);
    }
    { // heap valid, find in middle multiple characters
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("o to") == 4);
    }
    { // sso valid, find at end multiple characters
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.rfind("ld!") == 9);
    }
    { // heap valid, find at end multiple characters
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("ld!") == 26);
    }
    { // sso, find longer null
        var s = String.initSlice("hello world!");
        defer s.deinit();

        try expect(s.rfind("hello world! ") == null);
    }
    { // heap, find longer null
        var s = String.initSlice("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("hello to this glorious world! ") == null);
    }
}

test "String from int" {
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
        var s = String.fromInt(2);
        defer s.deinit();
        try expect(s.eqlSlice("2"));
    }
    {
        var s = String.fromInt(21);
        defer s.deinit();
        try expect(s.eqlSlice("21"));
    }
    {
        var s = String.fromInt(500);
        defer s.deinit();
        try expect(s.eqlSlice("500"));
    }
    {
        var s = String.fromInt(std.math.maxInt(Int));
        defer s.deinit();
        try expect(s.eqlSlice("9223372036854775807"));
    }
    {
        var s = String.fromInt(-1);
        defer s.deinit();
        try expect(s.eqlSlice("-1"));
    }
    {
        var s = String.fromInt(-2);
        defer s.deinit();
        try expect(s.eqlSlice("-2"));
    }
    {
        var s = String.fromInt(-21);
        defer s.deinit();
        try expect(s.eqlSlice("-21"));
    }
    {
        var s = String.fromInt(-500);
        defer s.deinit();
        try expect(s.eqlSlice("-500"));
    }
    {
        var s = String.fromInt(std.math.minInt(Int));
        defer s.deinit();
        try expect(s.eqlSlice("-9223372036854775808"));
    }
}

test "String compare" {
    var empty1 = String{};
    defer empty1.deinit();
    var empty2 = String{};
    defer empty2.deinit();
    var emptyClone = empty1.clone();
    defer emptyClone.deinit();

    var helloWorld1 = String.initSlice("hello world!");
    defer helloWorld1.deinit();
    var helloWorld2 = String.initSlice("hello world!");
    defer helloWorld2.deinit();
    var helloWorldClone = helloWorld1.clone();
    defer helloWorldClone.deinit();

    var helloWorldAlt1 = String.initSlice("hallo world!");
    defer helloWorldAlt1.deinit();
    var helloWorldAlt2 = String.initSlice("hallo world!");
    defer helloWorldAlt2.deinit();
    var helloWorldAltClone = helloWorldAlt1.clone();
    defer helloWorldAltClone.deinit();

    var helloWorldSpace1 = String.initSlice("hello world! ");
    defer helloWorldSpace1.deinit();
    var helloWorldSpace2 = String.initSlice("hello world! ");
    defer helloWorldSpace2.deinit();
    var helloWorldSpaceClone = helloWorldSpace1.clone();
    defer helloWorldSpaceClone.deinit();

    var helloWorldLong1 = String.initSlice("hello to this glorious world!");
    defer helloWorldLong1.deinit();
    var helloWorldLong2 = String.initSlice("hello to this glorious world!");
    defer helloWorldLong2.deinit();
    var helloWorldLongClone = helloWorldLong1.clone();
    defer helloWorldLongClone.deinit();

    var helloWorldLongAlt1 = String.initSlice("hallo to this glorious world!");
    defer helloWorldLongAlt1.deinit();
    var helloWorldLongAlt2 = String.initSlice("hallo to this glorious world!");
    defer helloWorldLongAlt2.deinit();
    var helloWorldLongAltClone = helloWorldLongAlt1.clone();
    defer helloWorldLongAltClone.deinit();

    var helloWorldLongSpace1 = String.initSlice("hello to this glorious world! ");
    defer helloWorldLongSpace1.deinit();
    var helloWorldLongSpace2 = String.initSlice("hello to this glorious world! ");
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
