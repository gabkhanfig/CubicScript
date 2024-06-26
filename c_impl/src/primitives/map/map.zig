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
            return @ptrCast(@alignCast(RawMap.cubs_map_find(self.asRaw(), @ptrCast(key))));
        }

        pub fn findMut(self: *Self, key: *const K) ?*V {
            return @ptrCast(@alignCast(RawMap.cubs_map_find_mut(self.asRawMut(), @ptrCast(key))));
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

        pub fn iter(self: *const Self) Iter {
            return Iter{ ._iter = CubsMapConstIter.cubs_map_const_iter_begin(self.asRaw()) };
        }

        pub fn mutIter(self: *Self) MutIter {
            return MutIter{ ._iter = CubsMapMutIter.cubs_map_mut_iter_begin(self.asRawMut()) };
        }

        pub const Iter = extern struct {
            _iter: CubsMapConstIter,

            pub fn next(self: *Iter) ?struct { key: *const K, value: *const V } {
                if (!CubsMapConstIter.cubs_map_const_iter_next(&self._iter)) {
                    return null;
                } else {
                    return .{
                        .key = @ptrCast(@alignCast(self._iter.key.?)),
                        .value = @ptrCast(@alignCast(self._iter.value.?)),
                    };
                }
            }
        };

        pub const MutIter = extern struct {
            _iter: CubsMapMutIter,

            pub fn next(self: *MutIter) ?struct { key: *const K, value: *V } {
                if (!CubsMapMutIter.cubs_map_mut_iter_next(&self._iter)) {
                    return null;
                } else {
                    return .{
                        .key = @ptrCast(@alignCast(self._iter.key.?)),
                        .value = @ptrCast(@alignCast(self._iter.value.?)),
                    };
                }
            }
        };
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

pub const CubsMapConstIter = extern struct {
    _map: *const RawMap,
    _nextIter: ?*const anyopaque,
    key: ?*const anyopaque,
    value: ?*const anyopaque,

    pub extern fn cubs_map_const_iter_begin(self: *const RawMap) callconv(.C) CubsMapConstIter;
    pub extern fn cubs_map_const_iter_end(self: *const RawMap) callconv(.C) CubsMapConstIter;
    pub extern fn cubs_map_const_iter_next(iter: *CubsMapConstIter) callconv(.C) bool;
};

pub const CubsMapMutIter = extern struct {
    _map: *RawMap,
    _nextIter: ?*anyopaque,
    key: ?*const anyopaque,
    value: ?*anyopaque,

    pub extern fn cubs_map_mut_iter_begin(self: *RawMap) callconv(.C) CubsMapMutIter;
    pub extern fn cubs_map_mut_iter_end(self: *RawMap) callconv(.C) CubsMapMutIter;
    pub extern fn cubs_map_mut_iter_next(iter: *CubsMapMutIter) callconv(.C) bool;
};

test "init" {
    {
        var map = Map(i64, f64).init();
        defer map.deinit();
    }
    {
        var map = Map(String, bool).init();
        defer map.deinit();
    }
    // {
    //     var map = Map(Map(i64, i64), String).init();
    //     defer map.deinit();
    // }
}

test "insert" {
    {
        var map = Map(i64, String).init();
        defer map.deinit();

        map.insert(4, String.initUnchecked("hello world!"));

        try expect(map.len == 1);
    }
    {
        var map = Map(String, String).init();
        defer map.deinit();

        map.insert(String.initUnchecked("erm"), String.initUnchecked("hello world!"));

        try expect(map.len == 1);
    }
    {
        var map = Map(i64, String).init();
        defer map.deinit();

        for (0..100) |i| {
            map.insert(@intCast(i), String.initUnchecked("hello world!"));
        }

        try expect(map.len == 100);
    }
    {
        var map = Map(String, String).init();
        defer map.deinit();

        for (0..100) |i| {
            map.insert(String.fromInt(@intCast(i)), String.initUnchecked("hello world!"));
        }
        try expect(map.len == 100);
    }
}

test "find" {
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

    try expect(map.len == 100);

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

test "findMut" {
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

    try expect(map.len == 100);

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

test "erase" {
    {
        var map = Map(String, String).init();
        defer map.deinit();

        var eraseVal = String.initUnchecked("erm");
        defer eraseVal.deinit();

        try expect(map.erase(&eraseVal) == false);

        map.insert(String.initUnchecked("erm"), String.initUnchecked("wuh"));
        try expect(map.len == 1);

        try expect(map.erase(&eraseVal) == true);
        try expect(map.len == 0);
    }
    {
        var map = Map(String, String).init();
        defer map.deinit();

        for (0..100) |i| {
            map.insert(String.fromInt(@intCast(i)), String.initUnchecked("wuh"));
        }

        try expect(map.len == 100);

        for (0..50) |i| {
            var eraseVal = String.fromInt(@intCast(i));
            defer eraseVal.deinit();

            try expect(map.erase(&eraseVal) == true);
        }

        try expect(map.len == 50);

        for (0..50) |i| {
            var eraseVal = String.fromInt(@intCast(i));
            defer eraseVal.deinit();

            try expect(map.erase(&eraseVal) == false);
        }
        try expect(map.len == 50);

        for (50..100) |i| {
            var eraseVal = String.fromInt(@intCast(i));
            defer eraseVal.deinit();

            try expect(map.erase(&eraseVal) == true);
        }
    }
}

test "iter" {
    var map = Map(i64, f64).init();
    defer map.deinit();

    {
        var iter = map.iter();
        try expect(iter.next() == null);
    }

    map.insert(0, 0.1);
    {
        var iter = map.iter();
        var i: usize = 0;
        while (iter.next()) |pair| {
            try expect(i < 1);
            try expect(pair.key.* == 0);
            try expect(pair.value.* == 0.1);
            i += 1;
        }
    }

    map.insert(1, 0.2);
    {
        var iter = map.iter();

        const pair1 = iter.next().?;
        try expect(pair1.key.* == 0);
        try expect(pair1.value.* == 0.1);

        const pair2 = iter.next().?;
        try expect(pair2.key.* == 1);
        try expect(pair2.value.* == 0.2);

        try expect(iter.next() == null);
    }

    for (2..10) |i| {
        map.insert(@intCast(i), @floatFromInt(i));
    }

    {
        var iter = map.iter();
        var i: usize = 0;
        while (iter.next()) |pair| {
            try expect(pair.key.* == i);
            i += 1;
        }
        try expect(i == 10);
    }
}

test "mutIter" {
    var map = Map(i64, f64).init();
    defer map.deinit();

    {
        var iter = map.mutIter();
        try expect(iter.next() == null);
    }

    map.insert(0, 0.1);
    {
        var iter = map.mutIter();
        var i: usize = 0;
        while (iter.next()) |pair| {
            try expect(i < 1);
            try expect(pair.key.* == 0);
            try expect(pair.value.* == 0.1);
            i += 1;
        }
    }

    map.insert(1, 0.2);
    {
        var iter = map.mutIter();

        const pair1 = iter.next().?;
        try expect(pair1.key.* == 0);
        try expect(pair1.value.* == 0.1);

        const pair2 = iter.next().?;
        try expect(pair2.key.* == 1);
        try expect(pair2.value.* == 0.2);

        try expect(iter.next() == null);
    }

    for (2..10) |i| {
        map.insert(@intCast(i), @floatFromInt(i));
    }

    {
        var iter = map.mutIter();
        var i: usize = 0;
        while (iter.next()) |pair| {
            try expect(pair.key.* == i);
            pair.value.* = 1.5;
            i += 1;
        }
        try expect(i == 10);
    }

    {
        var iter = map.mutIter();
        var i: usize = 0;
        while (iter.next()) |pair| {
            try expect(pair.key.* == i);
            try expect(pair.value.* == 1.5);
            i += 1;
        }
        try expect(i == 10);
    }
}
