const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;

const c = struct {
    extern fn cubs_set_init(keyTag: ValueTag) callconv(.C) Set(anyopaque);
    extern fn cubs_set_deinit(self: *Set(anyopaque)) callconv(.C) void;
    extern fn cubs_set_tag(self: *const Set(anyopaque)) callconv(.C) ValueTag;
    extern fn cubs_set_size(self: *const Set(anyopaque)) callconv(.C) usize;
    extern fn cubs_set_contains_unchecked(self: *const Set, key: *const anyopaque) callconv(.C) bool;
    extern fn cubs_set_contains_raw_unchecked(self: *const Set, key: *const RawValue) callconv(.C) bool;
    extern fn cubs_set_contains(self: *const Set(anyopaque), key: *const CTaggedValue) callconv(.C) bool;
    extern fn cubs_set_insert_unchecked(self: *Set(anyopaque), key: *anyopaque) callconv(.C) void;
    extern fn cubs_set_insert_raw_unchecked(self: *Set(anyopaque), key: RawValue) callconv(.C) void;
    extern fn cubs_set_insert(self: *Set(anyopaque), key: CTaggedValue) callconv(.C) void;
    extern fn cubs_set_erase_unchecked(self: *Set(anyopaque), key: *const anyopaque) callconv(.C) bool;
    extern fn cubs_set_erase_raw_unchecked(self: *Set(anyopaque), key: *const RawValue) callconv(.C) bool;
    extern fn cubs_set_erase(self: *Set(anyopaque), key: *const CTaggedValue) callconv(.C) bool;
};

pub fn Set(comptime K: type) type {
    return extern struct {
        const Self = @This();

        count: usize,
        _metadata: [3]*anyopaque,

        pub fn init() Self {
            const kTag = script_value.scriptTypeToTag(K);
            var temp = c.cubs_set_init(kTag);
            return temp.into(K);
        }

        pub fn deinit(self: *Self) void {
            c.cubs_set_deinit(self.castMut(anyopaque));
        }

        pub fn tag(self: *const Self) ValueTag {
            return c.cubs_set_tag(self.cast(anyopaque));
        }

        pub fn _compatSelfTag() ValueTag {
            return .set;
        }

        pub fn cast(self: *const Self, comptime OtherK: type) *const Set(OtherK) {
            if (OtherK != anyopaque) {
                script_value.validateTypeMatchesTag(OtherK, self.tag());
            }
            return @ptrCast(self);
        }

        pub fn castMut(self: *Self, comptime OtherK: type) *Set(OtherK) {
            if (OtherK != anyopaque) {
                script_value.validateTypeMatchesTag(OtherK, self.tag());
            }
            return @ptrCast(self);
        }

        /// Converts an array of one type into an array of another type. Currently only works when converting
        /// to and from `anyopaque` arrays.
        pub fn into(self: *Self, comptime OtherK: type) Set(OtherK) {
            const casted = self.castMut(OtherK).*;
            self.* = undefined; // invalidate self
            return casted;
        }

        pub fn contains(self: *const Self, key: *const K) bool {
            return c.cubs_set_contains_unchecked(self.cast(anyopaque), @ptrCast(key));
        }

        pub fn containsRawUnchecked(self: *const Self, key: *const RawValue) bool {
            return c.cubs_set_contains_raw_unchecked(self.cast(anyopaque), key);
        }

        pub fn containsTagged(self: *const Self, key: *const TaggedValue) bool {
            const tempC = script_value.zigToCTaggedValueTemp(key.*);
            return c.cubs_set_contains(self.cast(anyopaque), &tempC);
        }

        pub fn insert(self: *Self, key: K) void {
            var tempKey = key;
            c.cubs_set_insert_unchecked(self.castMut(anyopaque), @ptrCast(&tempKey));
        }

        pub fn insertRawUnchecked(self: *Self, key: RawValue) void {
            c.cubs_set_insert_raw_unchecked(self.castMut(anyopaque), key);
        }

        pub fn insertTagged(self: *Self, key: TaggedValue) void {
            var mutKey = key;
            const cKey = @call(.always_inline, TaggedValue.intoCRepr, .{&mutKey});
            c.cubs_set_insert(self.castMut(anyopaque), cKey);
        }

        pub fn erase(self: *Self, key: *const K) bool {
            return c.cubs_set_erase_unchecked(self.castMut(anyopaque), @ptrCast(key));
        }

        pub fn eraseRawUnchecked(self: *Self, key: *const RawValue) bool {
            return c.cubs_set_erase_raw_unchecked(self.castMut(anyopaque), key);
        }

        pub fn eraseTagged(self: *Self, key: *const TaggedValue) bool {
            const tempC = script_value.zigToCTaggedValueTemp(key.*);
            return c.cubs_set_erase(self.castMut(anyopaque), &tempC);
        }

        // test init {
        //     inline for (@typeInfo(ValueTag).Enum.fields) |keyF| {
        //         const keyEnum: ValueTag = @enumFromInt(keyF.value);
        //         var set = Set.init(keyEnum);
        //         defer set.deinit();

        //         try expect(set.tag() == keyEnum);
        //         try expect(set.count == 0);
        //     }
        // }

        // test insertUnchecked {
        //     {
        //         var set = Set(i64).init();
        //         defer set.deinit();

        //         set.insertUnchecked(RawValue{ .int = 4 });

        //         try expect(set.count == 1);
        //     }
        //     {
        //         var set = Set(String).init();
        //         defer set.deinit();

        //         set.insertUnchecked(RawValue{ .string = String.initUnchecked("erm") });

        //         try expect(set.count == 1);
        //     }
        //     {
        //         var set = Set(i64).init();
        //         defer set.deinit();

        //         for (0..100) |i| {
        //             set.insertUnchecked(RawValue{ .int = @intCast(i) });
        //         }

        //         try expect(set.count == 100);
        //     }
        //     {
        //         var set = Set(String).init();
        //         defer set.deinit();

        //         for (0..100) |i| {
        //             set.insertUnchecked(RawValue{ .string = String.fromInt(@intCast(i)) });
        //         }
        //         try expect(set.count == 100);
        //     }
        // }

        test insertTagged {
            {
                var set = Set(i64).init();
                defer set.deinit();

                set.insertTagged(TaggedValue{ .int = 4 });

                try expect(set.count == 1);
            }
            {
                var set = Set(String).init();
                defer set.deinit();

                set.insertTagged(TaggedValue{ .string = String.initUnchecked("erm") });

                try expect(set.count == 1);
            }
            {
                var set = Set(i64).init();
                defer set.deinit();

                for (0..100) |i| {
                    set.insertTagged(TaggedValue{ .int = @intCast(i) });
                }

                try expect(set.count == 100);
            }
            {
                var set = Set(String).init();
                defer set.deinit();

                for (0..100) |i| {
                    set.insertTagged(TaggedValue{ .string = String.fromInt(@intCast(i)) });
                }
                try expect(set.count == 100);
            }
        }

        // test containsUnchecked {
        //     var set = Set(String).init();
        //     defer set.deinit();

        //     var firstFind = RawValue{ .string = String.initUnchecked("erm") };
        //     defer firstFind.deinit(.string);

        //     try expect(set.containsUnchecked(&firstFind) == false);

        //     set.insert(TaggedValue{ .string = String.initUnchecked("erm") });

        //     try expect(set.containsUnchecked(&firstFind));

        //     for (0..99) |i| {
        //         set.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) });
        //     }

        //     try expect(set.count == 100);

        //     try expect(set.containsUnchecked(&firstFind));

        //     for (0..99) |i| {
        //         var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit(.string);

        //         try expect(set.containsUnchecked(&firstFind));
        //     }

        //     for (100..150) |i| {
        //         var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit(.string);

        //         try expect(set.containsUnchecked(&findVal) == false);
        //     }
        // }

        test containsTagged {
            var set = Set(String).init();
            defer set.deinit();

            var firstFind = TaggedValue{ .string = String.initUnchecked("erm") };
            defer firstFind.deinit();

            try expect(set.containsTagged(&firstFind) == false);

            set.insert(String.initUnchecked("erm"));

            try expect(set.containsTagged(&firstFind));

            for (0..99) |i| {
                set.insert(String.fromInt(@intCast(i)));
            }

            try expect(set.count == 100);

            try expect(set.containsTagged(&firstFind));

            for (0..99) |i| {
                var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit();

                try expect(set.containsTagged(&firstFind));
            }

            for (100..150) |i| {
                var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                defer findVal.deinit();

                try expect(set.containsTagged(&findVal) == false);
            }
        }

        // test eraseUnchecked {
        //     {
        //         var set = Set(String).init();
        //         defer set.deinit();

        //         var eraseVal = RawValue{ .string = String.initUnchecked("erm") };
        //         defer eraseVal.deinit(.string);

        //         try expect(set.eraseUnchecked(&eraseVal) == false);

        //         set.insert(TaggedValue{ .string = String.initUnchecked("erm") });
        //         try expect(set.count == 1);

        //         try expect(set.eraseUnchecked(&eraseVal) == true);
        //         try expect(set.count == 0);
        //     }
        //     {
        //         var set = Set(String).init();
        //         defer set.deinit();

        //         for (0..100) |i| {
        //             set.insert(TaggedValue{ .string = String.fromInt(@intCast(i)) });
        //         }

        //         try expect(set.count == 100);

        //         for (0..50) |i| {
        //             var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit(.string);

        //             try expect(set.eraseUnchecked(&eraseVal) == true);
        //         }

        //         try expect(set.count == 50);

        //         for (0..50) |i| {
        //             var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit(.string);

        //             try expect(set.eraseUnchecked(&eraseVal) == false);
        //         }
        //         try expect(set.count == 50);

        //         for (50..100) |i| {
        //             var eraseVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //             defer eraseVal.deinit(.string);

        //             try expect(set.eraseUnchecked(&eraseVal) == true);
        //         }
        //     }
        // }

        test eraseTagged {
            {
                var set = Set(String).init();
                defer set.deinit();

                var eraseVal = TaggedValue{ .string = String.initUnchecked("erm") };
                defer eraseVal.deinit();

                try expect(set.eraseTagged(&eraseVal) == false);

                set.insert(String.initUnchecked("erm"));
                try expect(set.count == 1);

                try expect(set.eraseTagged(&eraseVal) == true);
                try expect(set.count == 0);
            }
            {
                var set = Set(String).init();
                defer set.deinit();

                for (0..100) |i| {
                    set.insert(String.fromInt(@intCast(i)));
                }

                try expect(set.count == 100);

                for (0..50) |i| {
                    var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                    defer eraseVal.deinit();

                    try expect(set.eraseTagged(&eraseVal) == true);
                }

                try expect(set.count == 50);

                for (0..50) |i| {
                    var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                    defer eraseVal.deinit();

                    try expect(set.eraseTagged(&eraseVal) == false);
                }
                try expect(set.count == 50);

                for (50..100) |i| {
                    var eraseVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
                    defer eraseVal.deinit();

                    try expect(set.eraseTagged(&eraseVal) == true);
                }
            }
        }
    };
}
