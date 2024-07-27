const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;
const TypeContext = script_value.TypeContext;

pub fn Array(comptime T: type) type {
    return extern struct {
        const Self = @This();
        /// Helper to generically determine the script value type of `Self`, for example, since this is an `Array`,
        /// it returns `.array`. This is implemented for all script value that are generic.
        pub const SCRIPT_SELF_TAG: ValueTag = .array;
        pub const ValueType = T;

        len: usize = 0,
        buf: ?*T = null,
        capacity: usize = 0,
        context: *const TypeContext = TypeContext.auto(T),

        pub const Error = error{
            OutOfRange,
        };

        // /// For all primitive script types, creates the array.
        // /// For user defined types, attemps to generate one.
        // /// Alternatively, one can be passed in manually through creating a struct instance. For example
        // /// ```
        // /// const arr = Array(UserStruct){.context = ...};
        // /// ```
        // pub fn init() Self {
        //     const valueTag = comptime script_value.scriptTypeToTag(T);
        //     if (valueTag != .userStruct) {
        //         const raw = RawArray.cubs_array_init_primitive(valueTag);
        //         return @bitCast(raw);
        //     } else {
        //         const raw = RawArray.cubs_array_init_user_struct(TypeContext.auto(T));
        //         return raw;
        //     }
        // }

        pub fn deinit(self: *Self) void {
            return CubsArray.cubs_array_deinit(self.asRawMut());
        }

        pub fn clone(self: *const Self) Self {
            return @bitCast(CubsArray.cubs_array_clone(self.asRaw()));
        }

        /// Takes ownership of `value`. Accessing the memory of `value` after this
        /// function is undefined behaviour.
        pub fn push(self: *Self, value: T) void {
            var mutValue = value;
            CubsArray.cubs_array_push_unchecked(self.asRawMut(), @ptrCast(&mutValue));
        }

        pub fn slice(self: *const Self) []const T {
            if (self.buf) |buf| {
                return @as([*]const T, @ptrCast(buf))[0..self.len];
            } else {
                return {};
            }
        }

        pub fn sliceMut(self: *Self) []T {
            if (self.buf) |buf| {
                return @as([*]T, @ptrCast(buf))[0..self.len];
            } else {
                return {};
            }
        }

        pub fn atUnchecked(self: *const Self, index: usize) *const T {
            return @ptrCast(@alignCast(CubsArray.cubs_array_at_unchecked(self.asRaw(), index)));
        }

        pub fn at(self: *const Self, index: usize) Error!*const T {
            var out: *const anyopaque = undefined;
            switch (CubsArray.cubs_array_at(&out, self.asRaw(), index)) {
                .None => {
                    return @ptrCast(@alignCast(out));
                },
                .OutOfRange => {
                    return Error.OutOfRange;
                },
            }
        }

        pub fn atMutUnchecked(self: *Self, index: usize) *T {
            return @ptrCast(@alignCast(CubsArray.cubs_array_at_mut_unchecked(self.asRawMut(), index)));
        }

        pub fn atMut(self: *Self, index: usize) Error!*T {
            var out: *anyopaque = undefined;
            switch (CubsArray.cubs_array_at_mut(&out, self.asRawMut(), index)) {
                .None => {
                    return @ptrCast(@alignCast(out));
                },
                .OutOfRange => {
                    return Error.OutOfRange;
                },
            }
        }

        pub fn eql(self: *const Self, other: *const Self) bool {
            return CubsArray.cubs_array_eql(self.asRaw(), other.asRaw());
        }

        pub fn hash(self: *const Self) usize {
            return CubsArray.cubs_array_hash(self.asRaw());
        }

        pub fn iter(self: *const Self) Iter {
            return Iter{ ._iter = CubsArrayConstIter.cubs_array_const_iter_begin(self.asRaw()) };
        }

        pub fn mutIter(self: *Self) MutIter {
            return MutIter{ ._iter = CubsArrayMutIter.cubs_array_mut_iter_begin(self.asRawMut()) };
        }

        pub fn reverseIter(self: *const Self) ReverseIter {
            return ReverseIter{ ._iter = CubsArrayReverseConstIter.cubs_array_reverse_const_iter_begin(self.asRaw()) };
        }

        pub fn reverseMutIter(self: *Self) ReverseMutIter {
            return ReverseMutIter{ ._iter = CubsArrayReverseMutIter.cubs_array_reverse_mut_iter_begin(self.asRawMut()) };
        }

        pub const Iter = extern struct {
            _iter: CubsArrayConstIter,

            pub fn next(self: *Iter) ?*const T {
                if (!CubsArrayConstIter.cubs_array_const_iter_next(&self._iter)) {
                    return null;
                } else {
                    return @ptrCast(@alignCast(self._iter.value));
                }
            }
        };

        pub const MutIter = extern struct {
            _iter: CubsArrayMutIter,

            pub fn next(self: *MutIter) ?*T {
                if (!CubsArrayMutIter.cubs_array_mut_iter_next(&self._iter)) {
                    return null;
                } else {
                    return @ptrCast(@alignCast(self._iter.value));
                }
            }
        };

        pub const ReverseIter = extern struct {
            _iter: CubsArrayReverseConstIter,

            pub fn next(self: *ReverseIter) ?*const T {
                if (!CubsArrayReverseConstIter.cubs_array_reverse_const_iter_next(&self._iter)) {
                    return null;
                } else {
                    return @ptrCast(@alignCast(self._iter.value));
                }
            }
        };

        pub const ReverseMutIter = extern struct {
            _iter: CubsArrayReverseMutIter,

            pub fn next(self: *ReverseMutIter) ?*T {
                if (!CubsArrayReverseMutIter.cubs_array_reverse_mut_iter_next(&self._iter)) {
                    return null;
                } else {
                    return @ptrCast(@alignCast(self._iter.value));
                }
            }
        };

        pub fn asRaw(self: *const Self) *const CubsArray {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsArray {
            return @ptrCast(self);
        }
    };
}

pub const CubsArray = extern struct {
    len: usize,
    buf: ?*anyopaque,
    capacity: usize,
    context: *const TypeContext,

    pub const Err = enum(c_int) {
        None = 0,
        OutOfRange = 1,
    };

    pub const CUBS_ARRAY_N_POS: usize = @bitCast(@as(i64, -1));
    pub const SCRIPT_SELF_TAG: ValueTag = .array;

    pub extern fn cubs_array_init(rtti: *const TypeContext) callconv(.C) CubsArray;
    pub extern fn cubs_array_deinit(self: *CubsArray) callconv(.C) void;
    pub extern fn cubs_array_clone(self: *const CubsArray) callconv(.C) CubsArray;
    pub extern fn cubs_array_tag(self: *const CubsArray) callconv(.C) ValueTag;
    pub extern fn cubs_array_len(self: *const CubsArray) callconv(.C) usize;
    pub extern fn cubs_array_push_unchecked(self: *CubsArray, value: *anyopaque) callconv(.C) void;
    pub extern fn cubs_array_at_unchecked(self: *const CubsArray, index: usize) callconv(.C) *const anyopaque;
    pub extern fn cubs_array_at(out: **const anyopaque, self: *const CubsArray, index: usize) callconv(.C) Err;
    pub extern fn cubs_array_at_mut_unchecked(self: *CubsArray, index: usize) callconv(.C) *anyopaque;
    pub extern fn cubs_array_at_mut(out: **anyopaque, self: *CubsArray, index: usize) callconv(.C) Err;
    pub extern fn cubs_array_eql(self: *const CubsArray, other: *const CubsArray) callconv(.C) bool;
    pub extern fn cubs_array_hash(self: *const CubsArray) callconv(.C) usize;
};

pub const CubsArrayConstIter = extern struct {
    _arr: *const CubsArray,
    _nextIndex: usize,
    value: *const anyopaque,

    const Self = @This();

    pub extern fn cubs_array_const_iter_begin(self: *const CubsArray) callconv(.C) Self;
    pub extern fn cubs_array_const_iter_end(self: *const CubsArray) callconv(.C) Self;
    pub extern fn cubs_array_const_iter_next(iter: *Self) callconv(.C) bool;
};

pub const CubsArrayMutIter = extern struct {
    _arr: *CubsArray,
    _nextIndex: usize,
    value: *anyopaque,

    const Self = @This();

    pub extern fn cubs_array_mut_iter_begin(self: *CubsArray) callconv(.C) Self;
    pub extern fn cubs_array_mut_iter_end(self: *CubsArray) callconv(.C) Self;
    pub extern fn cubs_array_mut_iter_next(iter: *Self) callconv(.C) bool;
};

pub const CubsArrayReverseConstIter = extern struct {
    _arr: *const CubsArray,
    _priorIndex: usize,
    value: *const anyopaque,

    const Self = @This();

    pub extern fn cubs_array_reverse_const_iter_begin(self: *const CubsArray) callconv(.C) Self;
    pub extern fn cubs_array_reverse_const_iter_end(self: *const CubsArray) callconv(.C) Self;
    pub extern fn cubs_array_reverse_const_iter_next(iter: *Self) callconv(.C) bool;
};

pub const CubsArrayReverseMutIter = extern struct {
    _arr: *CubsArray,
    _priorIndex: usize,
    value: *anyopaque,

    const Self = @This();

    pub extern fn cubs_array_reverse_mut_iter_begin(self: *CubsArray) callconv(.C) Self;
    pub extern fn cubs_array_reverse_mut_iter_end(self: *CubsArray) callconv(.C) Self;
    pub extern fn cubs_array_reverse_mut_iter_next(iter: *Self) callconv(.C) bool;
};

test "nested array" {
    var arr1 = Array(Array(i64)){};
    defer arr1.deinit();

    var arr2 = Array(i64){};
    arr2.push(1);
    arr1.push(arr2);
}

test "push" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        arr.push(6);
        try expect(arr.len == 1);

        arr.push(7);
        try expect(arr.len == 2);
    }
    {
        var arr = Array(String){};
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect(arr.len == 1);

        arr.push(String.initUnchecked("hi"));
        try expect(arr.len == 2);
    }
}

test "atUnchecked" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        arr.push(6);
        try expect(arr.atUnchecked(0).* == 6);

        arr.push(7);
        try expect(arr.atUnchecked(0).* == 6);
        try expect(arr.atUnchecked(1).* == 7);
    }
    {
        var arr = Array(String){};
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect(arr.atUnchecked(0).eqlSlice("hi"));

        arr.push(String.initUnchecked("hi"));
        try expect(arr.atUnchecked(0).eqlSlice("hi"));
        try expect(arr.atUnchecked(1).eqlSlice("hi"));
    }
}

test "at" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        arr.push(6);
        try expect((try arr.at(0)).* == 6);
        try std.testing.expectError(error.OutOfRange, arr.at(1));

        arr.push(7);
        try expect((try arr.at(0)).* == 6);
        try expect((try arr.at(1)).* == 7);
        try std.testing.expectError(error.OutOfRange, arr.at(2));
    }
    {
        var arr = Array(String){};
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect((try arr.at(0)).eqlSlice("hi"));
        try std.testing.expectError(error.OutOfRange, arr.at(1));

        arr.push(String.initUnchecked("hi"));
        try expect((try arr.at(0)).eqlSlice("hi"));
        try expect((try arr.at(1)).eqlSlice("hi"));
        try std.testing.expectError(error.OutOfRange, arr.at(2));
    }
}

test "atMutUnchecked" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        arr.push(6);
        try expect(arr.atMutUnchecked(0).* == 6);

        arr.atMutUnchecked(0).* = 8;

        arr.push(7);
        try expect(arr.atMutUnchecked(0).* == 8);
        try expect(arr.atMutUnchecked(1).* == 7);
    }
    {
        var arr = Array(String){};
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect(arr.atMutUnchecked(0).eqlSlice("hi"));

        arr.atMutUnchecked(0).deinit();
        arr.atMutUnchecked(0).* = String.initUnchecked("erm");

        arr.push(String.initUnchecked("hi"));
        try expect(arr.atMutUnchecked(0).eqlSlice("erm"));
        try expect(arr.atMutUnchecked(1).eqlSlice("hi"));
    }
}

test "atMut" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        arr.push(6);
        try expect((try arr.atMut(0)).* == 6);
        try std.testing.expectError(error.OutOfRange, arr.at(1));

        (try arr.atMut(0)).* = 8;

        arr.push(7);
        try expect((try arr.atMut(0)).* == 8);
        try expect((try arr.atMut(1)).* == 7);
        try std.testing.expectError(error.OutOfRange, arr.at(2));
    }
    {
        var arr = Array(String){};
        defer arr.deinit();

        arr.push(String.initUnchecked("hi"));
        try expect((try arr.atMut(0)).eqlSlice("hi"));
        try std.testing.expectError(error.OutOfRange, arr.at(1));

        (try arr.atMut(0)).deinit();
        (try arr.atMut(0)).* = String.initUnchecked("erm");

        arr.push(String.initUnchecked("hi"));
        try expect((try arr.atMut(0)).eqlSlice("erm"));
        try expect((try arr.atMut(1)).eqlSlice("hi"));
        try std.testing.expectError(error.OutOfRange, arr.at(2));
    }
}

test "clone" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        for (0..6) |i| {
            arr.push(@intCast(i));
        }

        var clone = arr.clone();
        defer clone.deinit();

        try expect(clone.len == 6);
        for (0..6) |i| {
            try expect(clone.atUnchecked(i).* == @as(i64, @intCast(i)));
        }
    }
    {
        var arr = Array(String){};
        defer arr.deinit();

        for (0..6) |i| {
            arr.push(String.fromInt(@intCast(i)));
        }

        var clone = arr.clone();
        defer clone.deinit();

        try expect(clone.len == 6);
        try expect(clone.atUnchecked(0).eqlSlice("0"));
        try expect(clone.atUnchecked(1).eqlSlice("1"));
        try expect(clone.atUnchecked(2).eqlSlice("2"));
        try expect(clone.atUnchecked(3).eqlSlice("3"));
        try expect(clone.atUnchecked(4).eqlSlice("4"));
        try expect(clone.atUnchecked(5).eqlSlice("5"));
    }
}

test "eql" {
    {
        var arr1 = Array(i64){};
        defer arr1.deinit();

        for (0..6) |i| {
            arr1.push(@intCast(i));
        }

        var arr2 = Array(i64){};
        defer arr2.deinit();

        for (0..6) |i| {
            arr2.push(@intCast(i));
        }

        try expect(arr1.eql(&arr2));

        arr2.atMutUnchecked(0).* = 10;
        try expect(!arr1.eql(&arr2));

        arr2.atMutUnchecked(0).* = 0;
        try expect(arr1.eql(&arr2));

        arr2.push(6);
        try expect(!arr1.eql(&arr2));
    }
    {
        var arr1 = Array(String){};
        defer arr1.deinit();

        for (0..6) |i| {
            arr1.push(String.fromInt(@intCast(i)));
        }

        var arr2 = Array(String){};
        defer arr2.deinit();

        for (0..6) |i| {
            arr2.push(String.fromInt(@intCast(i)));
        }

        try expect(arr1.eql(&arr2));

        arr2.atMutUnchecked(0).deinit();
        arr2.atMutUnchecked(0).* = String.initUnchecked("hello world!");
        try expect(!arr1.eql(&arr2));

        arr2.atMutUnchecked(0).deinit();
        arr2.atMutUnchecked(0).* = String.fromInt(0);
        try expect(arr1.eql(&arr2));

        arr2.push(String.fromInt(6));
        try expect(!arr1.eql(&arr2));
    }
}

test "iter" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        {
            var iter = arr.iter();
            try expect(iter.next() == null);
        }

        arr.push(0);

        {
            var iter = arr.iter();
            try expect(iter.next().?.* == 0);
            try expect(iter.next() == null);
        }

        for (1..10) |i| {
            arr.push(@intCast(i));
        }

        {
            var iter = arr.iter();
            var i: usize = 0;
            while (iter.next()) |value| {
                try expect(value.* == @as(i64, @intCast(i)));
                i += 1;
            }
            try expect(i == 10);
        }
    }
}

test "mutIter" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        {
            var iter = arr.mutIter();
            try expect(iter.next() == null);
        }

        arr.push(0);

        {
            var iter = arr.mutIter();
            const firstVal = iter.next().?;
            try expect(firstVal.* == 0);
            firstVal.* = 20;
            try expect(iter.next() == null);
        }

        for (1..10) |i| {
            arr.push(@intCast(i));
        }

        {
            var iter = arr.mutIter();
            var i: usize = 0;
            while (iter.next()) |value| {
                if (i == 0) {
                    try expect(value.* == 20);
                } else {
                    try expect(value.* == @as(i64, @intCast(i)));
                    value.* += 20;
                }

                i += 1;
            }
            try expect(i == 10);
        }

        {
            var iter = arr.mutIter();
            var i: usize = 0;
            while (iter.next()) |value| {
                try expect(value.* == @as(i64, @intCast(i + 20)));
                i += 1;
            }
            try expect(i == 10);
        }
    }
}

test "reverseIter" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        {
            var iter = arr.reverseIter();
            try expect(iter.next() == null);
        }

        arr.push(0);

        {
            var iter = arr.reverseIter();
            try expect(iter.next().?.* == 0);
            try expect(iter.next() == null);
        }

        for (1..10) |i| {
            arr.push(@intCast(i));
        }

        {
            var iter = arr.reverseIter();
            var i: usize = 10;
            while (iter.next()) |value| {
                i -= 1;
                try expect(value.* == @as(i64, @intCast(i)));
            }
            try expect(i == 0);
        }
    }
}

test "reverseMutIter" {
    {
        var arr = Array(i64){};
        defer arr.deinit();

        {
            var iter = arr.reverseMutIter();
            try expect(iter.next() == null);
        }

        arr.push(0);

        {
            var iter = arr.reverseMutIter();
            const firstVal = iter.next().?;
            try expect(firstVal.* == 0);
            firstVal.* = 20;
            try expect(iter.next() == null);
        }

        for (1..10) |i| {
            arr.push(@intCast(i));
        }

        {
            var iter = arr.reverseMutIter();
            var i: usize = 10;
            while (iter.next()) |value| {
                i -= 1;
                if (i == 0) {
                    try expect(value.* == 20);
                } else {
                    try expect(value.* == @as(i64, @intCast(i)));
                    value.* += 20;
                }
            }
            try expect(i == 0);
        }

        {
            var iter = arr.reverseMutIter();
            var i: usize = 10;
            while (iter.next()) |value| {
                i -= 1;
                try expect(value.* == @as(i64, @intCast(i + 20)));
            }
            try expect(i == 0);
        }
    }
}

test "hash" {
    var emptyArr = Array(i64){};
    defer emptyArr.deinit();

    var oneArr = Array(i64){};
    defer oneArr.deinit();

    oneArr.push(5);

    var manyArr = Array(i64){};
    defer manyArr.deinit();

    manyArr.push(5);
    manyArr.push(5);
    manyArr.push(5);

    const h1 = emptyArr.hash();
    const h2 = oneArr.hash();
    const h3 = manyArr.hash();

    if (h1 == h2) {
        return error.SkipZigTest;
    } else if (h1 == h3) {
        return error.SkipZigTest;
    } else if (h2 == h3) {
        return error.SkipZigTest;
    }
}
