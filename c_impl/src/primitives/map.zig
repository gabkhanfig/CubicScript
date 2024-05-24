const std = @import("std");
const expect = std.testing.expect;
const value_types = @import("values.zig");
const ValueTag = value_types.ValueTag;
const RawValue = value_types.RawValue;
const CTaggedValue = value_types.CTaggedValue;
const TaggedValue = value_types.TaggedValue;
const String = @import("string.zig").String;

const c = struct {
    extern fn cubs_map_init(keyTag: ValueTag, valueTag: ValueTag) callconv(.C) Map;
    extern fn cubs_map_deinit(self: *Map) callconv(.C) void;
    extern fn cubs_map_key_tag(self: *const Map) callconv(.C) ValueTag;
    extern fn cubs_map_value_tag(self: *const Map) callconv(.C) ValueTag;
    extern fn cubs_map_size(self: *const Map) callconv(.C) usize;
    extern fn cubs_map_find_unchecked(self: *const Map, key: *const RawValue) callconv(.C) ?*const RawValue;
    extern fn cubs_map_find(self: *const Map, key: *const CTaggedValue) callconv(.C) ?*const RawValue;
    extern fn cubs_map_find_mut_unchecked(self: *Map, key: *const RawValue) callconv(.C) ?*RawValue;
    extern fn cubs_map_find_mut(self: *Map, key: *const CTaggedValue) callconv(.C) ?*RawValue;
    extern fn cubs_map_insert_unchecked(self: *Map, key: RawValue, value: RawValue) callconv(.C) void;
    extern fn cubs_map_insert(self: *Map, key: CTaggedValue, value: CTaggedValue) callconv(.C) void;
};

pub const Map = extern struct {
    const Self = @This();

    _inner: ?*anyopaque,

    pub fn init(inKeyTag: ValueTag, inValueTag: ValueTag) Self {
        return c.cubs_map_init(inKeyTag, inValueTag);
    }

    pub fn deinit(self: *Self) void {
        c.cubs_map_deinit(self);
    }

    pub fn keyTag(self: *const Self) ValueTag {
        return c.cubs_map_key_tag(self);
    }

    pub fn valueTag(self: *const Self) ValueTag {
        return c.cubs_map_value_tag(self);
    }

    pub fn size(self: *const Self) usize {
        return c.cubs_map_size(self);
    }

    pub fn findUnchecked(self: *const Self, key: *const RawValue) ?*const RawValue {
        return c.cubs_map_find_unchecked(self, key);
    }

    pub fn find(self: *const Self, key: *const CTaggedValue) ?*const RawValue {
        return c.cubs_map_find(self, key);
    }

    pub fn findMutUnchecked(self: *Self, key: *const RawValue) ?*RawValue {
        return c.cubs_map_find_mut_unchecked(self, key);
    }

    pub fn findMut(self: *Self, key: *const CTaggedValue) ?*RawValue {
        return c.cubs_map_find_mut(self, key);
    }

    pub fn insertUnchecked(self: *Self, key: RawValue, value: RawValue) void {
        c.cubs_map_insert_unchecked(self, key, value);
    }

    pub fn insert(self: *Self, key: CTaggedValue, value: CTaggedValue) void {
        c.cubs_map_insert(self, key, value);
    }

    test init {
        inline for (@typeInfo(ValueTag).Enum.fields) |keyF| {
            const keyEnum: ValueTag = @enumFromInt(keyF.value);
            inline for (@typeInfo(ValueTag).Enum.fields) |valueF| {
                const valueEnum: ValueTag = @enumFromInt(valueF.value);

                var map = Map.init(keyEnum, valueEnum);
                defer map.deinit();

                try expect(map.keyTag() == keyEnum);
                try expect(map.valueTag() == valueEnum);
                try expect(map.size() == 0);
            }
        }
    }

    test insertUnchecked {
        {
            var map = Map.init(.int, .string);
            defer map.deinit();

            map.insertUnchecked(RawValue{ .int = 4 }, RawValue{ .string = String.initUnchecked("hello world!") });

            try expect(map.size() == 1);
        }
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            map.insertUnchecked(RawValue{ .string = String.initUnchecked("erm") }, RawValue{ .string = String.initUnchecked("hello world!") });

            try expect(map.size() == 1);
        }
        {
            var map = Map.init(.int, .string);
            defer map.deinit();

            for (0..100) |i| {
                map.insertUnchecked(RawValue{ .int = @intCast(i) }, RawValue{ .string = String.initUnchecked("hello world!") });
            }

            try expect(map.size() == 100);
        }
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            for (0..100) |i| {
                map.insertUnchecked(RawValue{ .string = String.fromInt(@intCast(i)) }, RawValue{ .string = String.initUnchecked("hello world!") });
            }
            try expect(map.size() == 100);
        }
    }

    test insert {
        {
            var map = Map.init(.int, .string);
            defer map.deinit();

            map.insert(
                CTaggedValue{ .tag = .int, .value = RawValue{ .int = 4 } },
                CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hello world!") } },
            );

            try expect(map.size() == 1);
        }
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            map.insert(
                CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("erm") } },
                CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hello world!") } },
            );

            try expect(map.size() == 1);
        }
        {
            var map = Map.init(.int, .string);
            defer map.deinit();

            for (0..100) |i| {
                map.insert(
                    CTaggedValue{ .tag = .int, .value = RawValue{ .int = @intCast(i) } },
                    CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hello world!") } },
                );
            }

            try expect(map.size() == 100);
        }
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            for (0..100) |i| {
                map.insert(
                    CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.fromInt(@intCast(i)) } },
                    CTaggedValue{ .tag = .string, .value = RawValue{ .string = String.initUnchecked("hello world!") } },
                );
            }
            try expect(map.size() == 100);
        }
    }
};
