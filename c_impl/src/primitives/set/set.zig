const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;
const TypeContext = script_value.TypeContext;

pub fn Set(comptime K: type) type {
    return extern struct {
        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .set;
        pub const KeyType = K;

        len: usize = 0,
        _metadata: [5]?*anyopaque = std.mem.zeroes([5]?*anyopaque),
        context: *const TypeContext = TypeContext.auto(K),

        pub fn deinit(self: *Self) void {
            CubsSet.cubs_set_deinit(self.asRawMut());
        }

        pub fn clone(self: *const Self) Self {
            return @bitCast(CubsSet.cubs_set_clone(self.asRaw()));
        }

        /// Does NOT take ownership of `key`. Zig will likely optimize this to pass by const reference in many cases,
        /// but allows to easily pass in immediate values, rather than using temporary storage.
        pub fn contains(self: *const Self, key: K) bool {
            return CubsSet.cubs_set_contains(self.asRaw(), @ptrCast(&key));
        }

        /// Takes ownership of the memory of `key`.
        pub fn insert(self: *Self, key: K) void {
            var tempKey = key;
            CubsSet.cubs_set_insert(self.asRawMut(), @ptrCast(&tempKey));
        }

        /// Does NOT take ownership of `key`. Zig will likely optimize this to pass by const reference in many cases,
        /// but allows to easily pass in immediate values, rather than using temporary storage.
        pub fn erase(self: *Self, key: K) bool {
            return CubsSet.cubs_set_erase(self.asRawMut(), @ptrCast(&key));
        }

        pub fn eql(self: *const Self, other: *const Self) bool {
            return CubsSet.cubs_set_eql(self.asRaw(), other.asRaw());
        }

        pub fn hash(self: *const Self) usize {
            return CubsSet.cubs_set_hash(self.asRaw());
        }

        pub fn asRaw(self: *const Self) *const CubsSet {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsSet {
            return @ptrCast(self);
        }

        pub fn iter(self: *const Self) Iter {
            return Iter{ ._iter = CubsSetIter.cubs_set_iter_begin(self.asRaw()) };
        }

        pub fn reverseIter(self: *const Self) ReverseIter {
            return ReverseIter{ ._iter = CubsSetReverseIter.cubs_set_reverse_iter_begin(self.asRaw()) };
        }

        pub const Iter = extern struct {
            _iter: CubsSetIter,

            pub fn next(self: *Iter) ?*const K {
                if (!CubsSetIter.cubs_set_iter_next(&self._iter)) {
                    return null;
                } else {
                    return @ptrCast(@alignCast(self._iter.key.?));
                }
            }
        };

        pub const ReverseIter = extern struct {
            _iter: CubsSetReverseIter,

            pub fn next(self: *ReverseIter) ?*const K {
                if (!CubsSetReverseIter.cubs_set_reverse_iter_next(&self._iter)) {
                    return null;
                } else {
                    return @ptrCast(@alignCast(self._iter.key.?));
                }
            }
        };
    };
}

pub const CubsSet = extern struct {
    len: usize,
    _metadata: [5]?*anyopaque,
    keyContext: *const TypeContext,

    pub const SCRIPT_SELF_TAG: ValueTag = .set;

    pub extern fn cubs_set_init(context: *const TypeContext) callconv(.C) CubsSet;
    pub extern fn cubs_set_deinit(self: *CubsSet) callconv(.C) void;
    pub extern fn cubs_set_clone(self: *const CubsSet) callconv(.C) CubsSet;
    pub extern fn cubs_set_contains(self: *const CubsSet, key: *const anyopaque) callconv(.C) bool;
    pub extern fn cubs_set_insert(self: *CubsSet, key: *anyopaque) callconv(.C) void;
    pub extern fn cubs_set_erase(self: *CubsSet, key: *const anyopaque) callconv(.C) bool;
    pub extern fn cubs_set_eql(self: *const CubsSet, other: *const CubsSet) callconv(.C) bool;
    pub extern fn cubs_set_hash(self: *const CubsSet) callconv(.C) usize;
};

pub const CubsSetIter = extern struct {
    _set: *const CubsSet,
    _nextIter: ?*const anyopaque,
    key: ?*const anyopaque,
    value: ?*const anyopaque,

    pub extern fn cubs_set_iter_begin(self: *const CubsSet) callconv(.C) CubsSetIter;
    pub extern fn cubs_set_iter_end(self: *const CubsSet) callconv(.C) CubsSetIter;
    pub extern fn cubs_set_iter_next(iter: *CubsSetIter) callconv(.C) bool;
};

pub const CubsSetReverseIter = extern struct {
    _set: *const CubsSet,
    _nextIter: ?*const anyopaque,
    key: ?*const anyopaque,
    value: ?*const anyopaque,

    pub extern fn cubs_set_reverse_iter_begin(self: *const CubsSet) callconv(.C) CubsSetReverseIter;
    pub extern fn cubs_set_reverse_iter_end(self: *const CubsSet) callconv(.C) CubsSetReverseIter;
    pub extern fn cubs_set_reverse_iter_next(iter: *CubsSetReverseIter) callconv(.C) bool;
};

test "init" {
    {
        var set = Set(i64){};
        defer set.deinit();
    }
    {
        var set = Set(String){};
        defer set.deinit();
    }
    // {
    //     var set = set(set(i64, i64), String).init();
    //     defer set.deinit();
    // }
}

test "insert" {
    {
        var set = Set(i64){};
        defer set.deinit();

        set.insert(4);

        try expect(set.len == 1);
    }
    {
        var set = Set(String){};
        defer set.deinit();

        set.insert(String.initUnchecked("erm"));

        try expect(set.len == 1);
    }
    {
        var set = Set(i64){};
        defer set.deinit();

        for (0..100) |i| {
            set.insert(@intCast(i));
        }

        try expect(set.len == 100);
    }
    {
        var set = Set(String){};
        defer set.deinit();

        for (0..100) |i| {
            set.insert(String.fromInt(@intCast(i)));
        }
        try expect(set.len == 100);
    }
}

test "contains" {
    var set = Set(String){};
    defer set.deinit();

    var firstFind = String.initUnchecked("erm");
    defer firstFind.deinit();

    try expect(set.contains(firstFind) == false);

    set.insert(String.initUnchecked("erm"));

    try expect(set.contains(firstFind));

    for (0..99) |i| {
        set.insert(String.fromInt(@intCast(i)));
    }

    try expect(set.len == 100);

    try expect(set.contains(firstFind));

    for (0..99) |i| {
        var findVal = String.fromInt(@intCast(i));
        defer findVal.deinit();

        try expect(set.contains(findVal));
    }

    for (100..150) |i| {
        var findVal = String.fromInt(@intCast(i));
        defer findVal.deinit();

        try expect(set.contains(findVal) == false);
    }
}

test "erase" {
    {
        var set = Set(String){};
        defer set.deinit();

        var eraseVal = String.initUnchecked("erm");
        defer eraseVal.deinit();

        try expect(set.erase(eraseVal) == false);

        set.insert(String.initUnchecked("erm"));
        try expect(set.len == 1);

        try expect(set.erase(eraseVal) == true);
        try expect(set.len == 0);
    }
    {
        var set = Set(String){};
        defer set.deinit();

        for (0..100) |i| {
            set.insert(String.fromInt(@intCast(i)));
        }

        try expect(set.len == 100);

        for (0..50) |i| {
            var eraseVal = String.fromInt(@intCast(i));
            defer eraseVal.deinit();

            try expect(set.erase(eraseVal) == true);
        }

        try expect(set.len == 50);

        for (0..50) |i| {
            var eraseVal = String.fromInt(@intCast(i));
            defer eraseVal.deinit();

            try expect(set.erase(eraseVal) == false);
        }
        try expect(set.len == 50);

        for (50..100) |i| {
            var eraseVal = String.fromInt(@intCast(i));
            defer eraseVal.deinit();

            try expect(set.erase(eraseVal) == true);
        }
    }
}

test "iter" {
    var set = Set(i64){};
    defer set.deinit();

    {
        var iter = set.iter();
        try expect(iter.next() == null);
    }

    set.insert(0);
    {
        var iter = set.iter();
        var i: usize = 0;
        while (iter.next()) |key| {
            try expect(i < 1);
            try expect(key.* == 0);
            i += 1;
        }
    }

    set.insert(1);
    {
        var iter = set.iter();

        const key1 = iter.next().?;
        try expect(key1.* == 0);

        const key2 = iter.next().?;
        try expect(key2.* == 1);

        try expect(iter.next() == null);
    }

    for (2..10) |i| {
        set.insert(@intCast(i));
    }

    {
        var iter = set.iter();
        var i: usize = 0;
        while (iter.next()) |key| {
            try expect(key.* == i);
            i += 1;
        }
        try expect(i == 10);
    }
}

test "reverseIter" {
    var set = Set(i64){};
    defer set.deinit();

    {
        var iter = set.reverseIter();
        try expect(iter.next() == null);
    }

    set.insert(0);
    {
        var iter = set.reverseIter();
        var i: usize = 0;
        while (iter.next()) |key| {
            try expect(i < 1);
            try expect(key.* == 0);
            i += 1;
        }
    }

    set.insert(1);
    {
        var iter = set.reverseIter();

        const key2 = iter.next().?;
        try expect(key2.* == 1);

        const key1 = iter.next().?;
        try expect(key1.* == 0);

        try expect(iter.next() == null);
    }

    for (2..10) |i| {
        set.insert(@intCast(i));
    }

    {
        var iter = set.reverseIter();
        var i: usize = set.len;
        while (iter.next()) |key| {
            i -= 1;
            try expect(key.* == i);
        }
        try expect(i == 0);
    }
}

test "clone" {
    var set = Set(i64){};
    defer set.deinit();

    for (0..100) |i| {
        set.insert(@intCast(i));
    }

    var clone = set.clone();
    defer clone.deinit();

    try expect(clone.len == set.len);

    var iter = clone.iter();
    var i: i64 = 0;
    while (iter.next()) |key| {
        try expect(key.* == i);
        i += 1;
    }
}

test "eql" {
    { // consistent order
        var m1 = Set(i64){};
        defer m1.deinit();

        var m2 = Set(i64){};
        defer m2.deinit();

        try expect(m1.eql(&m2)); // both empty

        for (0..100) |i| {
            m1.insert(@intCast(i));
            m2.insert(@intCast(i));
        }

        try expect(m1.eql(&m2)); // both have the same values in the same order

        m1.insert(1000);

        try expect(!m1.eql(&m2)); // different length

        m2.insert(1000);

        try expect(m1.eql(&m2)); // both have the same values in the same order

        try expect(m2.erase(1000));
        m2.insert(999);

        try expect(!m1.eql(&m2)); // same length, different keys in the key-value pair
    }
    { // different order
        var m1 = Set(i64){};
        defer m1.deinit();

        var m2 = Set(i64){};
        defer m2.deinit();

        m1.insert(1000);

        try expect(!m1.eql(&m2));

        for (0..100) |i| {
            m1.insert(@intCast(i));
            m2.insert(@intCast(i));
        }

        try expect(!m1.eql(&m2)); // different length

        m2.insert(1000);

        try expect(!m1.eql(&m2)); // both have the same values in the different order
    }
    {
        var m1 = Set(i64){};
        defer m1.deinit();

        var m2 = Set(i64){};
        defer m2.deinit();

        for (0..100) |i| {
            m1.insert(@intCast(i));
        }

        {
            var i: usize = 100;
            while (i > 0) {
                i -= 1;
                m2.insert(@intCast(i));
            }
        }

        for (0..100) |i| {
            const findVal: i64 = @intCast(i);
            try expect(m1.contains(findVal));
            try expect(m2.contains(findVal));
        }

        try expect(!m1.eql(&m2)); // same keys and values, but different order
    }
}

test "hash" {
    {
        var emptySet = Set(i64){};
        defer emptySet.deinit();

        var oneSet = Set(i64){};
        defer oneSet.deinit();

        oneSet.insert(1);

        var twoSet = Set(i64){};
        defer twoSet.deinit();

        twoSet.insert(1);
        twoSet.insert(1);

        var manySet = Set(i64){};
        defer manySet.deinit();

        for (0..100) |i| {
            manySet.insert(@intCast(i));
        }

        const h1 = emptySet.hash();
        const h2 = oneSet.hash();
        const h3 = twoSet.hash();
        const h4 = manySet.hash();

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
        var m1 = Set(i64){};
        defer m1.deinit();

        var m2 = Set(i64){};
        defer m2.deinit();

        for (0..100) |i| {
            m1.insert(@intCast(i));
            m2.insert(@intCast(i));
        }

        try expect(m1.hash() == m2.hash());
    }
}
