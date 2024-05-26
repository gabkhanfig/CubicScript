const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;

// Maybe its possible to combine the groups allocation with the metadata?

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
    extern fn cubs_map_erase_unchecked(self: *const Map, key: *const RawValue) callconv(.C) bool;
    extern fn cubs_map_erase(self: *const Map, key: *const CTaggedValue) callconv(.C) bool;
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

    pub fn find(self: *const Self, key: *const TaggedValue) ?*const RawValue {
        const tempC = script_value.zigToCTaggedValueTemp(key.*);
        return c.cubs_map_find(self, &tempC);
    }

    pub fn findMutUnchecked(self: *Self, key: *const RawValue) ?*RawValue {
        return c.cubs_map_find_mut_unchecked(self, key);
    }

    pub fn findMut(self: *Self, key: *const TaggedValue) ?*RawValue {
        const tempC = script_value.zigToCTaggedValueTemp(key.*);
        return c.cubs_map_find_mut(self, &tempC);
    }

    pub fn insertUnchecked(self: *Self, key: RawValue, value: RawValue) void {
        c.cubs_map_insert_unchecked(self, key, value);
    }

    pub fn insert(self: *Self, key: TaggedValue, value: TaggedValue) void {
        var mutKey = key;
        var mutValue = value;
        const cKey = @call(.always_inline, TaggedValue.intoCRepr, .{&mutKey});
        const cValue = @call(.always_inline, TaggedValue.intoCRepr, .{&mutValue});
        c.cubs_map_insert(self, cKey, cValue);
    }

    pub fn eraseUnchecked(self: *Self, key: *const RawValue) bool {
        return c.cubs_map_erase_unchecked(self, key);
    }

    pub fn erase(self: *Self, key: *const TaggedValue) bool {
        const tempC = script_value.zigToCTaggedValueTemp(key.*);
        return c.cubs_map_erase(self, &tempC);
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
                TaggedValue{ .int = 4 },
                TaggedValue{ .string = String.initUnchecked("hello world!") },
            );

            try expect(map.size() == 1);
        }
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            map.insert(
                TaggedValue{ .string = String.initUnchecked("erm") },
                TaggedValue{ .string = String.initUnchecked("hello world!") },
            );

            try expect(map.size() == 1);
        }
        {
            var map = Map.init(.int, .string);
            defer map.deinit();

            for (0..100) |i| {
                map.insert(
                    TaggedValue{ .int = @intCast(i) },
                    TaggedValue{ .string = String.initUnchecked("hello world!") },
                );
            }

            try expect(map.size() == 100);
        }
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            for (0..100) |i| {
                map.insert(
                    TaggedValue{ .string = String.fromInt(@intCast(i)) },
                    TaggedValue{ .string = String.initUnchecked("hello world!") },
                );
            }
            try expect(map.size() == 100);
        }
    }

    test findUnchecked {
        var map = Map.init(.string, .string);
        defer map.deinit();

        var firstFind = RawValue{ .string = String.initUnchecked("erm") };
        defer firstFind.deinit(.string);

        if (map.findUnchecked(&firstFind)) |_| {
            try expect(false);
        } else {}

        map.insert(TaggedValue{ .string = String.initUnchecked("erm") }, TaggedValue{ .string = String.initUnchecked("wuh") });

        if (map.findUnchecked(&firstFind)) |found| {
            try expect(found.string.eqlSlice("wuh"));
        } else {
            try expect(false);
        }

        for (0..99) |i| {
            map.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("wuh") });
        }

        try expect(map.size() == 100);

        if (map.findUnchecked(&firstFind)) |found| {
            try expect(found.string.eqlSlice("wuh"));
        } else {
            try expect(false);
        }

        for (0..99) |i| {
            var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit(.string);

            if (map.findUnchecked(&findVal)) |found| {
                try expect(found.string.eqlSlice("wuh"));
            } else {
                try expect(false);
            }
        }

        for (100..150) |i| {
            var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit(.string);

            if (map.findUnchecked(&findVal)) |_| {
                try expect(false);
            } else {}
        }
    }

    test find {
        var map = Map.init(.string, .string);
        defer map.deinit();

        var firstFind = TaggedValue{ .string = String.initUnchecked("erm") };
        defer firstFind.deinit();

        if (map.find(&firstFind)) |_| {
            try expect(false);
        } else {}

        map.insert(TaggedValue{ .string = String.initUnchecked("erm") }, TaggedValue{ .string = String.initUnchecked("wuh") });

        if (map.find(&firstFind)) |found| {
            try expect(found.string.eqlSlice("wuh"));
        } else {
            try expect(false);
        }

        for (0..99) |i| {
            map.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("wuh") });
        }

        try expect(map.size() == 100);

        if (map.find(&firstFind)) |found| {
            try expect(found.string.eqlSlice("wuh"));
        } else {
            try expect(false);
        }

        for (0..99) |i| {
            var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit();

            if (map.find(&findVal)) |found| {
                try expect(found.string.eqlSlice("wuh"));
            } else {
                try expect(false);
            }
        }

        for (100..150) |i| {
            var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit();

            if (map.find(&findVal)) |_| {
                try expect(false);
            } else {}
        }
    }

    test findMutUnchecked {
        var map = Map.init(.string, .string);
        defer map.deinit();

        var firstFind = RawValue{ .string = String.initUnchecked("erm") };
        defer firstFind.deinit(.string);

        if (map.findMutUnchecked(&firstFind)) |_| {
            try expect(false);
        } else {}

        map.insert(TaggedValue{ .string = String.initUnchecked("erm") }, TaggedValue{ .string = String.initUnchecked("wuh") });

        if (map.findMutUnchecked(&firstFind)) |found| {
            try expect(found.string.eqlSlice("wuh"));
            found.deinit(.string);
            found.string = String.initUnchecked("holy moly");
        } else {
            try expect(false);
        }

        for (0..99) |i| {
            map.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("wuh") });
        }

        try expect(map.size() == 100);

        if (map.findMutUnchecked(&firstFind)) |found| {
            try expect(found.string.eqlSlice("holy moly"));
        } else {
            try expect(false);
        }

        for (0..99) |i| {
            var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit(.string);

            if (map.findMutUnchecked(&findVal)) |found| {
                try expect(found.string.eqlSlice("wuh"));
                found.deinit(.string);
                found.string = String.initUnchecked("holy moly");
            } else {
                try expect(false);
            }
        }

        for (0..99) |i| {
            var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit(.string);

            if (map.findUnchecked(&findVal)) |found| {
                try expect(found.string.eqlSlice("holy moly"));
            } else {
                try expect(false);
            }
        }

        for (100..150) |i| {
            var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit(.string);

            if (map.findMutUnchecked(&findVal)) |_| {
                try expect(false);
            } else {}
        }
    }

    test findMut {
        var map = Map.init(.string, .string);
        defer map.deinit();

        var firstFind = TaggedValue{ .string = String.initUnchecked("erm") };
        defer firstFind.deinit();

        if (map.findMut(&firstFind)) |_| {
            try expect(false);
        } else {}

        map.insert(TaggedValue{ .string = String.initUnchecked("erm") }, TaggedValue{ .string = String.initUnchecked("wuh") });

        if (map.findMut(&firstFind)) |found| {
            try expect(found.string.eqlSlice("wuh"));
            found.deinit(.string);
            found.string = String.initUnchecked("holy moly");
        } else {
            try expect(false);
        }

        for (0..99) |i| {
            map.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("wuh") });
        }

        try expect(map.size() == 100);

        if (map.findMut(&firstFind)) |found| {
            try expect(found.string.eqlSlice("holy moly"));
        } else {
            try expect(false);
        }

        for (0..99) |i| {
            var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit();

            if (map.findMut(&findVal)) |found| {
                try expect(found.string.eqlSlice("wuh"));
                found.deinit(.string);
                found.string = String.initUnchecked("holy moly");
            } else {
                try expect(false);
            }
        }

        for (0..99) |i| {
            var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit();

            if (map.find(&findVal)) |found| {
                try expect(found.string.eqlSlice("holy moly"));
            } else {
                try expect(false);
            }
        }

        for (100..150) |i| {
            var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit();

            if (map.findMut(&findVal)) |_| {
                try expect(false);
            } else {}
        }
    }

    test eraseUnchecked {
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            var eraseVal = RawValue{ .string = String.initUnchecked("erm") };
            defer eraseVal.deinit(.string);

            try expect(map.eraseUnchecked(&eraseVal) == false);

            map.insert(TaggedValue{ .string = String.initUnchecked("erm") }, TaggedValue{ .string = String.initUnchecked("wuh") });
            try expect(map.size() == 1);

            try expect(map.eraseUnchecked(&eraseVal) == true);
            try expect(map.size() == 0);
        }
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            for (0..100) |i| {
                map.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("wuh") });
            }

            try expect(map.size() == 100);

            for (0..50) |i| {
                var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit(.string);

                try expect(map.eraseUnchecked(&eraseVal) == true);
            }

            try expect(map.size() == 50);

            for (0..50) |i| {
                var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit(.string);

                try expect(map.eraseUnchecked(&eraseVal) == false);
            }
            try expect(map.size() == 50);

            for (50..100) |i| {
                var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit(.string);

                try expect(map.eraseUnchecked(&eraseVal) == true);
            }
        }
    }

    test erase {
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            var eraseVal = TaggedValue{ .string = String.initUnchecked("erm") };
            defer eraseVal.deinit();

            try expect(map.erase(&eraseVal) == false);

            map.insert(TaggedValue{ .string = String.initUnchecked("erm") }, TaggedValue{ .string = String.initUnchecked("wuh") });
            try expect(map.size() == 1);

            try expect(map.erase(&eraseVal) == true);
            try expect(map.size() == 0);
        }
        {
            var map = Map.init(.string, .string);
            defer map.deinit();

            for (0..100) |i| {
                map.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("wuh") });
            }

            try expect(map.size() == 100);

            for (0..50) |i| {
                var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit();

                try expect(map.erase(&eraseVal) == true);
            }

            try expect(map.size() == 50);

            for (0..50) |i| {
                var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit();

                try expect(map.erase(&eraseVal) == false);
            }
            try expect(map.size() == 50);

            for (50..100) |i| {
                var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit();

                try expect(map.erase(&eraseVal) == true);
            }
        }
    }
};
