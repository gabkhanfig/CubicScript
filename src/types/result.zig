const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const TaggedValue = root.TaggedValue;
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const allocator = @import("../state/global_allocator.zig").allocator;

pub const Result = extern struct {
    const IS_ERROR_BIT: usize = @shlExact(1, 63);
    const PTR_BITMASK: usize = 0xFFFFFFFFFFFF;
    const TAG_BITMASK: usize = ~(PTR_BITMASK | IS_ERROR_BIT);
    const SHIFT = 48;

    const Self = @This();

    inner: usize,

    pub fn initOk(okValue: TaggedValue) Self {
        const valueAlloc = allocator().create(RawValue) catch {
            @panic("Script out of memory");
        };
        valueAlloc.* = okValue.value;
        return Self{ .inner = @shlExact(okValue.tag.asUsize(), SHIFT) | @intFromPtr(valueAlloc) };
    }

    pub fn initErr(errValue: TaggedValue) Self {
        const valueAlloc = allocator().create(RawValue) catch {
            @panic("Script out of memory");
        };
        valueAlloc.* = errValue.value;
        return Self{ .inner = IS_ERROR_BIT | @shlExact(errValue.tag.asUsize(), SHIFT) | @intFromPtr(valueAlloc) };
    }

    /// If the ok or error owned by the result hasn't been taken `take()`, free's the associated memory.
    pub fn deinit(self: *Self) void {
        if (self.inner & (~IS_ERROR_BIT) != 0) {
            const innerValue: *RawValue = @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(self.inner & PTR_BITMASK))));
            var taggedValue = TaggedValue{ .value = innerValue.*, .tag = self.tag() };
            taggedValue.deinit();
            allocator().destroy(innerValue);
            self.inner = self.inner & IS_ERROR_BIT; // Clear the tagged pointer other than the flag for if it's an error or not.
        }
    }

    /// This function returns the same value on the same instance even if `take()` or `deinit()` is called.
    pub fn isOk(self: *const Self) bool {
        return (self.inner & IS_ERROR_BIT) == 0;
    }

    /// This function returns the same value on the same instance even if `take()` or `deinit()` is called.
    pub fn isErr(self: *const Self) bool {
        return (self.inner & IS_ERROR_BIT) != 0;
    }

    /// Get the tag of the result value, whether ok or error.
    pub fn tag(self: *const Self) ValueTag {
        return @enumFromInt(@shrExact(self.inner & TAG_BITMASK, SHIFT));
    }

    /// Get an immutable reference to the raw ok value owned by this result.
    pub fn getOk(self: *const Self) *const RawValue {
        assert(self.isOk());
        return @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(self.inner & PTR_BITMASK))));
    }

    /// Get a mutable reference to the raw ok value owned by this result.
    pub fn getOkMut(self: *Self) *RawValue {
        assert(self.isOk());
        return @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(self.inner & PTR_BITMASK))));
    }

    /// Gives up ownership of the owned ok value. Preserves whether this instance is ok or an error.
    pub fn takeOk(self: *Self) TaggedValue {
        assert(self.isOk());
        const valuePtr = self.getOkMut();
        const rawValue = valuePtr.*;
        const valueTag = self.tag();

        allocator().destroy(valuePtr);
        self.inner = self.inner & IS_ERROR_BIT; // Clear the tagged pointer other than the flag for if it's an error or not.

        return .{ .tag = valueTag, .value = rawValue };
    }

    /// Get an immutable reference to the raw error value owned by this result.
    pub fn getErr(self: *const Self) *const RawValue {
        assert(self.isErr());
        return @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(self.inner & PTR_BITMASK))));
    }

    /// Get a mutable reference to the raw error value owned by this result.
    pub fn getErrMut(self: *Self) *RawValue {
        assert(self.isErr());
        return @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(self.inner & PTR_BITMASK))));
    }

    /// Gives up ownership of the owned error value. Preserves whether this instance is ok or an error.
    pub fn takeErr(self: *Self) TaggedValue {
        assert(self.isErr());
        const valuePtr = self.getErrMut();
        const rawValue = valuePtr.*;
        const valueTag = self.tag();

        allocator().destroy(valuePtr);
        self.inner = self.inner & IS_ERROR_BIT; // Clear the tagged pointer other than the flag for if it's an error or not.

        return .{ .tag = valueTag, .value = rawValue };
    }
};

test "Result ok int" {
    { // destroy with deinit
        var result = Result.initOk(TaggedValue.initInt(10));
        defer result.deinit();

        try expect(result.isOk());
        try expect(result.tag() == .Int);

        try expect(result.getOk().int == 10);
        result.getOkMut().int = 20;
        try expect(result.getOk().int == 20);
    }
    { // take
        var result = Result.initOk(TaggedValue.initInt(10));
        defer result.deinit();

        result.getOkMut().int = 20;

        var take = result.takeOk();
        defer take.deinit();

        try expect(take.tag == .Int);
        try expect(take.value.int == 20);
    }
    { // take without calling deinit (safe)
        var result = Result.initOk(TaggedValue.initInt(10));

        result.getOkMut().int = 20;

        var take = result.takeOk();
        defer take.deinit();

        try expect(take.tag == .Int);
        try expect(take.value.int == 20);
    }
}

test "Result ok string" {
    { // destroy with deinit
        var result = Result.initOk(TaggedValue.initString(root.String.initSliceUnchecked("hello")));
        defer result.deinit();

        try expect(result.isOk());
        try expect(result.tag() == .String);

        try expect(result.getOk().string.eqlSlice("hello"));
        result.getOkMut().string.appendUnchecked(" world!");
        try expect(result.getOk().string.eqlSlice("hello world!"));
    }
    { // take
        var result = Result.initOk(TaggedValue.initString(root.String.initSliceUnchecked("hello")));
        defer result.deinit();

        result.getOkMut().string.appendUnchecked(" world!");

        var take = result.takeOk();
        defer take.deinit();

        try expect(take.tag == .String);
        try expect(take.value.string.eqlSlice("hello world!"));
    }
    { // take without calling deinit (safe)
        var result = Result.initOk(TaggedValue.initString(root.String.initSliceUnchecked("hello")));

        result.getOkMut().string.appendUnchecked(" world!");

        var take = result.takeOk();
        defer take.deinit();

        try expect(take.tag == .String);
        try expect(take.value.string.eqlSlice("hello world!"));
    }
}

test "Result err int" {
    { // destroy with deinit
        var result = Result.initErr(TaggedValue.initInt(10));
        defer result.deinit();

        try expect(result.isErr());
        try expect(result.tag() == .Int);

        try expect(result.getErr().int == 10);
        result.getErrMut().int = 20;
        try expect(result.getErr().int == 20);
    }
    { // take
        var result = Result.initErr(TaggedValue.initInt(10));
        defer result.deinit();

        result.getErrMut().int = 20;

        var take = result.takeErr();
        defer take.deinit();

        try expect(take.tag == .Int);
        try expect(take.value.int == 20);
    }
    { // take without calling deinit (safe)
        var result = Result.initErr(TaggedValue.initInt(10));

        result.getErrMut().int = 20;

        var take = result.takeErr();
        defer take.deinit();

        try expect(take.tag == .Int);
        try expect(take.value.int == 20);
    }
}

test "Result err string" {
    { // destroy with deinit
        var result = Result.initErr(TaggedValue.initString(root.String.initSliceUnchecked("hello")));
        defer result.deinit();

        try expect(result.isErr());
        try expect(result.tag() == .String);

        try expect(result.getErr().string.eqlSlice("hello"));
        result.getErrMut().string.appendUnchecked(" world!");
        try expect(result.getErr().string.eqlSlice("hello world!"));
    }
    { // take
        var result = Result.initErr(TaggedValue.initString(root.String.initSliceUnchecked("hello")));
        defer result.deinit();

        result.getErrMut().string.appendUnchecked(" world!");

        var take = result.takeErr();
        defer take.deinit();

        try expect(take.tag == .String);
        try expect(take.value.string.eqlSlice("hello world!"));
    }
    { // take without calling deinit (safe)
        var result = Result.initErr(TaggedValue.initString(root.String.initSliceUnchecked("hello")));

        result.getErrMut().string.appendUnchecked(" world!");

        var take = result.takeErr();
        defer take.deinit();

        try expect(take.tag == .String);
        try expect(take.value.string.eqlSlice("hello world!"));
    }
}
