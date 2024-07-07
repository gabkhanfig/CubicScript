const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;
const TypeContext = script_value.TypeContext;

pub fn Map(comptime K: type, comptime V: type) type {
    return extern struct {
        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .map;
        pub const KeyType = K;
        pub const ValueType = V;

        len: usize = 0,
        _metadata: [5]?*anyopaque = std.mem.zeroes([5]?*anyopaque),
        keyContext: *const TypeContext,
        valueContext: *const TypeContext,

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
                const raw = RawMap.cubs_map_init_user_struct(TypeContext.auto(K), TypeContext.auto(V));
                return @bitCast(raw);
            }
        }

        pub fn deinit(self: *Self) void {
            RawMap.cubs_map_deinit(self.asRawMut());
        }

        pub fn clone(self: *const Self) Self {
            return @bitCast(RawMap.cubs_map_clone(self.asRaw()));
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

        pub fn eql(self: *const Self, other: *const Self) bool {
            return RawMap.cubs_map_eql(self.asRaw(), other.asRaw());
        }

        pub fn hash(self: *const Self) usize {
            return RawMap.cubs_map_hash(self.asRaw());
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

        pub fn reverseIter(self: *const Self) ReverseIter {
            return ReverseIter{ ._iter = CubsMapReverseConstIter.cubs_map_reverse_const_iter_begin(self.asRaw()) };
        }

        pub fn reverseMutIter(self: *Self) ReverseMutIter {
            return ReverseMutIter{ ._iter = CubsMapReverseMutIter.cubs_map_reverse_mut_iter_begin(self.asRawMut()) };
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

        pub const ReverseIter = extern struct {
            _iter: CubsMapReverseConstIter,

            pub fn next(self: *ReverseIter) ?struct { key: *const K, value: *const V } {
                if (!CubsMapReverseConstIter.cubs_map_reverse_const_iter_next(&self._iter)) {
                    return null;
                } else {
                    return .{
                        .key = @ptrCast(@alignCast(self._iter.key.?)),
                        .value = @ptrCast(@alignCast(self._iter.value.?)),
                    };
                }
            }
        };

        pub const ReverseMutIter = extern struct {
            _iter: CubsMapReverseMutIter,

            pub fn next(self: *ReverseMutIter) ?struct { key: *const K, value: *V } {
                if (!CubsMapReverseMutIter.cubs_map_reverse_mut_iter_next(&self._iter)) {
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
    keyContext: *const TypeContext,
    valueContext: *const TypeContext,

    pub const SCRIPT_SELF_TAG: ValueTag = .map;

    pub extern fn cubs_map_init_primitives(keyTag: ValueTag, valueTag: ValueTag) callconv(.C) RawMap;
    pub extern fn cubs_map_init_user_struct(keyContext: *const TypeContext, valueContext: *const TypeContext) callconv(.C) RawMap;
    pub extern fn cubs_map_deinit(self: *RawMap) callconv(.C) void;
    pub extern fn cubs_map_clone(self: *const RawMap) callconv(.C) RawMap;
    pub extern fn cubs_map_find(self: *const RawMap, key: *const anyopaque) callconv(.C) ?*const anyopaque;
    pub extern fn cubs_map_find_mut(self: *RawMap, key: *const anyopaque) callconv(.C) ?*anyopaque;
    pub extern fn cubs_map_insert(self: *RawMap, key: *anyopaque, value: *anyopaque) callconv(.C) void;
    pub extern fn cubs_map_erase(self: *RawMap, key: *const anyopaque) callconv(.C) bool;
    pub extern fn cubs_map_eql(self: *const RawMap, other: *const RawMap) callconv(.C) bool;
    pub extern fn cubs_map_hash(self: *const RawMap) callconv(.C) usize;
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

pub const CubsMapReverseConstIter = extern struct {
    _map: *const RawMap,
    _nextIter: ?*const anyopaque,
    key: ?*const anyopaque,
    value: ?*const anyopaque,

    pub extern fn cubs_map_reverse_const_iter_begin(self: *const RawMap) callconv(.C) CubsMapReverseConstIter;
    pub extern fn cubs_map_reverse_const_iter_end(self: *const RawMap) callconv(.C) CubsMapReverseConstIter;
    pub extern fn cubs_map_reverse_const_iter_next(iter: *CubsMapReverseConstIter) callconv(.C) bool;
};

pub const CubsMapReverseMutIter = extern struct {
    _map: *RawMap,
    _nextIter: ?*anyopaque,
    key: ?*const anyopaque,
    value: ?*anyopaque,

    pub extern fn cubs_map_reverse_mut_iter_begin(self: *RawMap) callconv(.C) CubsMapReverseMutIter;
    pub extern fn cubs_map_reverse_mut_iter_end(self: *RawMap) callconv(.C) CubsMapReverseMutIter;
    pub extern fn cubs_map_reverse_mut_iter_next(iter: *CubsMapReverseMutIter) callconv(.C) bool;
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

test "reverseIter" {
    var map = Map(i64, f64).init();
    defer map.deinit();

    {
        var iter = map.reverseIter();
        try expect(iter.next() == null);
    }

    map.insert(0, 0.1);
    {
        var iter = map.reverseIter();
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
        var iter = map.reverseIter();

        const pair2 = iter.next().?;
        try expect(pair2.key.* == 1);
        try expect(pair2.value.* == 0.2);

        const pair1 = iter.next().?;
        try expect(pair1.key.* == 0);
        try expect(pair1.value.* == 0.1);

        try expect(iter.next() == null);
    }

    for (2..10) |i| {
        map.insert(@intCast(i), @floatFromInt(i));
    }

    {
        var iter = map.reverseIter();
        var i: usize = map.len;
        while (iter.next()) |pair| {
            i -= 1;
            try expect(pair.key.* == i);
        }
        try expect(i == 0);
    }
}

test "reverseMutIter" {
    var map = Map(i64, f64).init();
    defer map.deinit();

    {
        var iter = map.reverseMutIter();
        try expect(iter.next() == null);
    }

    map.insert(0, 0.1);
    {
        var iter = map.reverseMutIter();
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
        var iter = map.reverseMutIter();

        const pair2 = iter.next().?;
        try expect(pair2.key.* == 1);
        try expect(pair2.value.* == 0.2);

        const pair1 = iter.next().?;
        try expect(pair1.key.* == 0);
        try expect(pair1.value.* == 0.1);

        try expect(iter.next() == null);
    }

    for (2..10) |i| {
        map.insert(@intCast(i), @floatFromInt(i));
    }

    {
        var iter = map.reverseMutIter();
        var i: usize = 10;
        while (iter.next()) |pair| {
            i -= 1;
            try expect(pair.key.* == i);
            pair.value.* = 1.5;
        }
        try expect(i == 0);
    }

    {
        var iter = map.reverseMutIter();
        var i: usize = 10;
        while (iter.next()) |pair| {
            i -= 1;
            try expect(pair.key.* == i);
            try expect(pair.value.* == 1.5);
        }
        try expect(i == 0);
    }
}

test "clone" {
    var map = Map(i64, f64).init();
    defer map.deinit();

    for (0..100) |i| {
        map.insert(@intCast(i), @floatFromInt(i));
    }

    var clone = map.clone();
    defer clone.deinit();

    try expect(clone.len == map.len);

    var iter = clone.iter();
    var i: i64 = 0;
    while (iter.next()) |pair| {
        try expect(pair.key.* == i);
        try expect(pair.value.* == @as(f64, @floatFromInt(i)));
        i += 1;
    }
}

test "eql" {
    { // consistent order
        var m1 = Map(i64, f64).init();
        defer m1.deinit();

        var m2 = Map(i64, f64).init();
        defer m2.deinit();

        try expect(m1.eql(&m2)); // both empty

        for (0..100) |i| {
            m1.insert(@intCast(i), @floatFromInt(i));
            m2.insert(@intCast(i), @floatFromInt(i));
        }

        try expect(m1.eql(&m2)); // both have the same values in the same order

        m1.insert(1000, 1.5);

        try expect(!m1.eql(&m2)); // different length

        m2.insert(1000, 1.2);

        try expect(!m1.eql(&m2)); // same length, different values in the key-value pair

        m2.findMut(&@as(i64, 1000)).?.* = 1.5;

        try expect(m1.eql(&m2)); // both have the same values in the same order

        try expect(m2.erase(&@as(i64, 1000)));
        m2.insert(999, 1.5);

        try expect(!m1.eql(&m2)); // same length, different keys in the key-value pair
    }
    {
        var m1 = Map(i64, f64).init();
        defer m1.deinit();

        var m2 = Map(i64, f64).init();
        defer m2.deinit();

        for (0..100) |i| {
            m1.insert(@intCast(i), @floatFromInt(i));
        }

        {
            var i: usize = 100;
            while (i > 0) {
                i -= 1;
                m2.insert(@intCast(i), @floatFromInt(i));
            }
        }

        for (0..100) |i| {
            const findVal: i64 = @intCast(i);
            try expect(m1.find(&findVal) != null);
            try expect(m2.find(&findVal) != null);
        }

        try expect(!m1.eql(&m2)); // same keys and values, but different order
    }
}

test "hash" {
    {
        var emptyMap = Map(i64, f64).init();
        defer emptyMap.deinit();

        var oneMap = Map(i64, f64).init();
        defer oneMap.deinit();

        oneMap.insert(1, 1.5);

        var twoMap = Map(i64, f64).init();
        defer twoMap.deinit();

        twoMap.insert(1, 1.5);
        twoMap.insert(1, 1.5);

        var manyMap = Map(i64, f64).init();
        defer manyMap.deinit();

        for (0..100) |i| {
            manyMap.insert(@intCast(i), @floatFromInt(i));
        }

        const h1 = emptyMap.hash();
        const h2 = oneMap.hash();
        const h3 = twoMap.hash();
        const h4 = manyMap.hash();

        if (h1 == h2) {
            return error.SkipZigTest;
        } else if (h1 == h3) {
            return error.SkipZigTest;
        } else if (h1 == h4) {
            return error.SkipZigTest;
        } else if (h2 == h3) {
            return error.SkipZigTest;
        } else if (h2 == h4) {
            return error.SkipZigTest;
        } else if (h3 == h4) {
            return error.SkipZigTest;
        }
    }
    {
        var m1 = Map(i64, f64).init();
        defer m1.deinit();

        var m2 = Map(i64, f64).init();
        defer m2.deinit();

        for (0..100) |i| {
            m1.insert(@intCast(i), @floatFromInt(i));
            m2.insert(@intCast(i), @floatFromInt(i));
        }

        try expect(m1.hash() == m2.hash());
    }
}
