const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;

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
        const tempC = script_value.zigToCTaggedValueTemp(key.*);
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
        const tempC = script_value.zigToCTaggedValueTemp(key.*);
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

    test containsUnchecked {
        var set = Set.init(.string);
        defer set.deinit();

        var firstFind = RawValue{ .string = String.initUnchecked("erm") };
        defer firstFind.deinit(.string);

        try expect(set.containsUnchecked(&firstFind) == false);

        set.insert(TaggedValue{ .string = String.initUnchecked("erm") });

        try expect(set.containsUnchecked(&firstFind));

        for (0..99) |i| {
            set.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) });
        }

        try expect(set.size() == 100);

        try expect(set.containsUnchecked(&firstFind));

        for (0..99) |i| {
            var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit(.string);

            try expect(set.containsUnchecked(&firstFind));
        }

        for (100..150) |i| {
            var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit(.string);

            try expect(set.containsUnchecked(&findVal) == false);
        }
    }

    test contains {
        var set = Set.init(.string);
        defer set.deinit();

        var firstFind = TaggedValue{ .string = String.initUnchecked("erm") };
        defer firstFind.deinit();

        try expect(set.contains(&firstFind) == false);

        set.insert(TaggedValue{ .string = String.initUnchecked("erm") });

        try expect(set.contains(&firstFind));

        for (0..99) |i| {
            set.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) });
        }

        try expect(set.size() == 100);

        try expect(set.contains(&firstFind));

        for (0..99) |i| {
            var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit();

            try expect(set.contains(&firstFind));
        }

        for (100..150) |i| {
            var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
            defer findVal.deinit();

            try expect(set.contains(&findVal) == false);
        }
    }

    test eraseUnchecked {
        {
            var set = Set.init(.string);
            defer set.deinit();

            var eraseVal = RawValue{ .string = String.initUnchecked("erm") };
            defer eraseVal.deinit(.string);

            try expect(set.eraseUnchecked(&eraseVal) == false);

            set.insert(TaggedValue{ .string = String.initUnchecked("erm") });
            try expect(set.size() == 1);

            try expect(set.eraseUnchecked(&eraseVal) == true);
            try expect(set.size() == 0);
        }
        {
            var set = Set.init(.string);
            defer set.deinit();

            for (0..100) |i| {
                set.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) });
            }

            try expect(set.size() == 100);

            for (0..50) |i| {
                var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit(.string);

                try expect(set.eraseUnchecked(&eraseVal) == true);
            }

            try expect(set.size() == 50);

            for (0..50) |i| {
                var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit(.string);

                try expect(set.eraseUnchecked(&eraseVal) == false);
            }
            try expect(set.size() == 50);

            for (50..100) |i| {
                var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit(.string);

                try expect(set.eraseUnchecked(&eraseVal) == true);
            }
        }
    }

    test erase {
        {
            var set = Set.init(.string);
            defer set.deinit();

            var eraseVal = TaggedValue{ .string = String.initUnchecked("erm") };
            defer eraseVal.deinit();

            try expect(set.erase(&eraseVal) == false);

            set.insert(TaggedValue{ .string = String.initUnchecked("erm") });
            try expect(set.size() == 1);

            try expect(set.erase(&eraseVal) == true);
            try expect(set.size() == 0);
        }
        {
            var set = Set.init(.string);
            defer set.deinit();

            for (0..100) |i| {
                set.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) });
            }

            try expect(set.size() == 100);

            for (0..50) |i| {
                var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit();

                try expect(set.erase(&eraseVal) == true);
            }

            try expect(set.size() == 50);

            for (0..50) |i| {
                var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit();

                try expect(set.erase(&eraseVal) == false);
            }
            try expect(set.size() == 50);

            for (50..100) |i| {
                var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer eraseVal.deinit();

                try expect(set.erase(&eraseVal) == true);
            }
        }
    }
};
