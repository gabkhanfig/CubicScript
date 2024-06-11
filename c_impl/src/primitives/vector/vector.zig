const std = @import("std");
const expect = std.testing.expect;
const approxEqAbs = std.math.approxEqAbs;
const floatEpsilon = std.math.floatEps(f64);

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

pub const Vec3i = extern struct {
    const Self = @This();

    x: i64 = 0,
    y: i64 = 0,
    z: i64 = 0,

    pub fn add(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec3i_add(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3i_add(&self, &vec);
    }

    pub fn addScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec3i_add_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec3i_add_scalar(&self, scalar);
    }

    pub fn sub(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec3i_sub(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3i_sub(&self, &vec);
    }

    pub fn subScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec3i_sub_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec3i_sub_scalar(&self, scalar);
    }

    pub fn mul(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec3i_mul(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3i_mul(&self, &vec);
    }

    pub fn mulScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec3i_mul_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec3i_mul_scalar(&self, scalar);
    }

    pub fn div(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec3i_div(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3i_div(&self, &vec);
    }

    pub fn divScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec3i_div_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec3i_div_scalar(&self, scalar);
    }

    test add {
        const v1 = Self{ .x = 10, .y = -10, .z = 1 };
        const v2 = Self{ .x = -10, .y = 10, .z = 1 };
        const v3 = v1.add(v2);
        try expect(v3.x == 0);
        try expect(v3.y == 0);
        try expect(v3.z == 2);
    }

    test addScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = 4 };
        const v2 = v1.addScalar(4);
        try expect(v2.x == 19);
        try expect(v2.y == -3);
        try expect(v2.z == 8);
    }

    test sub {
        const v1 = Self{ .x = 10, .y = -10, .z = 1 };
        const v2 = Self{ .x = -10, .y = 10, .z = 1 };
        const v3 = v1.sub(v2);
        try expect(v3.x == 20);
        try expect(v3.y == -20);
        try expect(v3.z == 0);
    }

    test subScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = 4 };
        const v2 = v1.subScalar(4);
        try expect(v2.x == 11);
        try expect(v2.y == -11);
        try expect(v2.z == 0);
    }

    test mul {
        const v1 = Self{ .x = 100, .y = -10, .z = 2 };
        const v2 = Self{ .x = -10, .y = 10, .z = 10 };
        const v3 = v1.mul(v2);
        try expect(v3.x == -1000);
        try expect(v3.y == -100);
        try expect(v3.z == 20);
    }

    test mulScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = -1 };
        const v2 = v1.mulScalar(4);
        try expect(v2.x == 60);
        try expect(v2.y == -28);
        try expect(v2.z == -4);
    }

    test div {
        const v1 = Self{ .x = 10, .y = -10, .z = 10 };
        const v2 = Self{ .x = -3, .y = 10, .z = 4 };
        const v3 = v1.div(v2);
        try expect(v3.x == -3);
        try expect(v3.y == -1);
        try expect(v3.z == 2);
    }

    test divScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = -17 };
        const v2 = v1.divScalar(4);
        try expect(v2.x == 3);
        try expect(v2.y == -1);
        try expect(v2.z == -4);
    }
};

pub const Vec4i = extern struct {
    const Self = @This();

    x: i64 = 0,
    y: i64 = 0,
    z: i64 = 0,
    w: i64 = 0,

    pub fn add(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec4i_add(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec4i_add(&self, &vec);
    }

    pub fn addScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec4i_add_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec4i_add_scalar(&self, scalar);
    }

    pub fn sub(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec4i_sub(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec4i_sub(&self, &vec);
    }

    pub fn subScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec4i_sub_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec4i_sub_scalar(&self, scalar);
    }

    pub fn mul(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec4i_mul(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec4i_mul(&self, &vec);
    }

    pub fn mulScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec4i_mul_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec4i_mul_scalar(&self, scalar);
    }

    pub fn div(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec4i_div(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec4i_div(&self, &vec);
    }

    pub fn divScalar(self: Self, scalar: i64) Self {
        const c = struct {
            extern fn cubs_vec4i_div_scalar(s: *const Self, l: i64) callconv(.C) Self;
        };
        return c.cubs_vec4i_div_scalar(&self, scalar);
    }

    test add {
        const v1 = Self{ .x = 10, .y = -10, .z = 1, .w = 10 };
        const v2 = Self{ .x = -10, .y = 10, .z = 1, .w = 10 };
        const v3 = v1.add(v2);
        try expect(v3.x == 0);
        try expect(v3.y == 0);
        try expect(v3.z == 2);
        try expect(v3.w == 20);
    }

    test addScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = 4, .w = -4 };
        const v2 = v1.addScalar(4);
        try expect(v2.x == 19);
        try expect(v2.y == -3);
        try expect(v2.z == 8);
        try expect(v2.w == 0);
    }

    test sub {
        const v1 = Self{ .x = 10, .y = -10, .z = 1, .w = -5 };
        const v2 = Self{ .x = -10, .y = 10, .z = 1, .w = 5 };
        const v3 = v1.sub(v2);
        try expect(v3.x == 20);
        try expect(v3.y == -20);
        try expect(v3.z == 0);
        try expect(v3.w == -10);
    }

    test subScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = 4, .w = 5 };
        const v2 = v1.subScalar(4);
        try expect(v2.x == 11);
        try expect(v2.y == -11);
        try expect(v2.z == 0);
        try expect(v2.w == 1);
    }

    test mul {
        const v1 = Self{ .x = 100, .y = -10, .z = 2, .w = -5 };
        const v2 = Self{ .x = -10, .y = 10, .z = 10, .w = 5 };
        const v3 = v1.mul(v2);
        try expect(v3.x == -1000);
        try expect(v3.y == -100);
        try expect(v3.z == 20);
        try expect(v3.w == -25);
    }

    test mulScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = -1, .w = -5 };
        const v2 = v1.mulScalar(4);
        try expect(v2.x == 60);
        try expect(v2.y == -28);
        try expect(v2.z == -4);
        try expect(v2.w == -20);
    }

    test div {
        const v1 = Self{ .x = 10, .y = -10, .z = 10, .w = 6 };
        const v2 = Self{ .x = -3, .y = 10, .z = 4, .w = 2 };
        const v3 = v1.div(v2);
        try expect(v3.x == -3);
        try expect(v3.y == -1);
        try expect(v3.z == 2);
        try expect(v3.w == 3);
    }

    test divScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = -17, .w = 17 };
        const v2 = v1.divScalar(4);
        try expect(v2.x == 3);
        try expect(v2.y == -1);
        try expect(v2.z == -4);
        try expect(v2.w == 4);
    }
};

pub const Vec2f = extern struct {
    const Self = @This();

    x: f64 = 0,
    y: f64 = 0,

    pub fn add(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec2f_add(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec2f_add(&self, &vec);
    }

    pub fn addScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec2f_add_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec2f_add_scalar(&self, scalar);
    }

    pub fn sub(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec2f_sub(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec2f_sub(&self, &vec);
    }

    pub fn subScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec2f_sub_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec2f_sub_scalar(&self, scalar);
    }

    pub fn mul(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec2f_mul(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec2f_mul(&self, &vec);
    }

    pub fn mulScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec2f_mul_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec2f_mul_scalar(&self, scalar);
    }

    pub fn div(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec2f_div(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec2f_div(&self, &vec);
    }

    pub fn divScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec2f_div_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec2f_div_scalar(&self, scalar);
    }

    pub fn dot(self: Self, vec: Self) f64 {
        const c = struct {
            extern fn cubs_vec2f_dot(s: *const Self, v: *const Self) callconv(.C) f64;
        };
        return c.cubs_vec2f_dot(&self, &vec);
    }

    test add {
        const v1 = Self{ .x = 10, .y = -10 };
        const v2 = Self{ .x = -10, .y = 10 };
        const v3 = v1.add(v2);
        try expect(approxEqAbs(f64, v3.x, 0, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, 0, floatEpsilon));
    }

    test addScalar {
        const v1 = Self{ .x = 15, .y = -7 };
        const v2 = v1.addScalar(4);
        try expect(approxEqAbs(f64, v2.x, 19, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -3, floatEpsilon));
    }

    test sub {
        const v1 = Self{ .x = 10, .y = -10 };
        const v2 = Self{ .x = -10, .y = 10 };
        const v3 = v1.sub(v2);
        try expect(approxEqAbs(f64, v3.x, 20, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -20, floatEpsilon));
    }

    test subScalar {
        const v1 = Self{ .x = 15, .y = -7 };
        const v2 = v1.subScalar(4);
        try expect(approxEqAbs(f64, v2.x, 11, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -11, floatEpsilon));
    }

    test mul {
        const v1 = Self{ .x = 100, .y = -10 };
        const v2 = Self{ .x = -10, .y = 10 };
        const v3 = v1.mul(v2);
        try expect(approxEqAbs(f64, v3.x, -1000, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -100, floatEpsilon));
    }

    test mulScalar {
        const v1 = Self{ .x = 15, .y = -7 };
        const v2 = v1.mulScalar(4);
        try expect(approxEqAbs(f64, v2.x, 60, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -28, floatEpsilon));
    }

    test div {
        const v1 = Self{ .x = 10, .y = -10 };
        const v2 = Self{ .x = -3, .y = 10 };
        const v3 = v1.div(v2);
        try expect(approxEqAbs(f64, v3.x, -3.3333333333333333333333, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -1, floatEpsilon));
    }

    test divScalar {
        const v1 = Self{ .x = 15, .y = -7 };
        const v2 = v1.divScalar(4);
        try expect(approxEqAbs(f64, v2.x, 3.75, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -1.75, floatEpsilon));
    }
};

pub const Vec3f = extern struct {
    const Self = @This();

    x: f64 = 0,
    y: f64 = 0,
    z: f64 = 0,

    pub fn add(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec3f_add(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3f_add(&self, &vec);
    }

    pub fn addScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec3f_add_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec3f_add_scalar(&self, scalar);
    }

    pub fn sub(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec3f_sub(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3f_sub(&self, &vec);
    }

    pub fn subScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec3f_sub_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec3f_sub_scalar(&self, scalar);
    }

    pub fn mul(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec3f_mul(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3f_mul(&self, &vec);
    }

    pub fn mulScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec3f_mul_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec3f_mul_scalar(&self, scalar);
    }

    pub fn div(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec3f_div(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3f_div(&self, &vec);
    }

    pub fn divScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec3f_div_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec3f_div_scalar(&self, scalar);
    }

    pub fn dot(self: Self, vec: Self) f64 {
        const c = struct {
            extern fn cubs_vec3f_dot(s: *const Self, v: *const Self) callconv(.C) f64;
        };
        return c.cubs_vec3f_dot(&self, &vec);
    }

    pub fn cross(self: Self, vec: Self) f64 {
        const c = struct {
            extern fn cubs_vec3f_cross(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec3f_cross(&self, &vec);
    }

    test add {
        const v1 = Self{ .x = 10, .y = -10, .z = 1.1 };
        const v2 = Self{ .x = -10, .y = 10, .z = -1.1 };
        const v3 = v1.add(v2);
        try expect(approxEqAbs(f64, v3.x, 0, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, 0, floatEpsilon));
        try expect(approxEqAbs(f64, v3.z, 0, floatEpsilon));
    }

    test addScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = 1.5 };
        const v2 = v1.addScalar(4);
        try expect(approxEqAbs(f64, v2.x, 19, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -3, floatEpsilon));
        try expect(approxEqAbs(f64, v2.z, 5.5, floatEpsilon));
    }

    test sub {
        const v1 = Self{ .x = 10, .y = -10, .z = 2.5 };
        const v2 = Self{ .x = -10, .y = 10, .z = 1 };
        const v3 = v1.sub(v2);
        try expect(approxEqAbs(f64, v3.x, 20, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -20, floatEpsilon));
        try expect(approxEqAbs(f64, v3.z, 1.5, floatEpsilon));
    }

    test subScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = 1.5 };
        const v2 = v1.subScalar(4);
        try expect(approxEqAbs(f64, v2.x, 11, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -11, floatEpsilon));
        try expect(approxEqAbs(f64, v2.z, -2.5, floatEpsilon));
    }

    test mul {
        const v1 = Self{ .x = 100, .y = -10, .z = 7.5 };
        const v2 = Self{ .x = -10, .y = 10, .z = 2 };
        const v3 = v1.mul(v2);
        try expect(approxEqAbs(f64, v3.x, -1000, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -100, floatEpsilon));
        try expect(approxEqAbs(f64, v3.z, 15, floatEpsilon));
    }

    test mulScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = -10.1 };
        const v2 = v1.mulScalar(4);
        try expect(approxEqAbs(f64, v2.x, 60, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -28, floatEpsilon));
        try expect(approxEqAbs(f64, v2.z, -40.4, floatEpsilon));
    }

    test div {
        const v1 = Self{ .x = 10, .y = -10, .z = 15 };
        const v2 = Self{ .x = -3, .y = 10, .z = 10 };
        const v3 = v1.div(v2);
        try expect(approxEqAbs(f64, v3.x, -3.3333333333333333333333, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -1, floatEpsilon));
        try expect(approxEqAbs(f64, v3.z, 1.5, floatEpsilon));
    }

    test divScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = -10 };
        const v2 = v1.divScalar(4);
        try expect(approxEqAbs(f64, v2.x, 3.75, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -1.75, floatEpsilon));
        try expect(approxEqAbs(f64, v2.z, -2.5, floatEpsilon));
    }
};

pub const Vec4f = extern struct {
    const Self = @This();

    x: f64 = 0,
    y: f64 = 0,
    z: f64 = 0,
    w: f64 = 0,

    pub fn add(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec4f_add(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec4f_add(&self, &vec);
    }

    pub fn addScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec4f_add_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec4f_add_scalar(&self, scalar);
    }

    pub fn sub(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec4f_sub(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec4f_sub(&self, &vec);
    }

    pub fn subScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec4f_sub_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec4f_sub_scalar(&self, scalar);
    }

    pub fn mul(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec4f_mul(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec4f_mul(&self, &vec);
    }

    pub fn mulScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec4f_mul_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec4f_mul_scalar(&self, scalar);
    }

    pub fn div(self: Self, vec: Self) Self {
        const c = struct {
            extern fn cubs_vec4f_div(s: *const Self, v: *const Self) callconv(.C) Self;
        };
        return c.cubs_vec4f_div(&self, &vec);
    }

    pub fn divScalar(self: Self, scalar: f64) Self {
        const c = struct {
            extern fn cubs_vec4f_div_scalar(s: *const Self, l: f64) callconv(.C) Self;
        };
        return c.cubs_vec4f_div_scalar(&self, scalar);
    }

    pub fn dot(self: Self, vec: Self) f64 {
        const c = struct {
            extern fn cubs_vec4f_dot(s: *const Self, v: *const Self) callconv(.C) f64;
        };
        return c.cubs_vec4f_dot(&self, &vec);
    }

    test add {
        const v1 = Self{ .x = 10, .y = -10, .z = 1.1, .w = -2 };
        const v2 = Self{ .x = -10, .y = 10, .z = -1.1, .w = -2.5 };
        const v3 = v1.add(v2);
        try expect(approxEqAbs(f64, v3.x, 0, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, 0, floatEpsilon));
        try expect(approxEqAbs(f64, v3.z, 0, floatEpsilon));
        try expect(approxEqAbs(f64, v3.w, -4.5, floatEpsilon));
    }

    test addScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = 1.5, .w = -4 };
        const v2 = v1.addScalar(4);
        try expect(approxEqAbs(f64, v2.x, 19, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -3, floatEpsilon));
        try expect(approxEqAbs(f64, v2.z, 5.5, floatEpsilon));
        try expect(approxEqAbs(f64, v2.w, 0, floatEpsilon));
    }

    test sub {
        const v1 = Self{ .x = 10, .y = -10, .z = 2.5, .w = 0 };
        const v2 = Self{ .x = -10, .y = 10, .z = 1, .w = 2 };
        const v3 = v1.sub(v2);
        try expect(approxEqAbs(f64, v3.x, 20, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -20, floatEpsilon));
        try expect(approxEqAbs(f64, v3.z, 1.5, floatEpsilon));
        try expect(approxEqAbs(f64, v3.w, -2, floatEpsilon));
    }

    test subScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = 1.5, .w = 0 };
        const v2 = v1.subScalar(4);
        try expect(approxEqAbs(f64, v2.x, 11, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -11, floatEpsilon));
        try expect(approxEqAbs(f64, v2.z, -2.5, floatEpsilon));
        try expect(approxEqAbs(f64, v2.w, -4, floatEpsilon));
    }

    test mul {
        const v1 = Self{ .x = 100, .y = -10, .z = 7.5, .w = 2.1 };
        const v2 = Self{ .x = -10, .y = 10, .z = 2, .w = 3 };
        const v3 = v1.mul(v2);
        try expect(approxEqAbs(f64, v3.x, -1000, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -100, floatEpsilon));
        try expect(approxEqAbs(f64, v3.z, 15, floatEpsilon));
        try expect(approxEqAbs(f64, v3.w, 6.300000000000001, floatEpsilon)); // even float epsilon doesnt work here???
    }

    test mulScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = -10.1, .w = 2.1 };
        const v2 = v1.mulScalar(4);
        try expect(approxEqAbs(f64, v2.x, 60, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -28, floatEpsilon));
        try expect(approxEqAbs(f64, v2.z, -40.4, floatEpsilon));
        try expect(approxEqAbs(f64, v2.w, 8.4, floatEpsilon));
    }

    test div {
        const v1 = Self{ .x = 10, .y = -10, .z = 15, .w = -15 };
        const v2 = Self{ .x = -3, .y = 10, .z = 10, .w = 6 };
        const v3 = v1.div(v2);
        try expect(approxEqAbs(f64, v3.x, -3.3333333333333333333333, floatEpsilon));
        try expect(approxEqAbs(f64, v3.y, -1, floatEpsilon));
        try expect(approxEqAbs(f64, v3.z, 1.5, floatEpsilon));
        try expect(approxEqAbs(f64, v3.w, -2.5, floatEpsilon));
    }

    test divScalar {
        const v1 = Self{ .x = 15, .y = -7, .z = -10, .w = 10 };
        const v2 = v1.divScalar(4);
        try expect(approxEqAbs(f64, v2.x, 3.75, floatEpsilon));
        try expect(approxEqAbs(f64, v2.y, -1.75, floatEpsilon));
        try expect(approxEqAbs(f64, v2.z, -2.5, floatEpsilon));
        try expect(approxEqAbs(f64, v2.w, 2.5, floatEpsilon));
    }
};
