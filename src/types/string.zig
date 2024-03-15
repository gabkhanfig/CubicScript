const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const AtomicRefCount = @import("atomic_ref_count.zig").AtomicRefCount;
const Int = @import("primitives.zig").Int;

/// Immutable, ref counted string.
pub const String = extern struct {
    const Self = @This();

    /// If null, is just an empty string. This makes 0 initization viable.
    /// TODO does this need to be atomic? It's possible one thread reads while another deinits on the same String reference (not inner reference)?
    inner: ?*anyopaque = null,

    pub fn initSlice(slice: [:0]const u8, allocator: Allocator) Allocator.Error!Self {
        assert(slice.len != 0);

        const inner = try Inner.initSlice(slice, allocator);
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

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.inner != null) {
            const inner = self.asInnerMut(); // Use this ordering in the event of weird synchronization issues.
            self.inner = null;
            inner.decrementRefCount(allocator);
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

            return string_simd.cubs_string_compare_equal_strings_simd_heap_rep(
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

            return string_simd.cubs_string_compare_equal_string_and_slice_simd_heap_rep(
                @ptrCast(self.asInner().rep.heap.data),
                @ptrCast(other.ptr),
                @intCast(other.len),
            );
        }

        return std.mem.eql(u8, self.toSlice(), other);
    }

    pub fn hash(self: *const Self) usize {
        const slice = self.toSlice();
        return string_simd.cubs_string_compute_hash_simd(@ptrCast(slice.ptr), @intCast(slice.len));
    }

    pub fn find(self: *const Self, literal: [:0]const u8) ?Int {
        if (self.inner == null) {
            return null;
        } else {
            if (literal.len == 0) {
                return null;
            }
            const selfBuffer = self.toSlice();
            if (self.asInner().isSso()) {
                const index = std.mem.indexOf(u8, selfBuffer, literal);
                if (index) |i| {
                    return @intCast(i);
                } else {
                    return null;
                }
            } else {
                const result = string_simd.cubs_string_find_str_slice(
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

        fn decrementRefCount(self: *Inner, allocator: Allocator) void {
            if (!self.refCount.removeRef()) {
                return;
            }

            if (!self.isSso()) {
                allocator.free(self.rep.heap.data[0..(self.rep.heap.allocationSize - 1) :0]);
                self.rep.heap.data = undefined;
                self.rep.heap.allocationSize = 0;
            }
            allocator.destroy(self);
        }

        fn isSso(self: *const Inner) bool {
            return self.lenAndFlag & FLAG_BIT == 0;
        }

        fn initSlice(slice: [:0]const u8, allocator: Allocator) Allocator.Error!*Inner {
            const self = try allocator.create(Inner);

            self.* = Inner{ .lenAndFlag = slice.len };
            self.refCount.addRef();
            try self.ensureTotalCapacity(allocator, slice.len + 1);

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
        fn ensureTotalCapacity(self: *Inner, allocator: Allocator, minCapacity: usize) Allocator.Error!void {
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
            const newSlice: []align(64) u8 = try allocator.alignedAlloc(u8, 64, mallocCapacity);
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

    /// See string_simd.cpp
    const string_simd = struct {
        extern fn cubs_string_compare_equal_strings_simd_heap_rep(selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) bool;
        extern fn cubs_string_compare_equal_string_and_slice_simd_heap_rep(selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) bool;
        extern fn cubs_string_compute_hash_simd(selfBuffer: [*c]const u8, len: c_ulonglong) c_ulonglong;
        extern fn cubs_string_find_str_slice(selfBuffer: [*c]const u8, selfLength: c_ulonglong, sliceBuffer: [*c]const u8, sliceLength: c_ulonglong) c_ulonglong;
    };
};

test "String default init" {
    const s = String{};
    try expect(s.len() == 0);
    try expect(std.mem.eql(u8, s.toSlice(), ""));
}

test "String from slice" {
    const allocator = std.testing.allocator;
    {
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.len() == 12);
        try expect(std.mem.eql(u8, s.toSlice(), "hello world!"));
    }
    {
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.len() == 29);
        try expect(std.mem.eql(u8, s.toSlice(), "hello to this glorious world!"));
    }
}

test "String clone" {
    const allocator = std.testing.allocator;
    {
        var s1 = try String.initSlice("hello world!", allocator);
        defer s1.deinit(allocator);

        var s2 = s1.clone();
        defer s2.deinit(allocator);

        try expect(s1.inner == s2.inner);
        try expect(std.mem.eql(u8, s1.toSlice(), "hello world!"));
        try expect(std.mem.eql(u8, s2.toSlice(), "hello world!"));
    }
    {
        var s1 = try String.initSlice("hello to this glorious world!", allocator);
        defer s1.deinit(allocator);

        var s2 = s1.clone();
        defer s2.deinit(allocator);

        try expect(s1.inner == s2.inner);
        try expect(std.mem.eql(u8, s1.toSlice(), "hello to this glorious world!"));
        try expect(std.mem.eql(u8, s2.toSlice(), "hello to this glorious world!"));
    }
}

test "String clone thread safety" {
    const allocator = std.testing.allocator;

    const TestThreadHandler = struct {
        fn makeClonesNTimes(ref: *String, n: usize, a: Allocator) void {
            for (0..n) |_| {
                var s1 = ref.clone();
                defer s1.deinit(a);
                var s2 = ref.clone();
                defer s2.deinit(a);
                var s3 = ref.clone();
                defer s3.deinit(a);
                var s4 = ref.clone();
                defer s4.deinit(a);
            }
        }
    };

    {
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        const t1 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t2 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t3 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t4 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });

        t1.join();
        t2.join();
        t3.join();
        t4.join();
    }
    {
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        const t1 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t2 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t3 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });
        const t4 = try std.Thread.spawn(.{}, TestThreadHandler.makeClonesNTimes, .{ &s, 10000, allocator });

        t1.join();
        t2.join();
        t3.join();
        t4.join();
    }
}

test "String equal" {
    const allocator = std.testing.allocator;
    { // null
        var s1 = String{};
        defer s1.deinit(allocator);
        var s2 = String{};
        defer s2.deinit(allocator);

        try expect(s1.eql(s2));
    }
    { // shared reference sso
        var s1 = try String.initSlice("hello world!", allocator);
        defer s1.deinit(allocator);

        var s2 = s1.clone();
        defer s2.deinit(allocator);

        try expect(s1.eql(s2));
    }
    { // different reference sso
        var s1 = try String.initSlice("hello world!", allocator);
        defer s1.deinit(allocator);

        var s2 = try String.initSlice("hello world!", allocator);
        defer s2.deinit(allocator);

        try expect(s1.eql(s2));
    }
    { // shared reference heap
        var s1 = try String.initSlice("hello to this glorious world!", allocator);
        defer s1.deinit(allocator);

        var s2 = s1.clone();
        defer s2.deinit(allocator);

        try expect(s1.eql(s2));
    }
    { // different reference heap
        var s1 = try String.initSlice("hello to this glorious world!", allocator);
        defer s1.deinit(allocator);

        var s2 = try String.initSlice("hello to this glorious world!", allocator);
        defer s2.deinit(allocator);

        try expect(s1.eql(s2));
    }
    { // not equal one null
        var s1 = try String.initSlice("hello world!", allocator);
        defer s1.deinit(allocator);

        var s2 = String{};
        defer s2.deinit(allocator);

        try expect(!s1.eql(s2));
    }
    { // not equal one null sanity
        var s1 = String{};
        defer s1.deinit(allocator);

        var s2 = try String.initSlice("hello world!", allocator);
        defer s2.deinit(allocator);

        try expect(!s1.eql(s2));
    }
    { // not equal both sso
        var s1 = try String.initSlice("hello world!", allocator);
        defer s1.deinit(allocator);

        var s2 = try String.initSlice("hello warld!", allocator);
        defer s2.deinit(allocator);

        try expect(!s1.eql(s2));
    }
    { // not equal both sso sanity
        var s1 = try String.initSlice("hello world!", allocator);
        defer s1.deinit(allocator);

        var s2 = try String.initSlice("hello world! ", allocator);
        defer s2.deinit(allocator);

        try expect(!s1.eql(s2));
    }
    { // not equal both heap
        var s1 = try String.initSlice("hello to this glorious world!", allocator);
        defer s1.deinit(allocator);

        var s2 = try String.initSlice("hello to this glarious world!", allocator);
        defer s2.deinit(allocator);

        try expect(!s1.eql(s2));
    }
    { // not equal both heap sanity
        var s1 = try String.initSlice("hello to this glorious world!", allocator);
        defer s1.deinit(allocator);

        var s2 = try String.initSlice("hello to this glorious world! ", allocator);
        defer s2.deinit(allocator);

        try expect(!s1.eql(s2));
    }
    { // not equal mix
        var s1 = try String.initSlice("hello world!", allocator);
        defer s1.deinit(allocator);

        var s2 = try String.initSlice("hello to this glorious world! ", allocator);
        defer s2.deinit(allocator);

        try expect(!s1.eql(s2));
    }
}

test "String equal slice" {
    const allocator = std.testing.allocator;
    { // null
        var s = String{};
        defer s.deinit(allocator);

        try expect(s.eqlSlice(""));
    }
    { // sso
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.eqlSlice("hello world!"));
    }
    { // heap
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.eqlSlice("hello to this glorious world!"));
    }
    { // not equal empty
        var s = String{};
        defer s.deinit(allocator);

        try expect(!s.eqlSlice("!"));
    }
    { // not equal empty sanity
        var s = String{};
        defer s.deinit(allocator);

        try expect(!s.eqlSlice("!"));
    }
    { // not equal sso
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(!s.eqlSlice("hello warld!"));
    }
    { // not equal sso sanity
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(!s.eqlSlice("hello world! "));
    }
    { // not equal heap
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        var s2 = try String.initSlice("hello to this glarious world!", allocator);
        defer s2.deinit(allocator);

        try expect(!s.eqlSlice("hello to this glarious world!"));
    }
    { // not equal heap sanity
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(!s.eqlSlice("hello to this glorious world! "));
    }
}

test "String find" {
    const allocator = std.testing.allocator;
    { // null
        var s = String{};
        defer s.deinit(allocator);

        var f = String{};
        defer f.deinit(allocator);

        try expect(s.find(f) == null);
    }
    { // sso valid, cant find empty
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("") == null);
    }
    { // heap valid, cant find empty
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("") == null);
    }
    { // sso valid, find at beginning 1 character
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("h") == 0);
    }
    { // heap valid, find at beginning 1 character
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("h") == 0);
    }
    { // sso valid, find in middle 1 character
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("o") == 4);
    }
    { // heap valid, find in middle 1 character
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("o") == 4);
    }
    { // sso valid, find at end 1 character
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("!") == 11);
    }
    { // heap valid, find at end 1 character
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("!") == 28);
    }
    { // sso valid, find at beginning multiple characters
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("hel") == 0);
    }
    { // heap valid, find at beginning multiple characters
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("hel") == 0);
    }
    { // sso valid, find in middle multiple characters
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("o wo") == 4);
    }
    { // heap valid, find in middle multiple characters
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("o to") == 4);
    }
    { // sso valid, find at end multiple characters
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("ld!") == 9);
    }
    { // heap valid, find at end multiple characters
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("ld!") == 26);
    }
    { // sso, find longer null
        var s = try String.initSlice("hello world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("hello world! ") == null);
    }
    { // heap, find longer null
        var s = try String.initSlice("hello to this glorious world!", allocator);
        defer s.deinit(allocator);

        try expect(s.find("hello to this glorious world! ") == null);
    }
}
