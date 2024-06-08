const std = @import("std");
const expect = std.testing.expect;

pub const Vec2i = extern struct {
    const Self = @This();

    x: i64 = 0,
    y: i64 = 0,

    pub fn add(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec2i_add(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec2i_add(&self, &vec);
    }

    pub fn addScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec2i_add_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec2i_add_scalar(&self, scalar);
    }

    pub fn sub(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec2i_sub(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec2i_sub(&self, &vec);
    }

    pub fn subScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec2i_sub_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec2i_sub_scalar(&self, scalar);
    }

    pub fn mul(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec2i_mul(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec2i_mul(&self, &vec);
    }

    pub fn mulScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec2i_mul_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec2i_mul_scalar(&self, scalar);
    }

    pub fn div(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec2i_div(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec2i_div(&self, &vec);
    }

    pub fn divScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec2i_div_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec2i_div_scalar(&self, scalar);
    }

    test add {
        const v1 = Self{ .x = 10, .y = -10 };
        const v2 = Self{ .x = -10, .y = 10 };
        const v3 = v1.add(v2);
        try expect(v3.x == 0);
        try expect(v3.y == 0);
    }

    test addScalar {
        const v1 = Self{ .x = 15, .y = -7 };
        const v2 = v1.addScalar(4);
        try expect(v2.x == 19);
        try expect(v2.y == -3);
    }

    test sub {
        const v1 = Self{ .x = 10, .y = -10 };
        const v2 = Self{ .x = -10, .y = 10 };
        const v3 = v1.sub(v2);
        try expect(v3.x == 20);
        try expect(v3.y == -20);
    }

    test subScalar {
        const v1 = Self{ .x = 15, .y = -7 };
        const v2 = v1.subScalar(4);
        try expect(v2.x == 11);
        try expect(v2.y == -11);
    }

    test mul {
        const v1 = Self{ .x = 100, .y = -10 };
        const v2 = Self{ .x = -10, .y = 10 };
        const v3 = v1.mul(v2);
        try expect(v3.x == -1000);
        try expect(v3.y == -100);
    }

    test mulScalar {
        const v1 = Self{ .x = 15, .y = -7 };
        const v2 = v1.mulScalar(4);
        try expect(v2.x == 60);
        try expect(v2.y == -28);
    }

    test div {
        const v1 = Self{ .x = 10, .y = -10 };
        const v2 = Self{ .x = -3, .y = 10 };
        const v3 = v1.div(v2);
        try expect(v3.x == -3);
        try expect(v3.y == -1);
    }

    test divScalar {
        const v1 = Self{ .x = 15, .y = -7 };
        const v2 = v1.divScalar(4);
        try expect(v2.x == 3);
        try expect(v2.y == -1);
    }
};
