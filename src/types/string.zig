const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const AtomicRefCount = @import("atomic_ref_count.zig").AtomicRefCount;
const root = @import("../root.zig");
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

    /// Will validate that `slice` is utf8, and that no null terminator is found before the end of the slice.
    pub fn initSlice(slice: []const u8) error{InvalidUtf8}!Self {
        if (slice.len == 0) {
            return .{};
        }

        const inner = try Inner.initSlice(slice);
        return Self{ .inner = @ptrCast(inner) };
    }

    /// Performs no validation on `slice`, meaning it could be invalid utf8 or have an early null terminator.
    pub fn initSliceUnchecked(slice: []const u8) Self {
        if (slice.len == 0) {
            return .{};
        }

        const inner = Inner.initSlice(slice) catch unreachable;
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

    pub fn len(self: *const Self) usize {
        if (self.inner == null) {
            return 0;
        } else {
            return self.asInner().lenAndFlag & ~Inner.FLAG_BIT;
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
            if (@import("builtin").target.cpu.arch.isX86()) { // TODO SIMD for other platforms such as ARM MacOS (neon?)
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

    pub fn find(self: *const Self, literal: []const u8) ?usize {
        if (self.inner == null or literal.len == 0) {
            return null;
        } else {
            const selfBuffer = self.toSlice();
            if (self.asInner().isSso()) {
                const index = std.mem.indexOf(u8, selfBuffer, literal);
                if (index) |i| {
                    return i;
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

    pub fn rfind(self: *const Self, literal: []const u8) ?usize {
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

    pub fn append(self: *Self, literal: []const u8) error{InvalidUtf8}!void {
        if (!isValidUtf8(literal)) {
            return error.InvalidUtf8;
        }
        self.appendUnchecked(literal);
    }

    pub fn appendUnchecked(self: *Self, literal: []const u8) void {
        if (self.inner == null) {
            self.* = String.initSliceUnchecked(literal);
            return;
        }

        self.makeSelfUniqueReference();
        const inner = self.asInnerMut();
        inner.growCapacity(literal.len);
        const bufCopyStart: [*]u8 = blk: {
            if (inner.isSso()) {
                break :blk @ptrCast(&inner.rep.sso.chars[self.len()]);
            } else {
                break :blk @ptrCast(&inner.rep.heap.data[self.len()]);
            }
        };
        for (0..literal.len) |i| {
            bufCopyStart[i] = literal[i];
        }
        inner.setLen(inner.len() + literal.len);
        assert(bufCopyStart[literal.len] == 0); // ensure null terminator
    }

    pub fn substr(self: *const Self, startInclusive: usize, endExclusive: usize) error{ IndexOutOfBounds, InvalidUtf8 }!Self {
        if (startInclusive >= self.len() or endExclusive > self.len()) {
            return error.IndexOutOfBounds;
        }
        if (startInclusive == endExclusive) {
            return Self{};
        }

        if (Self.initSlice(self.toSlice()[startInclusive..endExclusive])) |string| {
            return string;
        } else |_| {
            return error.InvalidUtf8;
        }
    }

    // split
    // insert
    // remove

    pub fn fromBool(boolean: bool) Self {
        if (boolean) { // TODO is it possible to make these globals without running into tests leaking memory issues?
            return Self.initSliceUnchecked("true");
        } else {
            return Self.initSliceUnchecked("false");
        }
    }

    pub fn fromInt(num: i64) Self {
        if (num == 0) {
            return Self.initSliceUnchecked("0"); // TODO can the 0 string become a global?
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
        return Self.initSliceUnchecked(tempNums[tempAt..][0..length]);
    }

    pub fn fromFloat(num: f64) Self {
        if (num == 0) {
            return Self.initSliceUnchecked("0"); // TODO can the 0 string become a global?
        }
        // https://stackoverflow.com/questions/1701055/what-is-the-maximum-length-in-chars-needed-to-represent-any-double-value
        var buf: [1079]u8 = undefined;
        // UnrealEngine uses sprintf %f specifier, so decimal notation seems reasonable.
        const numAsSlice = std.fmt.bufPrint(&buf, "{d}", .{num}) catch unreachable;
        return Self.initSliceUnchecked(numAsSlice);
    }

    pub fn toBool(self: *const Self) error{NotBool}!bool {
        const slice = self.toSlice();
        if (std.mem.eql(u8, slice, "true")) {
            return true;
        } else if (std.mem.eql(u8, slice, "false")) {
            return false;
        } else {
            return error.NotBool;
        }
    }

    pub fn toInt(self: *const Self) error{NotInt}!i64 {
        if (std.fmt.parseInt(i64, self.toSlice(), 0)) |num| {
            return num;
        } else |_| {
            return error.NotInt;
        }
    }

    pub fn toFloat(self: *const Self) error{NotFloat}!f64 {
        if (std.fmt.parseFloat(f64, self.toSlice)) |num| {
            return num;
        } else |_| {
            return error.NotFloat;
        }
    }

    fn asInner(self: Self) *const Inner {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asInnerMut(self: *Self) *Inner {
        return @ptrCast(@alignCast(self.inner));
    }

    fn makeSelfUniqueReference(self: *Self) void {
        if (self.inner == null) {
            return;
        }

        const oldInner = self.asInnerMut();
        self.* = String.initSliceUnchecked(self.toSlice());
        oldInner.decrementRefCount();
    }

    const Inner = extern struct {
        const FLAG_BIT: usize = @shlExact(1, 63);

        refCount: AtomicRefCount = AtomicRefCount{},
        lenAndFlag: usize,
        rep: StringRep = undefined,

        fn len(self: Inner) usize {
            return self.lenAndFlag & ~FLAG_BIT;
        }

        fn setLen(self: *Inner, newLen: usize) void {
            self.lenAndFlag = newLen | (self.lenAndFlag & Inner.FLAG_BIT);
        }

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

        fn initSlice(slice: []const u8) error{InvalidUtf8}!*Inner {
            if (!isValidUtf8(slice)) {
                return error.InvalidUtf8;
            }
            return Inner.initSliceUnchecked(slice);
        }

        fn initSliceUnchecked(slice: []const u8) *Inner {
            const self = allocator().create(Inner) catch {
                @panic("Script out of memory");
            };

            self.* = Inner{ .lenAndFlag = slice.len };
            self.refCount.addRef();
            self.ensureTotalCapacity(slice.len + 1); // Will set the heap flag if necessary

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

        /// Increases the capacity of the string, accounting for the null terminator.
        /// Should only be used for unique references.
        fn growCapacity(self: *Inner, increaseBy: usize) void {
            assert(self.refCount.count.load(std.builtin.AtomicOrder.acquire) == 1); // MUST be a ref count of 1.
            if (self.isSso()) {
                if ((self.lenAndFlag + increaseBy) <= SsoRep.MAX_LEN) {
                    return;
                }

                var mallocCapacity = self.lenAndFlag + increaseBy + 1; // null terminator
                const remainder = @mod(mallocCapacity, 64);
                if (remainder != 0) {
                    mallocCapacity = mallocCapacity + (64 - remainder);
                }
                const newSlice: []align(64) u8 = allocator().alignedAlloc(u8, 64, mallocCapacity) catch {
                    @panic("Script out of memory");
                };
                @memset(newSlice, 0);
                @memcpy(@as([*]u8, @ptrCast(&newSlice.ptr[0])), self.rep.sso.chars[0..self.lenAndFlag]);
                self.rep.heap.data = @ptrCast(newSlice.ptr);
                self.rep.heap.allocationSize = mallocCapacity;
                self.lenAndFlag |= Inner.FLAG_BIT;
            } else {
                if ((self.len() + increaseBy + 1) <= self.rep.heap.allocationSize) {
                    return;
                }

                var mallocCapacity = self.len() + increaseBy + 1; // null terminator
                const remainder = @mod(mallocCapacity, 64);
                if (remainder != 0) {
                    mallocCapacity = mallocCapacity + (64 - remainder);
                }
                const newSlice: []align(64) u8 = allocator().alignedAlloc(u8, 64, mallocCapacity) catch {
                    @panic("Script out of memory");
                };
                @memset(newSlice, 0);
                @memcpy(@as([*]u8, @ptrCast(&newSlice.ptr[0])), self.rep.heap.data[0..self.len()]);

                allocator().free(self.rep.heap.data[0..self.rep.heap.allocationSize]);

                self.rep.heap.data = @ptrCast(newSlice.ptr);
                self.rep.heap.allocationSize = mallocCapacity;
            }
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

// can this be SIMD?
pub fn isValidUtf8(slice: []const u8) bool {
    const asciiZeroBit: u8 = 0b10000000;
    const trailingBytesBitmask: u8 = 0b11000000;
    const trailingBytesCodePoint: u8 = 0b10000000;
    const twoByteCodePoint: u8 = 0b11000000;
    const twoByteBitmask: u8 = 0b11100000;
    const threeByteCodePoint: u8 = 0b11100000;
    const threeByteBitmask: u8 = 0b11110000;
    const fourByteCodePoint: u8 = 0b11110000;
    const fourByteBitmask: u8 = 0b11111000;

    var i: usize = 0;
    while (i < slice.len) {
        const c = slice[i];
        if (c == 0) {
            return false;
        } else if (c & asciiZeroBit == 0) {
            i += 1;
        } else if (c & twoByteBitmask == twoByteCodePoint) {
            if (slice[i + 1] & trailingBytesBitmask != trailingBytesCodePoint) {
                return false;
            }
            i += 2;
        } else if (c & threeByteBitmask == threeByteCodePoint) {
            if (slice[i + 1] & trailingBytesBitmask != trailingBytesCodePoint) {
                return false;
            }
            if (slice[i + 2] & trailingBytesBitmask != trailingBytesCodePoint) {
                return false;
            }
            i += 3;
        } else if (c & fourByteBitmask == fourByteCodePoint) {
            if (slice[i + 1] & trailingBytesBitmask != trailingBytesCodePoint) {
                return false;
            }
            if (slice[i + 2] & trailingBytesBitmask != trailingBytesCodePoint) {
                return false;
            }
            if (slice[i + 3] & trailingBytesBitmask != trailingBytesCodePoint) {
                return false;
            }
            i += 4;
        } else {
            return false;
        }
    }
    return true;
}

test "String default init" {
    const s = String{};
    try expect(s.len() == 0);
    try expect(std.mem.eql(u8, s.toSlice(), ""));
}

test "String from slice" {
    {
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.len() == 12);
        try expect(std.mem.eql(u8, s.toSlice(), "hello world!"));
    }
    {
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.len() == 29);
        try expect(std.mem.eql(u8, s.toSlice(), "hello to this glorious world!"));
    }
}

test "String clone" {
    {
        var s1 = String.initSliceUnchecked("hello world!");
        defer s1.deinit();

        var s2 = s1.clone();
        defer s2.deinit();

        try expect(s1.inner == s2.inner);
        try expect(std.mem.eql(u8, s1.toSlice(), "hello world!"));
        try expect(std.mem.eql(u8, s2.toSlice(), "hello world!"));
    }
    {
        var s1 = String.initSliceUnchecked("hello to this glorious world!");
        defer s1.deinit();

        var s2 = s1.clone();
        defer s2.deinit();

        try expect(s1.inner == s2.inner);
        try expect(std.mem.eql(u8, s1.toSlice(), "hello to this glorious world!"));
        try expect(std.mem.eql(u8, s2.toSlice(), "hello to this glorious world!"));
    }
}

test "String clone thread safety" {
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
        var s = String.initSliceUnchecked("hello world!");
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
        var s = String.initSliceUnchecked("hello to this glorious world!");
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
        var s1 = String.initSliceUnchecked("hello world!");
        defer s1.deinit();

        var s2 = s1.clone();
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // different reference sso
        var s1 = String.initSliceUnchecked("hello world!");
        defer s1.deinit();

        var s2 = String.initSliceUnchecked("hello world!");
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // shared reference heap
        var s1 = String.initSliceUnchecked("hello to this glorious world!");
        defer s1.deinit();

        var s2 = s1.clone();
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // different reference heap
        var s1 = String.initSliceUnchecked("hello to this glorious world!");
        defer s1.deinit();

        var s2 = String.initSliceUnchecked("hello to this glorious world!");
        defer s2.deinit();

        try expect(s1.eql(s2));
    }
    { // not equal one null
        var s1 = String.initSliceUnchecked("hello world!");
        defer s1.deinit();

        var s2 = String{};
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal one null sanity
        var s1 = String{};
        defer s1.deinit();

        var s2 = String.initSliceUnchecked("hello world!");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal both sso
        var s1 = String.initSliceUnchecked("hello world!");
        defer s1.deinit();

        var s2 = String.initSliceUnchecked("hello warld!");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal both sso sanity
        var s1 = String.initSliceUnchecked("hello world!");
        defer s1.deinit();

        var s2 = String.initSliceUnchecked("hello world! ");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal both heap
        var s1 = String.initSliceUnchecked("hello to this glorious world!");
        defer s1.deinit();

        var s2 = String.initSliceUnchecked("hello to this glarious world!");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal both heap sanity
        var s1 = String.initSliceUnchecked("hello to this glorious world!");
        defer s1.deinit();

        var s2 = String.initSliceUnchecked("hello to this glorious world! ");
        defer s2.deinit();

        try expect(!s1.eql(s2));
    }
    { // not equal mix
        var s1 = String.initSliceUnchecked("hello world!");
        defer s1.deinit();

        var s2 = String.initSliceUnchecked("hello to this glorious world! ");
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
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.eqlSlice("hello world!"));
    }
    { // heap
        var s = String.initSliceUnchecked("hello to this glorious world!");
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
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(!s.eqlSlice("hello warld!"));
    }
    { // not equal sso sanity
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(!s.eqlSlice("hello world! "));
    }
    { // not equal heap
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        var s2 = String.initSliceUnchecked("hello to this glarious world!");
        defer s2.deinit();

        try expect(!s.eqlSlice("hello to this glarious world!"));
    }
    { // not equal heap sanity
        var s = String.initSliceUnchecked("hello to this glorious world!");
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
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.find("") == null);
    }
    { // heap valid, cant find empty
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("") == null);
    }
    { // sso valid, find at beginning 1 character
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.find("h") == 0);
    }
    { // heap valid, find at beginning 1 character
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("h") == 0);
    }
    { // sso valid, find in middle 1 character
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.find("o") == 4);
    }
    { // heap valid, find in middle 1 character
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("o") == 4);
    }
    { // sso valid, find at end 1 character
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.find("!") == 11);
    }
    { // heap valid, find at end 1 character
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("!") == 28);
    }
    { // sso valid, find at beginning multiple characters
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.find("hel") == 0);
    }
    { // heap valid, find at beginning multiple characters
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("hel") == 0);
    }
    { // sso valid, find in middle multiple characters
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.find("o wo") == 4);
    }
    { // heap valid, find in middle multiple characters
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("o to") == 4);
    }
    { // sso valid, find at end multiple characters
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.find("ld!") == 9);
    }
    { // heap valid, find at end multiple characters
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.find("ld!") == 26);
    }
    { // sso, find longer null
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.find("hello world! ") == null);
    }
    { // heap, find longer null
        var s = String.initSliceUnchecked("hello to this glorious world!");
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
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.rfind("") == null);
    }
    { // heap valid, cant find empty
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("") == null);
    }
    { // sso valid, find at beginning 1 character
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.rfind("h") == 0);
    }
    { // heap valid, find at beginning 1 character
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("h") == 10);
    }
    { // sso valid, find in middle 1 character
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.rfind("o") == 7);
    }
    { // heap valid, find in middle 1 character
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("o") == 24);
    }
    { // sso valid, find at end 1 character
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.rfind("!") == 11);
    }
    { // heap valid, find at end 1 character
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("!") == 28);
    }
    { // sso valid, find at beginning multiple characters
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.rfind("hel") == 0);
    }
    { // heap valid, find at beginning multiple characters
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("hel") == 0);
    }
    { // sso valid, find in middle multiple characters
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.rfind("o wo") == 4);
    }
    { // heap valid, find in middle multiple characters
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("o to") == 4);
    }
    { // sso valid, find at end multiple characters
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.rfind("ld!") == 9);
    }
    { // heap valid, find at end multiple characters
        var s = String.initSliceUnchecked("hello to this glorious world!");
        defer s.deinit();

        try expect(s.rfind("ld!") == 26);
    }
    { // sso, find longer null
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        try expect(s.rfind("hello world! ") == null);
    }
    { // heap, find longer null
        var s = String.initSliceUnchecked("hello to this glorious world!");
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
        var s = String.fromInt(std.math.maxInt(i64));
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
        var s = String.fromInt(std.math.minInt(i64));
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

    var helloWorld1 = String.initSliceUnchecked("hello world!");
    defer helloWorld1.deinit();
    var helloWorld2 = String.initSliceUnchecked("hello world!");
    defer helloWorld2.deinit();
    var helloWorldClone = helloWorld1.clone();
    defer helloWorldClone.deinit();

    var helloWorldAlt1 = String.initSliceUnchecked("hallo world!");
    defer helloWorldAlt1.deinit();
    var helloWorldAlt2 = String.initSliceUnchecked("hallo world!");
    defer helloWorldAlt2.deinit();
    var helloWorldAltClone = helloWorldAlt1.clone();
    defer helloWorldAltClone.deinit();

    var helloWorldSpace1 = String.initSliceUnchecked("hello world! ");
    defer helloWorldSpace1.deinit();
    var helloWorldSpace2 = String.initSliceUnchecked("hello world! ");
    defer helloWorldSpace2.deinit();
    var helloWorldSpaceClone = helloWorldSpace1.clone();
    defer helloWorldSpaceClone.deinit();

    var helloWorldLong1 = String.initSliceUnchecked("hello to this glorious world!");
    defer helloWorldLong1.deinit();
    var helloWorldLong2 = String.initSliceUnchecked("hello to this glorious world!");
    defer helloWorldLong2.deinit();
    var helloWorldLongClone = helloWorldLong1.clone();
    defer helloWorldLongClone.deinit();

    var helloWorldLongAlt1 = String.initSliceUnchecked("hallo to this glorious world!");
    defer helloWorldLongAlt1.deinit();
    var helloWorldLongAlt2 = String.initSliceUnchecked("hallo to this glorious world!");
    defer helloWorldLongAlt2.deinit();
    var helloWorldLongAltClone = helloWorldLongAlt1.clone();
    defer helloWorldLongAltClone.deinit();

    var helloWorldLongSpace1 = String.initSliceUnchecked("hello to this glorious world! ");
    defer helloWorldLongSpace1.deinit();
    var helloWorldLongSpace2 = String.initSliceUnchecked("hello to this glorious world! ");
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

test "String append" {
    { // Empty string append sso
        var s = String{};
        defer s.deinit();

        s.appendUnchecked("hello world!");
        try expect(s.len() == 12);
        try expect(s.eqlSlice("hello world!"));
    }
    { // Empty string append heap
        var s = String{};
        defer s.deinit();

        s.appendUnchecked("hello to this glorious world!");
        try expect(s.len() == 29);
        try expect(s.eqlSlice("hello to this glorious world!"));
    }
    { // String with data append sso
        var s = String.initSliceUnchecked("erm");
        defer s.deinit();

        s.appendUnchecked(" tuna...");
        try expect(s.len() == 11);
        try expect(s.eqlSlice("erm tuna..."));
    }
    { // String that is sso append to heap
        var s = String.initSliceUnchecked("erm");
        defer s.deinit();
        s.appendUnchecked(" what da tuna good sir...");
        try expect(s.len() == 28);
        try expect(s.eqlSlice("erm what da tuna good sir..."));
    }
    { // String that is heap append heap
        var s = String.initSliceUnchecked("hello? is anyone there??");
        defer s.deinit();

        s.appendUnchecked("nuh uh!");
        try expect(s.len() == 31);
        try expect(s.eqlSlice("hello? is anyone there??nuh uh!"));
    }
    { // heap extra grow
        var s = String.initSliceUnchecked("hello? is anyone there??");
        defer s.deinit();
        s.appendUnchecked(" NO! I will never ever ever ever ever ever ever ever ever be here... I am a mysterious... slanger... aaaaaaaaaaa");
        try expect(s.len() == 136);
        try expect(s.eqlSlice("hello? is anyone there?? NO! I will never ever ever ever ever ever ever ever ever be here... I am a mysterious... slanger... aaaaaaaaaaa"));
    }
}

test "String substr" {
    {
        var s = String{};
        if (s.substr(0, 1)) |_| {
            try expect(false);
        } else |err| {
            try expect(err == error.IndexOutOfBounds);
        }

        if (s.substr(0, 0)) |_| {
            try expect(false);
        } else |err| {
            try expect(err == error.IndexOutOfBounds);
        }
    }
    {
        var s = String.initSliceUnchecked("hello world!");
        defer s.deinit();

        if (s.substr(0, 5)) |sub| {
            try expect(sub.eqlSlice("hello"));
            var subD = sub;
            subD.deinit();
        } else |_| {
            try expect(false);
        }

        if (s.substr(0, s.len())) |sub| {
            try expect(sub.eql(s));
            var subD = sub;
            subD.deinit();
        } else |_| {
            try expect(false);
        }
    }
}
