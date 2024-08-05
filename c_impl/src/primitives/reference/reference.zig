const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const TypeContext = script_value.TypeContext;

/// Can be freely cloned, as references do not use any form of GC.
pub fn ConstRef(comptime T: type) type {
    return extern struct {
        const Self = @This();
        pub const ValueType = T;

        ref: *const T,
        context: *const TypeContext = TypeContext.auto(T),

        pub fn eql(self: *const Self, other: Self) bool {
            return CubsConstRef.cubs_const_ref_eql(self.asRaw(), other.asRaw());
        }

        pub fn eqlValue(self: *const Self, other: T) bool {
            return CubsConstRef.cubs_const_ref_eql_value(self.asRaw(), @ptrCast(&other));
        }

        pub fn hash(self: *const Self) usize {
            return CubsConstRef.cubs_const_ref_hash(self.asRaw());
        }

        pub fn asRaw(self: *const Self) *const CubsConstRef {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsConstRef {
            return @ptrCast(self);
        }
    };
}

pub const CubsConstRef = extern struct {
    ref: *const anyopaque,
    context: *const TypeContext,

    const Self = @This();

    pub extern fn cubs_const_ref_eql(self: *const Self, other: *const Self) callconv(.C) bool;
    pub extern fn cubs_const_ref_eql_value(self: *const Self, other: *const anyopaque) callconv(.C) bool;
    pub extern fn cubs_const_ref_hash(self: *const Self) callconv(.C) usize;
};

test "const ref eql" {
    { // same ref
        const a: i64 = 11;
        const r1 = ConstRef(i64){ .ref = &a };
        const r2 = ConstRef(i64){ .ref = &a };
        try expect(r1.eql(r2));
    }
    { // different ref, same value
        const a: i64 = 11;
        const r1 = ConstRef(i64){ .ref = &a };
        const b: i64 = 11;
        const r2 = ConstRef(i64){ .ref = &b };
        try expect(r1.eql(r2));
    }
    { // different ref, different value
        const a: i64 = 11;
        const r1 = ConstRef(i64){ .ref = &a };
        const b: i64 = 12;
        const r2 = ConstRef(i64){ .ref = &b };
        try expect(!r1.eql(r2));
    }
}

test "const ref eqlValue" {
    { // same value
        const a: i64 = 11;
        const r = ConstRef(i64){ .ref = &a };
        try expect(r.eqlValue(a));
    }
    { // same value
        const a: i64 = 11;
        const r = ConstRef(i64){ .ref = &a };
        const b: i64 = 11;
        try expect(r.eqlValue(b));
    }
    { // different value
        const a: i64 = 11;
        const r = ConstRef(i64){ .ref = &a };
        const b: i64 = 12;
        try expect(!r.eqlValue(b));
    }
}

test "const ref hash" {
    const String = script_value.String;

    const s = String.initUnchecked("hello world!");
    const r = ConstRef(String){ .ref = &s };
    try expect(s.hash() == r.hash());
}
