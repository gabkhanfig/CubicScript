const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const TaggedValue = root.TaggedValue;
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const allocator = @import("../state/global_allocator.zig").allocator;

/// Can be zero initialized, meaning it's a none value.
pub const Option = extern struct {
    const PTR_BITMASK: usize = 0xFFFFFFFFFFFF;
    const TAG_BITMASK: usize = ~PTR_BITMASK;
    const SHIFT = 48;

    const Self = @This();

    inner: usize = 0,

    pub fn init(inValue: TaggedValue) Self {
        if (inValue.tag == .None) {
            return Self{};
        }
        const value = allocator().create(RawValue) catch {
            @panic("Script out of memory");
        };
        value.* = inValue.value;
        return Self{ .inner = @shlExact(inValue.tag.asUsize(), SHIFT) | @intFromPtr(value) };
    }

    pub fn deinit(self: *Self) void {
        if (self.isNone()) {
            return;
        } else {
            var taken = self.take();
            taken.deinit();
        }
    }

    pub fn isNone(self: *const Self) bool {
        return self.inner == 0;
    }

    pub fn tag(self: *const Self) ValueTag {
        return @enumFromInt(@shrExact(self.inner & TAG_BITMASK, SHIFT));
    }

    pub fn get(self: *const Self) *const RawValue {
        assert(!self.isNone());
        return @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(self.inner & PTR_BITMASK))));
    }

    pub fn getMut(self: *Self) *RawValue {
        assert(!self.isNone());
        return @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(self.inner & PTR_BITMASK))));
    }

    pub fn take(self: *Self) TaggedValue {
        assert(!self.isNone());

        const valuePtr = self.getMut();
        const rawValue = valuePtr.*; // take ownership
        const valueTag = self.tag();

        allocator().destroy(valuePtr);

        self.inner = 0;
        return .{ .tag = valueTag, .value = rawValue };
    }
};

test "null" {
    var opt = Option{};
    defer opt.deinit();

    try expect(opt.isNone());
}

test "not null" {
    var opt = Option.init(TaggedValue.initString(root.String.initSliceUnchecked("aa")));
    defer opt.deinit();

    try expect(opt.isNone() == false);
    try expect(opt.get().string.eqlSlice("aa"));
}

test "take" {
    var opt = Option.init(TaggedValue.initString(root.String.initSliceUnchecked("aa")));
    defer opt.deinit();

    var take = opt.take();
    defer take.deinit();

    try expect(take.tag == .String);
    try expect(take.value.string.eqlSlice("aa"));
}
