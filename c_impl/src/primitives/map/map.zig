const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;

// Maybe its possible to combine the groups allocation with the metadata?

const c = struct {
    extern fn cubs_map_init(keyTag: ValueTag, valueTag: ValueTag) callconv(.C) Map(anyopaque, anyopaque);
    extern fn cubs_map_deinit(self: *Map(anyopaque, anyopaque)) callconv(.C) void;
    extern fn cubs_map_key_tag(self: *const Map(anyopaque, anyopaque)) callconv(.C) ValueTag;
    extern fn cubs_map_value_tag(self: *const Map(anyopaque, anyopaque)) callconv(.C) ValueTag;
    extern fn cubs_map_key_size(self: *const Map(anyopaque, anyopaque)) callconv(.C) usize;
    extern fn cubs_map_value_size(self: *const Map(anyopaque, anyopaque)) callconv(.C) usize;
    extern fn cubs_map_find_unchecked(self: *const Map(anyopaque, anyopaque), key: *const anyopaque) callconv(.C) ?*const anyopaque;
    extern fn cubs_map_find_raw_unchecked(self: *const Map(anyopaque, anyopaque), key: *const RawValue) callconv(.C) ?*const anyopaque;
    extern fn cubs_map_find(self: *const Map(anyopaque, anyopaque), key: *const CTaggedValue) callconv(.C) ?*const anyopaque;
    extern fn cubs_map_find_mut_unchecked(self: *Map(anyopaque, anyopaque), key: *const anyopaque) callconv(.C) ?*anyopaque;
    extern fn cubs_map_find_raw_mut_unchecked(self: *Map(anyopaque, anyopaque), key: *const RawValue) callconv(.C) ?*anyopaque;
    extern fn cubs_map_find_mut(self: *Map(anyopaque, anyopaque), key: *const CTaggedValue) callconv(.C) ?*anyopaque;
    extern fn cubs_map_insert_unchecked(self: *Map(anyopaque, anyopaque), key: *anyopaque, value: *anyopaque) callconv(.C) void;
    extern fn cubs_map_insert_raw_unchecked(self: *Map(anyopaque, anyopaque), key: RawValue, value: RawValue) callconv(.C) void;
    extern fn cubs_map_insert(self: *Map(anyopaque, anyopaque), key: CTaggedValue, value: CTaggedValue) callconv(.C) void;
    extern fn cubs_map_erase_unchecked(self: *const Map(anyopaque, anyopaque), key: *const anyopaque) callconv(.C) bool;
    extern fn cubs_map_erase_raw_unchecked(self: *const Map(anyopaque, anyopaque), key: *const RawValue) callconv(.C) bool;
    extern fn cubs_map_erase(self: *const Map(anyopaque, anyopaque), key: *const CTaggedValue) callconv(.C) bool;
};

pub fn Map(comptime K: type, comptime V: type) type {
    return extern struct {
        const Self = @This();

        count: usize,
        _metadata: [3]*anyopaque,

        pub fn init() Self {
            const kTag = script_value.scriptTypeToTag(K);
            const vTag = script_value.scriptTypeToTag(V);
            var temp = c.cubs_map_init(kTag, vTag);
            return temp.into(K, V);
        }

        pub fn deinit(self: *Self) void {
            c.cubs_map_deinit(self.castMut(anyopaque, anyopaque));
        }

        pub fn keyTag(self: *const Self) ValueTag {
            return c.cubs_map_key_tag(self);
        }

        pub fn valueTag(self: *const Self) ValueTag {
            return c.cubs_map_value_tag(self);
        }

        pub fn _compatSelfTag() ValueTag {
            return .map;
        }

        pub fn cast(self: *const Self, comptime OtherK: type, comptime OtherV: type) *const Map(OtherK, OtherV) {
            if (OtherK != anyopaque) {
                script_value.validateTypeMatchesTag(OtherK, self.keyTag());
            }
            if (OtherV != anyopaque) {
                script_value.validateTypeMatchesTag(OtherV, self.valueTag());
            }
            return @ptrCast(self);
        }

        pub fn castMut(self: *Self, comptime OtherK: type, comptime OtherV: type) *Map(OtherK, OtherV) {
            if (OtherK != anyopaque) {
                script_value.validateTypeMatchesTag(OtherK, self.keyTag());
            }
            if (OtherV != anyopaque) {
                script_value.validateTypeMatchesTag(OtherV, self.valueTag());
            }
            return @ptrCast(self);
        }

        /// Converts an array of one type into an array of another type. Currently only works when converting
        /// to and from `anyopaque` arrays.
        pub fn into(self: *Self, comptime OtherK: type, comptime OtherV: type) Map(OtherK, OtherV) {
            const casted = self.castMut(OtherK, OtherV).*;
            self.* = undefined; // invalidate self
            return casted;
        }

        pub fn find(self: *const Self, key: *const K) ?*const V {
            return @ptrCast(@alignCast(c.cubs_map_find_unchecked(self.cast(anyopaque, anyopaque), @ptrCast(key))));
        }

        pub fn findTagged(self: *const Self, key: *const TaggedValue) ?*const V {
            const tempC = script_value.zigToCTaggedValueTemp(key.*);
            return @ptrCast(@alignCast(c.cubs_map_find(self.cast(anyopaque, anyopaque), &tempC)));
        }

        pub fn findRawUnchecked(self: *const Self, key: *const RawValue) ?*const V {
            return @ptrCast(@alignCast(c.cubs_map_find_raw_unchecked(self.cast(anyopaque, anyopaque), key)));
        }

        pub fn findMut(self: *Self, key: *const K) ?*V {
            return @ptrCast(@alignCast(c.cubs_map_find_mut_unchecked(self.castMut(anyopaque, anyopaque), key)));
        }

        pub fn findMutTagged(self: *Self, key: *const TaggedValue) ?*V {
            const tempC = script_value.zigToCTaggedValueTemp(key.*);
            return @ptrCast(@alignCast(c.cubs_map_find_mut(self.castMut(anyopaque, anyopaque), &tempC)));
        }

        pub fn findRawMutUnchecked(self: *Self, key: *const RawValue) ?*V {
            return @ptrCast(@alignCast(c.cubs_map_find_raw_mut_unchecked(self.castMut(anyopaque, anyopaque), key)));
        }

        pub fn insert(self: *Self, key: K, value: V) void {
            var mutKey = key;
            var mutValue = value;
            c.cubs_map_insert_unchecked(self.castMut(anyopaque, anyopaque), @ptrCast(&mutKey), @ptrCast(&mutValue));
        }

        pub fn insertTagged(self: *Self, key: TaggedValue, value: TaggedValue) void {
            var mutKey = key;
            var mutValue = value;
            const cKey = @call(.always_inline, TaggedValue.intoCRepr, .{&mutKey});
            const cValue = @call(.always_inline, TaggedValue.intoCRepr, .{&mutValue});
            c.cubs_map_insert(self.castMut(anyopaque, anyopaque), cKey, cValue);
        }

        pub fn insertUnchecked(self: *Self, key: RawValue, value: RawValue) void {
            c.cubs_map_insert_raw_unchecked(self.castMut(anyopaque, anyopaque), key, value);
        }

        pub fn erase(self: *Self, key: *const K) bool {
            const tempC = script_value.zigToCTaggedValueTemp(key.*);
            return c.cubs_map_erase_unchecked(self.castMut(anyopaque, anyopaque), &tempC);
        }

        pub fn eraseTagged(self: *Self, key: *const TaggedValue) bool {
            const tempC = script_value.zigToCTaggedValueTemp(key.*);
            return c.cubs_map_erase(self.castMut(anyopaque, anyopaque), &tempC);
        }

        pub fn eraseUnchecked(self: *Self, key: *const RawValue) bool {
            return c.cubs_map_erase_raw_unchecked(self.castMut(anyopaque, anyopaque), key);
        }

        // test init {
        //     inline for (@typeInfo(ValueTag).Enum.fields) |keyF| {
        //         const keyEnum: ValueTag = @enumFromInt(keyF.value);
        //         inline for (@typeInfo(ValueTag).Enum.fields) |valueF| {
        //             const valueEnum: ValueTag = @enumFromInt(valueF.value);

        //             var map = Map.init(keyEnum, valueEnum);
        //             defer map.deinit();

        //             try expect(map.keyTag() == keyEnum);
        //             try expect(map.valueTag() == valueEnum);
        //             try expect(map.count == 0);
        //         }
        //     }
        // }

        test insert {
            {
                var map = Map(i64, String).init();
                defer map.deinit();

                map.insert(4, String.initUnchecked("hello world!"));

                try expect(map.count == 1);
            }
            {
                var map = Map(String, String).init();
                defer map.deinit();

                map.insert(String.initUnchecked("erm"), String.initUnchecked("hello world!"));

                try expect(map.count == 1);
            }
            {
                var map = Map(i64, String).init();
                defer map.deinit();

                for (0..100) |i| {
                    map.insert(@intCast(i), String.initUnchecked("hello world!"));
                }

                try expect(map.count == 100);
            }
            {
                var map = Map(String, String).init();
                defer map.deinit();

                for (0..100) |i| {
                    map.insert(String.fromInt(@intCast(i)), String.initUnchecked("hello world!"));
                }
                try expect(map.count == 100);
            }
        }

        test insertTagged {
            {
                var map = Map(i64, String).init();
                defer map.deinit();

                map.insertTagged(TaggedValue{ .int = 4 }, TaggedValue{ .string = String.initUnchecked("hello world!") });

                try expect(map.count == 1);
            }
            {
                var map = Map(String, String).init();
                defer map.deinit();

                map.insertTagged(TaggedValue{ .string = String.initUnchecked("erm") }, TaggedValue{ .string = String.initUnchecked("hello world!") });

                try expect(map.count == 1);
            }
            {
                var map = Map(i64, String).init();
                defer map.deinit();

                for (0..100) |i| {
                    map.insertTagged(TaggedValue{ .int = @intCast(i) }, TaggedValue{ .string = String.initUnchecked("hello world!") });
                }

                try expect(map.count == 100);
            }
            {
                var map = Map(String, String).init();
                defer map.deinit();

                for (0..100) |i| {
                    map.insertTagged(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("hello world!") });
                }
                try expect(map.count == 100);
            }
        }

        test insertUnchecked {
            {
                var map = Map(i64, String).init();
                defer map.deinit();

                map.insertUnchecked(RawValue{ .int = 4 }, RawValue{ .string = String.initUnchecked("hello world!") });

                try expect(map.count == 1);
            }
            {
                var map = Map(String, String).init();
                defer map.deinit();

                map.insertUnchecked(RawValue{ .string = String.initUnchecked("erm") }, RawValue{ .string = String.initUnchecked("hello world!") });

                try expect(map.count == 1);
            }
            {
                var map = Map(i64, String).init();
                defer map.deinit();

                for (0..100) |i| {
                    map.insertUnchecked(RawValue{ .int = @intCast(i) }, RawValue{ .string = String.initUnchecked("hello world!") });
                }

                try expect(map.count == 100);
            }
            {
                var map = Map(String, String).init();
                defer map.deinit();

                for (0..100) |i| {
                    map.insertUnchecked(RawValue{ .string = String.fromInt(@intCast(i)) }, RawValue{ .string = String.initUnchecked("hello world!") });
                }
                try expect(map.count == 100);
            }
        }

        test find {
            var map = Map(String, String).init();
            defer map.deinit();

            var firstFind = String.initUnchecked("erm");
            defer firstFind.deinit();

            if (map.find(&firstFind)) |_| {
                try expect(false);
            } else {}

            map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

            if (map.find(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
            }

            try expect(map.count == 100);

            if (map.find(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                var findVal = String.fromInt(@intCast(i));
                defer findVal.deinit();

                if (map.find(&findVal)) |found| {
                    try expect(found.eqlSlice("wuh"));
                } else {
                    try expect(false);
                }
            }

            for (100..150) |i| {
                var findVal = String.fromInt(@intCast(i));
                defer findVal.deinit();

                if (map.find(&findVal)) |_| {
                    try expect(false);
                } else {}
            }
        }

        test findTagged {
            var map = Map(String, String).init();
            defer map.deinit();

            var firstFind = TaggedValue{ .string = String.initUnchecked("erm") };
            defer firstFind.deinit();

            if (map.findTagged(&firstFind)) |_| {
                try expect(false);
            } else {}

            map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

            if (map.findTagged(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
            }

            try expect(map.count == 100);

            if (map.findTagged(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit();

                if (map.findTagged(&findVal)) |found| {
                    try expect(found.eqlSlice("wuh"));
                } else {
                    try expect(false);
                }
            }

            for (100..150) |i| {
                var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit();

                if (map.findTagged(&findVal)) |_| {
                    try expect(false);
                } else {}
            }
        }

        test findRawUnchecked {
            var map = Map(String, String).init();
            defer map.deinit();

            var firstFind = RawValue{ .string = String.initUnchecked("erm") };
            defer firstFind.deinit(.string);

            if (map.findRawUnchecked(&firstFind)) |_| {
                try expect(false);
            } else {}

            map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

            if (map.findRawUnchecked(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
            }

            try expect(map.count == 100);

            if (map.findRawUnchecked(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit(.string);

                if (map.findRawUnchecked(&findVal)) |found| {
                    try expect(found.eqlSlice("wuh"));
                } else {
                    try expect(false);
                }
            }

            for (100..150) |i| {
                var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit(.string);

                if (map.findRawUnchecked(&findVal)) |_| {
                    try expect(false);
                } else {}
            }
        }

        test findMut {
            var map = Map(String, String).init();
            defer map.deinit();

            var firstFind = String.initUnchecked("erm");
            defer firstFind.deinit();

            if (map.findMut(&firstFind)) |_| {
                try expect(false);
            } else {}

            map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

            if (map.findMut(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
                found.deinit();
                found.* = String.initUnchecked("holy moly");
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
            }

            try expect(map.count == 100);

            if (map.findMut(&firstFind)) |found| {
                try expect(found.eqlSlice("holy moly"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                var findVal = String.fromInt(@intCast(i));
                defer findVal.deinit();

                if (map.findMut(&findVal)) |found| {
                    try expect(found.eqlSlice("wuh"));
                    found.deinit();
                    found.* = String.initUnchecked("holy moly");
                } else {
                    try expect(false);
                }
            }

            for (0..99) |i| {
                var findVal = String.fromInt(@intCast(i));
                defer findVal.deinit();

                if (map.findMut(&findVal)) |found| {
                    try expect(found.eqlSlice("holy moly"));
                } else {
                    try expect(false);
                }
            }

            for (100..150) |i| {
                var findVal = String.fromInt(@intCast(i));
                defer findVal.deinit();

                if (map.findMut(&findVal)) |_| {
                    try expect(false);
                } else {}
            }
        }

        test findMutTagged {
            var map = Map(String, String).init();
            defer map.deinit();

            var firstFind = TaggedValue{ .string = String.initUnchecked("erm") };
            defer firstFind.deinit();

            if (map.findMutTagged(&firstFind)) |_| {
                try expect(false);
            } else {}

            map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

            if (map.findMutTagged(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
                found.deinit();
                found.* = String.initUnchecked("holy moly");
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
            }

            try expect(map.count == 100);

            if (map.findMutTagged(&firstFind)) |found| {
                try expect(found.eqlSlice("holy moly"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit();

                if (map.findMutTagged(&findVal)) |found| {
                    try expect(found.eqlSlice("wuh"));
                    found.deinit();
                    found.* = String.initUnchecked("holy moly");
                } else {
                    try expect(false);
                }
            }

            for (0..99) |i| {
                var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit();

                if (map.findMutTagged(&findVal)) |found| {
                    try expect(found.eqlSlice("holy moly"));
                } else {
                    try expect(false);
                }
            }

            for (100..150) |i| {
                var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit();

                if (map.findMutTagged(&findVal)) |_| {
                    try expect(false);
                } else {}
            }
        }

        test findRawMutUnchecked {
            var map = Map(String, String).init();
            defer map.deinit();

            var firstFind = RawValue{ .string = String.initUnchecked("erm") };
            defer firstFind.deinit(.string);

            if (map.findRawMutUnchecked(&firstFind)) |_| {
                try expect(false);
            } else {}

            map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

            if (map.findRawMutUnchecked(&firstFind)) |found| {
                try expect(found.eqlSlice("wuh"));
                found.deinit();
                found.* = String.initUnchecked("holy moly");
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
            }

            try expect(map.count == 100);

            if (map.findRawMutUnchecked(&firstFind)) |found| {
                try expect(found.eqlSlice("holy moly"));
            } else {
                try expect(false);
            }

            for (0..99) |i| {
                var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit(.string);

                if (map.findRawMutUnchecked(&findVal)) |found| {
                    try expect(found.eqlSlice("wuh"));
                    found.deinit();
                    found.* = String.initUnchecked("holy moly");
                } else {
                    try expect(false);
                }
            }

            for (0..99) |i| {
                var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit(.string);

                if (map.findRawMutUnchecked(&findVal)) |found| {
                    try expect(found.eqlSlice("holy moly"));
                } else {
                    try expect(false);
                }
            }

            for (100..150) |i| {
                var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit(.string);

                if (map.findRawMutUnchecked(&findVal)) |_| {
                    try expect(false);
                } else {}
            }
        }

        // test eraseUnchecked {
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         var eraseVal = RawValue{ .string = String.initUnchecked("erm") };
        //         defer eraseVal.deinit(.string);

        //         try expect(map.eraseUnchecked(&eraseVal) == false);

        //         map.insert(String.initUnchecked("erm"), TaggedValue{ .string = String.initUnchecked("wuh") });
        //         try expect(map.count == 1);

        //         try expect(map.eraseUnchecked(&eraseVal) == true);
        //         try expect(map.count == 0);
        //     }
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         for (0..100) |i| {
        //             map.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("wuh") });
        //         }

        //         try expect(map.count == 100);

        //         for (0..50) |i| {
        //             var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit(.string);

        //             try expect(map.eraseUnchecked(&eraseVal) == true);
        //         }

        //         try expect(map.count == 50);

        //         for (0..50) |i| {
        //             var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit(.string);

        //             try expect(map.eraseUnchecked(&eraseVal) == false);
        //         }
        //         try expect(map.count == 50);

        //         for (50..100) |i| {
        //             var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit(.string);

        //             try expect(map.eraseUnchecked(&eraseVal) == true);
        //         }
        //     }
        // }

        // test erase {
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         var eraseVal = TaggedValue{ .string = String.initUnchecked("erm") };
        //         defer eraseVal.deinit();

        //         try expect(map.erase(&eraseVal) == false);

        //         map.insert(String.initUnchecked("erm"), TaggedValue{ .string = String.initUnchecked("wuh") });
        //         try expect(map.count == 1);

        //         try expect(map.erase(&eraseVal) == true);
        //         try expect(map.count == 0);
        //     }
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         for (0..100) |i| {
        //             map.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("wuh") });
        //         }

        //         try expect(map.count == 100);

        //         for (0..50) |i| {
        //             var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit();

        //             try expect(map.erase(&eraseVal) == true);
        //         }

        //         try expect(map.count == 50);

        //         for (0..50) |i| {
        //             var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit();

        //             try expect(map.erase(&eraseVal) == false);
        //         }
        //         try expect(map.count == 50);

        //         for (50..100) |i| {
        //             var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit();

        //             try expect(map.erase(&eraseVal) == true);
        //         }
        //     }
        // }
    };
}
