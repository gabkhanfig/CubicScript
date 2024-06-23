const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;
const StructContext = script_value.StructContext;

pub fn Map(comptime K: type, comptime V: type) type {
    return extern struct {
        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .map;
        pub const KeyType = K;
        pub const ValueType = V;

        len: usize = 0,
        _metadata: [5]?*anyopaque = std.mem.zeroes([5]?*anyopaque),
        keyContext: *const StructContext,
        valueContext: *const StructContext,

        /// For all primitive script types, creates the map.
        /// For user defined types, attemps to generate one.
        /// Alternatively, one can be passed in manually through creating a map instance. For example
        /// ```
        /// const map = Map(UserStructA, UserStructB){.keyContext = ..., .valueContext = ...};
        /// ```
        pub fn init() Self {
            const kTag = comptime script_value.scriptTypeToTag(K);
            const vTag = comptime script_value.scriptTypeToTag(V);
            if (kTag != .userStruct and vTag != .userStruct) {
                const raw = RawMap.cubs_map_init_primitives(kTag, vTag);
                return @bitCast(raw);
            } else {
                const raw = RawMap.cubs_map_init_user_struct(StructContext.auto(K), StructContext.auto(V));
                return @bitCast(raw);
            }
        }

        pub fn deinit(self: *Self) void {
            RawMap.cubs_map_deinit(self.asRawMut());
        }

        pub fn find(self: *const Self, key: *const K) ?*const V {
            return @ptrCast(RawMap.cubs_map_find(self.asRaw(), @ptrCast(key)));
        }

        pub fn find_mut(self: *Self, key: *const K) ?*V {
            return @ptrCast(RawMap.cubs_map_find_mut(self.asRawMut(), @ptrCast(key)));
        }

        pub fn insert(self: *Self, key: K, value: V) void {
            var mutKey = key;
            var mutValue = value;
            RawMap.cubs_map_insert(self.asRawMut(), @ptrCast(&mutKey), @ptrCast(&mutValue));
        }

        pub fn erase(self: *Self, key: *const K) bool {
            return RawMap.cubs_map_erase(self.asRawMut(), @ptrCast(key));
        }

        pub fn asRaw(self: *const Self) *const RawMap {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *RawMap {
            return @ptrCast(self);
        }

        test init {
            {
                var map = Map(i64, f64).init();
                defer map.deinit();
            }
        }

        // test insert {
        //     {
        //         var map = Map(i64, String).init();
        //         defer map.deinit();

        //         map.insert(4, String.initUnchecked("hello world!"));

        //         try expect(map.count == 1);
        //     }
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         map.insert(String.initUnchecked("erm"), String.initUnchecked("hello world!"));

        //         try expect(map.count == 1);
        //     }
        //     {
        //         var map = Map(i64, String).init();
        //         defer map.deinit();

        //         for (0..100) |i| {
        //             map.insert(@intCast(i), String.initUnchecked("hello world!"));
        //         }

        //         try expect(map.count == 100);
        //     }
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         for (0..100) |i| {
        //             map.insert(String.fromInt(@intCast(i)), String.initUnchecked("hello world!"));
        //         }
        //         try expect(map.count == 100);
        //     }
        // }

        // test insertTagged {
        //     {
        //         var map = Map(i64, String).init();
        //         defer map.deinit();

        //         map.insertTagged(TaggedValue{ .int = 4 }, TaggedValue{ .string = String.initUnchecked("hello world!") });

        //         try expect(map.count == 1);
        //     }
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         map.insertTagged(TaggedValue{ .string = String.initUnchecked("erm") }, TaggedValue{ .string = String.initUnchecked("hello world!") });

        //         try expect(map.count == 1);
        //     }
        //     {
        //         var map = Map(i64, String).init();
        //         defer map.deinit();

        //         for (0..100) |i| {
        //             map.insertTagged(TaggedValue{ .int = @intCast(i) }, TaggedValue{ .string = String.initUnchecked("hello world!") });
        //         }

        //         try expect(map.count == 100);
        //     }
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         for (0..100) |i| {
        //             map.insertTagged(TaggedValue{ .string = String.fromInt(@intCast(i)) }, TaggedValue{ .string = String.initUnchecked("hello world!") });
        //         }
        //         try expect(map.count == 100);
        //     }
        // }

        // test insertUnchecked {
        //     {
        //         var map = Map(i64, String).init();
        //         defer map.deinit();

        //         map.insertUnchecked(RawValue{ .int = 4 }, RawValue{ .string = String.initUnchecked("hello world!") });

        //         try expect(map.count == 1);
        //     }
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         map.insertUnchecked(RawValue{ .string = String.initUnchecked("erm") }, RawValue{ .string = String.initUnchecked("hello world!") });

        //         try expect(map.count == 1);
        //     }
        //     {
        //         var map = Map(i64, String).init();
        //         defer map.deinit();

        //         for (0..100) |i| {
        //             map.insertUnchecked(RawValue{ .int = @intCast(i) }, RawValue{ .string = String.initUnchecked("hello world!") });
        //         }

        //         try expect(map.count == 100);
        //     }
        //     {
        //         var map = Map(String, String).init();
        //         defer map.deinit();

        //         for (0..100) |i| {
        //             map.insertUnchecked(RawValue{ .string = String.fromInt(@intCast(i)) }, RawValue{ .string = String.initUnchecked("hello world!") });
        //         }
        //         try expect(map.count == 100);
        //     }
        // }

        // test find {
        //     var map = Map(String, String).init();
        //     defer map.deinit();

        //     var firstFind = String.initUnchecked("erm");
        //     defer firstFind.deinit();

        //     if (map.find(&firstFind)) |_| {
        //         try expect(false);
        //     } else {}

        //     map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

        //     if (map.find(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
        //     }

        //     try expect(map.count == 100);

        //     if (map.find(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         var findVal = String.fromInt(@intCast(i));
        //         defer findVal.deinit();

        //         if (map.find(&findVal)) |found| {
        //             try expect(found.eqlSlice("wuh"));
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (100..150) |i| {
        //         var findVal = String.fromInt(@intCast(i));
        //         defer findVal.deinit();

        //         if (map.find(&findVal)) |_| {
        //             try expect(false);
        //         } else {}
        //     }
        // }

        // test findTagged {
        //     var map = Map(String, String).init();
        //     defer map.deinit();

        //     var firstFind = TaggedValue{ .string = String.initUnchecked("erm") };
        //     defer firstFind.deinit();

        //     if (map.findTagged(&firstFind)) |_| {
        //         try expect(false);
        //     } else {}

        //     map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

        //     if (map.findTagged(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
        //     }

        //     try expect(map.count == 100);

        //     if (map.findTagged(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit();

        //         if (map.findTagged(&findVal)) |found| {
        //             try expect(found.eqlSlice("wuh"));
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (100..150) |i| {
        //         var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit();

        //         if (map.findTagged(&findVal)) |_| {
        //             try expect(false);
        //         } else {}
        //     }
        // }

        // test findRawUnchecked {
        //     var map = Map(String, String).init();
        //     defer map.deinit();

        //     var firstFind = RawValue{ .string = String.initUnchecked("erm") };
        //     defer firstFind.deinit(.string);

        //     if (map.findRawUnchecked(&firstFind)) |_| {
        //         try expect(false);
        //     } else {}

        //     map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

        //     if (map.findRawUnchecked(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
        //     }

        //     try expect(map.count == 100);

        //     if (map.findRawUnchecked(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit(.string);

        //         if (map.findRawUnchecked(&findVal)) |found| {
        //             try expect(found.eqlSlice("wuh"));
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (100..150) |i| {
        //         var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit(.string);

        //         if (map.findRawUnchecked(&findVal)) |_| {
        //             try expect(false);
        //         } else {}
        //     }
        // }

        // test findMut {
        //     var map = Map(String, String).init();
        //     defer map.deinit();

        //     var firstFind = String.initUnchecked("erm");
        //     defer firstFind.deinit();

        //     if (map.findMut(&firstFind)) |_| {
        //         try expect(false);
        //     } else {}

        //     map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

        //     if (map.findMut(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //         found.deinit();
        //         found.* = String.initUnchecked("holy moly");
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
        //     }

        //     try expect(map.count == 100);

        //     if (map.findMut(&firstFind)) |found| {
        //         try expect(found.eqlSlice("holy moly"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         var findVal = String.fromInt(@intCast(i));
        //         defer findVal.deinit();

        //         if (map.findMut(&findVal)) |found| {
        //             try expect(found.eqlSlice("wuh"));
        //             found.deinit();
        //             found.* = String.initUnchecked("holy moly");
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (0..99) |i| {
        //         var findVal = String.fromInt(@intCast(i));
        //         defer findVal.deinit();

        //         if (map.findMut(&findVal)) |found| {
        //             try expect(found.eqlSlice("holy moly"));
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (100..150) |i| {
        //         var findVal = String.fromInt(@intCast(i));
        //         defer findVal.deinit();

        //         if (map.findMut(&findVal)) |_| {
        //             try expect(false);
        //         } else {}
        //     }
        // }

        // test findMutTagged {
        //     var map = Map(String, String).init();
        //     defer map.deinit();

        //     var firstFind = TaggedValue{ .string = String.initUnchecked("erm") };
        //     defer firstFind.deinit();

        //     if (map.findMutTagged(&firstFind)) |_| {
        //         try expect(false);
        //     } else {}

        //     map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

        //     if (map.findMutTagged(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //         found.deinit();
        //         found.* = String.initUnchecked("holy moly");
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
        //     }

        //     try expect(map.count == 100);

        //     if (map.findMutTagged(&firstFind)) |found| {
        //         try expect(found.eqlSlice("holy moly"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit();

        //         if (map.findMutTagged(&findVal)) |found| {
        //             try expect(found.eqlSlice("wuh"));
        //             found.deinit();
        //             found.* = String.initUnchecked("holy moly");
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (0..99) |i| {
        //         var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit();

        //         if (map.findMutTagged(&findVal)) |found| {
        //             try expect(found.eqlSlice("holy moly"));
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (100..150) |i| {
        //         var findVal = TaggedValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit();

        //         if (map.findMutTagged(&findVal)) |_| {
        //             try expect(false);
        //         } else {}
        //     }
        // }

        // test findRawMutUnchecked {
        //     var map = Map(String, String).init();
        //     defer map.deinit();

        //     var firstFind = RawValue{ .string = String.initUnchecked("erm") };
        //     defer firstFind.deinit(.string);

        //     if (map.findRawMutUnchecked(&firstFind)) |_| {
        //         try expect(false);
        //     } else {}

        //     map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));

        //     if (map.findRawMutUnchecked(&firstFind)) |found| {
        //         try expect(found.eqlSlice("wuh"));
        //         found.deinit();
        //         found.* = String.initUnchecked("holy moly");
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
        //     }

        //     try expect(map.count == 100);

        //     if (map.findRawMutUnchecked(&firstFind)) |found| {
        //         try expect(found.eqlSlice("holy moly"));
        //     } else {
        //         try expect(false);
        //     }

        //     for (0..99) |i| {
        //         var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit(.string);

        //         if (map.findRawMutUnchecked(&findVal)) |found| {
        //             try expect(found.eqlSlice("wuh"));
        //             found.deinit();
        //             found.* = String.initUnchecked("holy moly");
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (0..99) |i| {
        //         var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit(.string);

        //         if (map.findRawMutUnchecked(&findVal)) |found| {
        //             try expect(found.eqlSlice("holy moly"));
        //         } else {
        //             try expect(false);
        //         }
        //     }

        //     for (100..150) |i| {
        //         var findVal = RawValue{ .string = String.fromInt(@intCast(i)) };
        //         defer findVal.deinit(.string);

        //         if (map.findRawMutUnchecked(&findVal)) |_| {
        //             try expect(false);
        //         } else {}
        //     }
        // }

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

pub const RawMap = extern struct {
    len: usize,
    _metadata: [5]?*anyopaque,
    keyContext: *const StructContext,
    valueContext: *const StructContext,

    pub const SCRIPT_SELF_TAG: ValueTag = .map;

    pub extern fn cubs_map_init_primitives(keyTag: ValueTag, valueTag: ValueTag) callconv(.C) RawMap;
    pub extern fn cubs_map_init_user_struct(keyContext: *const StructContext, valueContext: *const StructContext) callconv(.C) RawMap;
    pub extern fn cubs_map_deinit(self: *RawMap) callconv(.C) void;
    pub extern fn cubs_map_find(self: *const RawMap, key: *const anyopaque) callconv(.C) ?*const anyopaque;
    pub extern fn cubs_map_find_mut(self: *RawMap, key: *const anyopaque) callconv(.C) ?*anyopaque;
    pub extern fn cubs_map_insert(self: *RawMap, key: *anyopaque, value: *anyopaque) callconv(.C) void;
    pub extern fn cubs_map_erase(self: *RawMap, key: *const anyopaque) callconv(.C) bool;
};
