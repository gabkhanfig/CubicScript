const std = @import("std");
const expect = std.testing.expect;
const value_types = @import("../values.zig");
const ValueTag = value_types.ValueTag;
const RawValue = value_types.RawValue;
const CTaggedValue = value_types.CTaggedValue;
const TaggedValue = value_types.TaggedValue;
const String = @import("../string.zig").String;

const c = struct {
    extern fn cubs_set_init(keyTag: ValueTag) callconv(.C) Set;
    extern fn cubs_set_deinit(self: *Set) callconv(.C) void;
    extern fn cubs_set_tag(self: *const Set) callconv(.C) ValueTag;
    extern fn cubs_set_size(self: *const Set) callconv(.C) usize;
    extern fn cubs_set_contains_unchecked(self: *const Set, key: *const RawValue) callconv(.C) bool;
    extern fn cubs_set_contains(self: *const Set, key: *const CTaggedValue) callconv(.C) bool;
    extern fn cubs_set_insert_unchecked(self: *Set, key: RawValue) callconv(.C) void;
    extern fn cubs_set_insert(self: *Set, key: CTaggedValue) callconv(.C) void;
    extern fn cubs_set_erase_unchecked(self: *const Set, key: *const RawValue) callconv(.C) bool;
    extern fn cubs_set_erase(self: *const Set, key: *const CTaggedValue) callconv(.C) bool;
};

pub const Set = extern struct {
    const Self = @This();

    _inner: ?*anyopaque,

    pub fn init(inKeyTag: ValueTag) Self {
        return c.cubs_set_init(inKeyTag);
    }

    pub fn deinit(self: *Self) void {
        c.cubs_set_deinit(self);
    }

    pub fn tag(self: *const Self) ValueTag {
        return c.cubs_set_tag(self);
    }

    pub fn size(self: *const Self) usize {
        return c.cubs_set_size(self);
    }

    pub fn containsUnchecked(self: *const Self, key: *const RawValue) bool {
        return c.cubs_set_contains_unchecked(self, key);
    }

    pub fn contains(self: *const Self, key: *const TaggedValue) bool {
        const tempC = value_types.zigToCTaggedValueTemp(key.*);
        return c.cubs_set_contains(self, &tempC);
    }

    pub fn insertUnchecked(self: *Self, key: RawValue) void {
        c.cubs_set_insert_unchecked(self, key);
    }

    pub fn insert(self: *Self, key: TaggedValue) void {
        var mutKey = key;
        const cKey = @call(.always_inline, TaggedValue.intoCRepr, .{&mutKey});
        c.cubs_set_insert(self, cKey);
    }

    pub fn eraseUnchecked(self: *Self, key: *const RawValue) bool {
        return c.cubs_set_erase_unchecked(self, key);
    }

    pub fn erase(self: *Self, key: *const TaggedValue) bool {
        const tempC = value_types.zigToCTaggedValueTemp(key.*);
        return c.cubs_set_erase(self, &tempC);
    }

    test init {
        inline for (@typeInfo(ValueTag).Enum.fields) |keyF| {
            const keyEnum: ValueTag = @enumFromInt(keyF.value);
            var set = Set.init(keyEnum);
            defer set.deinit();

            try expect(set.tag() == keyEnum);
            try expect(set.size() == 0);
        }
    }

    test insertUnchecked {
        {
            var set = Set.init(.int);
            defer set.deinit();

            set.insertUnchecked(RawValue{ .int = 4 });

            try expect(set.size() == 1);
        }
        {
            var set = Set.init(.string);
            defer set.deinit();

            set.insertUnchecked(RawValue{ .string = String.initUnchecked("erm") });

            try expect(set.size() == 1);
        }
        {
            var set = Set.init(.int);
            defer set.deinit();

            for (0..100) |i| {
                set.insertUnchecked(RawValue{ .int = @intCast(i) });
            }

            try expect(set.size() == 100);
        }
        {
            var set = Set.init(.string);
            defer set.deinit();

            for (0..100) |i| {
                set.insertUnchecked(RawValue{ .string = String.fromInt(@intCast(i)) });
            }
            try expect(set.size() == 100);
        }
    }

    test insert {
        {
            var set = Set.init(.int);
            defer set.deinit();

            set.insert(TaggedValue{ .int = 4 });

            try expect(set.size() == 1);
        }
        {
            var set = Set.init(.string);
            defer set.deinit();

            set.insert(TaggedValue{ .string = String.initUnchecked("erm") });

            try expect(set.size() == 1);
        }
        {
            var set = Set.init(.int);
            defer set.deinit();

            for (0..100) |i| {
                set.insert(TaggedValue{ .int = @intCast(i) });
            }

            try expect(set.size() == 100);
        }
        {
            var set = Set.init(.string);
            defer set.deinit();

            for (0..100) |i| {
                set.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) });
            }
            try expect(set.size() == 100);
        }
    }
};
