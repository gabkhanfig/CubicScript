const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const Int = root.Int;
const Float = root.Float;
const math = @import("math.zig");
//const ValueTag = root.ValueTag;
const CubicScriptState = @import("../state/CubicScriptState.zig");
const MAX_INT = math.MAX_INT;
const MIN_INT = math.MIN_INT;

/// 2 component 64 bit int vector. By default, initializes to { 0, 0 }.
/// The math operations return the implementation structure, rather than a `Vec2i`,
/// sacrificing convenience in exchange for not allocating more memory than necessary.
/// The resulting value however has an function to turn into a `Vec2i`.
pub const Vec2i = extern struct {
    const Self = @This();

    inner: ?*anyopaque = null,

    pub fn init(inX: Int, inY: Int, state: *const CubicScriptState) Allocator.Error!Self {
        if (inX == 0 and inY == 0) {
            return Self{};
        }

        const impl = try state.allocator.create(Vector2IntImpl());
        impl.* = Vector2IntImpl(){ .x = inX, .y = inY };
        return Self{ .inner = @ptrCast(impl) };
    }

    pub fn deinit(self: *Self, state: *const CubicScriptState) void {
        if (self.asImplMut()) |impl| {
            state.allocator.destroy(impl);
            self.inner = null;
        }
    }

    pub fn clone(self: *const Self, state: *const CubicScriptState) Allocator.Error!Self {
        if (self.asImpl()) |impl| {
            return impl.toVec2i(state);
        } else {
            return Self{};
        }
    }

    pub fn x(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.x;
        } else {
            return 0;
        }
    }

    pub fn y(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.y;
        } else {
            return 0;
        }
    }

    pub fn setX(self: *Self, inX: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.x = inX;
        } else {
            const impl = try state.allocator.create(Vector2IntImpl());
            impl.* = Vector2IntImpl(){ .x = inX, .y = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setY(self: *Self, inY: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.y = inY;
        } else {
            const impl = try state.allocator.create(Vector2IntImpl());
            impl.* = Vector2IntImpl(){ .x = 0, .y = inY };
            self.inner = @ptrCast(impl);
        }
    }

    /// Returns a tuple of the resulting addition, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn add(self: *const Self, other: Vector2IntImpl()) struct { Vector2IntImpl(), bool } {
        return self.getAsImplVec().add(other);
    }

    /// Returns a tuple of the resulting subtraction, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn sub(self: *const Self, other: Vector2IntImpl()) struct { Vector2IntImpl(), bool } {
        return self.getAsImplVec().sub(other);
    }

    /// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn mul(self: *const Self, other: Vector2IntImpl()) struct { Vector2IntImpl(), bool } {
        return self.getAsImplVec().mul(other);
    }

    /// If the return value is null, that means a divide by 0 would have occurred.
    /// Otherwise, the divison result is returned.
    pub fn div(self: *const Self, other: Vector2IntImpl()) ?Vector2IntImpl() {
        return self.getAsImplVec().div(other);
    }

    pub fn dot(self: *const Self, other: Vector2IntImpl()) struct { Int, bool } {
        return self.getAsImplVec().dot(other);
    }

    pub fn getAsImplVec(self: *const Self) Vector2IntImpl() {
        if (self.asImpl()) |impl| {
            return impl.*;
        } else {
            return .{ .x = 0, .y = 0 };
        }
    }

    fn asImpl(self: *const Self) ?*const Vector2IntImpl() {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asImplMut(self: *Self) ?*Vector2IntImpl() {
        return @ptrCast(@alignCast(self.inner));
    }
};

/// 3 component 64 bit int vector. By default, initializes to { 0, 0, 0 }.
/// The math operations return the implementation structure, rather than a `Vec3i`,
/// sacrificing convenience in exchange for not allocating more memory than necessary.
/// The resulting value however has an function to turn into a `Vec3i`.
pub const Vec3i = extern struct {
    const Self = @This();

    inner: ?*anyopaque = null,

    pub fn init(inX: Int, inY: Int, inZ: Int, state: *const CubicScriptState) Allocator.Error!Self {
        if (inX == 0 and inY == 0 and inZ == 0) {
            return Self{};
        }

        const impl = try state.allocator.create(Vector3IntImpl());
        impl.* = Vector3IntImpl(){ .x = inX, .y = inY, .z = inZ };
        return Self{ .inner = @ptrCast(impl) };
    }

    pub fn deinit(self: *Self, state: *const CubicScriptState) void {
        if (self.asImplMut()) |impl| {
            state.allocator.destroy(impl);
            self.inner = null;
        }
    }

    pub fn clone(self: *const Self, state: *const CubicScriptState) Allocator.Error!Self {
        if (self.asImpl()) |impl| {
            return impl.toVec2i(state);
        } else {
            return Self{};
        }
    }

    pub fn x(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.x;
        } else {
            return 0;
        }
    }

    pub fn y(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.y;
        } else {
            return 0;
        }
    }

    pub fn z(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.z;
        } else {
            return 0;
        }
    }

    pub fn setX(self: *Self, inX: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.x = inX;
        } else {
            const impl = try state.allocator.create(Vector3IntImpl());
            impl.* = Vector2IntImpl(){ .x = inX, .y = 0, .z = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setY(self: *Self, inY: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.y = inY;
        } else {
            const impl = try state.allocator.create(Vector3IntImpl());
            impl.* = Vector3IntImpl(){ .x = 0, .y = inY, .z = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setZ(self: *Self, inZ: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.z = inZ;
        } else {
            const impl = try state.allocator.create(Vector3IntImpl());
            impl.* = Vector3IntImpl(){ .x = 0, .y = 0, .z = inZ };
            self.inner = @ptrCast(impl);
        }
    }

    /// Returns a tuple of the resulting addition, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn add(self: *const Self, other: Vector3IntImpl()) struct { Vector3IntImpl(), bool } {
        return self.getAsImplVec().add(other);
    }

    /// Returns a tuple of the resulting subtraction, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn sub(self: *const Self, other: Vector3IntImpl()) struct { Vector3IntImpl(), bool } {
        return self.getAsImplVec().sub(other);
    }

    /// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn mul(self: *const Self, other: Vector3IntImpl()) struct { Vector3IntImpl(), bool } {
        return self.getAsImplVec().mul(other);
    }

    /// If the return value is null, that means a divide by 0 would have occurred.
    /// Otherwise, the divison result is returned.
    pub fn div(self: *const Self, other: Vector3IntImpl()) ?Vector3IntImpl() {
        return self.getAsImplVec().div(other);
    }

    pub fn dot(self: *const Self, other: Vector3IntImpl()) struct { Int, bool } {
        return self.getAsImplVec().dot(other);
    }

    pub fn getAsImplVec(self: *const Self) Vector3IntImpl() {
        if (self.asImpl()) |impl| {
            return impl.*;
        } else {
            return .{ .x = 0, .y = 0 };
        }
    }

    fn asImpl(self: *const Self) ?*const Vector3IntImpl() {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asImplMut(self: *Self) ?*Vector3IntImpl() {
        return @ptrCast(@alignCast(self.inner));
    }
};

/// 4 component 64 bit int vector. By default, initializes to { 0, 0, 0, 0 }.
/// The math operations return the implementation structure, rather than a `Vec4i`,
/// sacrificing convenience in exchange for not allocating more memory than necessary.
/// The resulting value however has an function to turn into a `Vec4i`.
pub const Vec4i = extern struct {
    const Self = @This();

    inner: ?*anyopaque = null,

    pub fn init(inX: Int, inY: Int, inZ: Int, inW: Int, state: *const CubicScriptState) Allocator.Error!Self {
        if (inX == 0 and inY == 0 and inZ == 0 and inW == 0) {
            return Self{};
        }

        const impl = try state.allocator.create(Vector4IntImpl());
        impl.* = Vector4IntImpl(){ .x = inX, .y = inY, .z = inZ, .w = inW };
        return Self{ .inner = @ptrCast(impl) };
    }

    pub fn deinit(self: *Self, state: *const CubicScriptState) void {
        if (self.asImplMut()) |impl| {
            state.allocator.destroy(impl);
            self.inner = null;
        }
    }

    pub fn clone(self: *const Self, state: *const CubicScriptState) Allocator.Error!Self {
        if (self.asImpl()) |impl| {
            return impl.toVec2i(state);
        } else {
            return Self{};
        }
    }

    pub fn x(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.x;
        } else {
            return 0;
        }
    }

    pub fn y(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.y;
        } else {
            return 0;
        }
    }

    pub fn z(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.z;
        } else {
            return 0;
        }
    }

    pub fn w(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.w;
        } else {
            return 0;
        }
    }

    pub fn setX(self: *Self, inX: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.x = inX;
        } else {
            const impl = try state.allocator.create(Vector4IntImpl());
            impl.* = Vector2IntImpl(){ .x = inX, .y = 0, .z = 0, .w = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setY(self: *Self, inY: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.y = inY;
        } else {
            const impl = try state.allocator.create(Vector4IntImpl());
            impl.* = Vector4IntImpl(){ .x = 0, .y = inY, .z = 0, .w = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setZ(self: *Self, inZ: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.z = inZ;
        } else {
            const impl = try state.allocator.create(Vector4IntImpl());
            impl.* = Vector4IntImpl(){ .x = 0, .y = 0, .z = inZ, .w = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setW(self: *Self, inW: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.w = inW;
        } else {
            const impl = try state.allocator.create(Vector4IntImpl());
            impl.* = Vector4IntImpl(){ .x = 0, .y = 0, .z = 0, .w = inW };
            self.inner = @ptrCast(impl);
        }
    }

    /// Returns a tuple of the resulting addition, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn add(self: *const Self, other: Vector4IntImpl()) struct { Vector4IntImpl(), bool } {
        return self.getAsImplVec().add(other);
    }

    /// Returns a tuple of the resulting subtraction, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn sub(self: *const Self, other: Vector4IntImpl()) struct { Vector4IntImpl(), bool } {
        return self.getAsImplVec().sub(other);
    }

    /// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn mul(self: *const Self, other: Vector4IntImpl()) struct { Vector4IntImpl(), bool } {
        return self.getAsImplVec().mul(other);
    }

    /// If the return value is null, that means a divide by 0 would have occurred.
    /// Otherwise, the divison result is returned.
    pub fn div(self: *const Self, other: Vector4IntImpl()) ?Vector4IntImpl() {
        return self.getAsImplVec().div(other);
    }

    pub fn dot(self: *const Self, other: Vector4IntImpl()) struct { Int, bool } {
        return self.getAsImplVec().dot(other);
    }

    pub fn getAsImplVec(self: *const Self) Vector4IntImpl() {
        if (self.asImpl()) |impl| {
            return impl.*;
        } else {
            return .{ .x = 0, .y = 0 };
        }
    }

    fn asImpl(self: *const Self) ?*const Vector4IntImpl() {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asImplMut(self: *Self) ?*Vector4IntImpl() {
        return @ptrCast(@alignCast(self.inner));
    }
};

/// 2 component 64 bit float vector. By default, initializes to { 0, 0 }.
/// The math operations return the implementation structure, rather than a `Vec2f`,
/// sacrificing convenience in exchange for not allocating more memory than necessary.
/// The resulting value however has an function to turn into a `Vec2f`.
pub const Vec2f = extern struct {
    const Self = @This();

    inner: ?*anyopaque = null,

    pub fn init(inX: Float, inY: Float, state: *const CubicScriptState) Allocator.Error!Self {
        if (inX == 0 and inY == 0) {
            return Self{};
        }

        const impl = try state.allocator.create(Vector2FloatImpl());
        impl.* = Vector2FloatImpl(){ .x = inX, .y = inY };
        return Self{ .inner = @ptrCast(impl) };
    }

    pub fn deinit(self: *Self, state: *const CubicScriptState) void {
        if (self.asImplMut()) |impl| {
            state.allocator.destroy(impl);
            self.inner = null;
        }
    }

    pub fn clone(self: *const Self, state: *const CubicScriptState) Allocator.Error!Self {
        if (self.asImpl()) |impl| {
            return impl.toVec2f(state);
        } else {
            return Self{};
        }
    }

    pub fn x(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.x;
        } else {
            return 0;
        }
    }

    pub fn y(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.y;
        } else {
            return 0;
        }
    }

    pub fn setX(self: *Self, inX: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.x = inX;
        } else {
            const impl = try state.allocator.create(Vector2FloatImpl());
            impl.* = Vector2FloatImpl(){ .x = inX, .y = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setY(self: *Self, inY: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.y = inY;
        } else {
            const impl = try state.allocator.create(Vector2FloatImpl());
            impl.* = Vector2FloatImpl(){ .x = 0, .y = inY };
            self.inner = @ptrCast(impl);
        }
    }

    /// Returns a tuple of the resulting addition, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn add(self: *const Self, other: Vector2FloatImpl()) Vector2FloatImpl() {
        return self.getAsImplVec().add(other);
    }

    /// Returns a tuple of the resulting subtraction, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn sub(self: *const Self, other: Vector2FloatImpl()) Vector2FloatImpl() {
        return self.getAsImplVec().sub(other);
    }

    /// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn mul(self: *const Self, other: Vector2FloatImpl()) Vector2FloatImpl() {
        return self.getAsImplVec().mul(other);
    }

    /// If the return value is null, that means a divide by 0 would have occurred.
    /// Otherwise, the divison result is returned.
    pub fn div(self: *const Self, other: Vector2FloatImpl()) ?Vector2FloatImpl() {
        return self.getAsImplVec().div(other);
    }

    pub fn dot(self: *const Self, other: Vector2FloatImpl()) Float {
        return self.getAsImplVec().dot(other);
    }

    pub fn getAsImplVec(self: *const Self) Vector2FloatImpl() {
        if (self.asImpl()) |impl| {
            return impl.*;
        } else {
            return .{ .x = 0, .y = 0 };
        }
    }

    fn asImpl(self: *const Self) ?*const Vector2FloatImpl() {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asImplMut(self: *Self) ?*Vector2FloatImpl() {
        return @ptrCast(@alignCast(self.inner));
    }
};

/// 3 component 64 bit float vector. By default, initializes to { 0, 0, 0 }.
/// The math operations return the implementation structure, rather than a `Vec3f`,
/// sacrificing convenience in exchange for not allocating more memory than necessary.
/// The resulting value however has an function to turn into a `Vec3f`.
pub const Vec3f = extern struct {
    const Self = @This();

    inner: ?*anyopaque = null,

    pub fn init(inX: Float, inY: Float, inZ: Float, state: *const CubicScriptState) Allocator.Error!Self {
        if (inX == 0.0 and inY == 0.0 and inZ == 0.0) {
            return Self{};
        }

        const impl = try state.allocator.create(Vector3FloatImpl());
        impl.* = Vector3FloatImpl(){ .x = inX, .y = inY, .z = inZ };
        return Self{ .inner = @ptrCast(impl) };
    }

    pub fn deinit(self: *Self, state: *const CubicScriptState) void {
        if (self.asImplMut()) |impl| {
            state.allocator.destroy(impl);
            self.inner = null;
        }
    }

    pub fn clone(self: *const Self, state: *const CubicScriptState) Allocator.Error!Self {
        if (self.asImpl()) |impl| {
            return impl.toVec3f(state);
        } else {
            return Self{};
        }
    }

    pub fn x(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.x;
        } else {
            return 0;
        }
    }

    pub fn y(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.y;
        } else {
            return 0;
        }
    }

    pub fn z(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.z;
        } else {
            return 0;
        }
    }

    pub fn setX(self: *Self, inX: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.x = inX;
        } else {
            const impl = try state.allocator.create(Vector3FloatImpl());
            impl.* = Vector2FloatImpl(){ .x = inX, .y = 0, .z = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setY(self: *Self, inY: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.y = inY;
        } else {
            const impl = try state.allocator.create(Vector3FloatImpl());
            impl.* = Vector3FloatImpl(){ .x = 0, .y = inY, .z = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setZ(self: *Self, inZ: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.z = inZ;
        } else {
            const impl = try state.allocator.create(Vector3FloatImpl());
            impl.* = Vector3FloatImpl(){ .x = 0, .y = 0, .z = inZ };
            self.inner = @ptrCast(impl);
        }
    }

    /// Returns a tuple of the resulting addition, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn add(self: *const Self, other: Vector3FloatImpl()) Vector3FloatImpl() {
        return self.getAsImplVec().add(other);
    }

    /// Returns a tuple of the resulting subtraction, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn sub(self: *const Self, other: Vector3FloatImpl()) Vector3FloatImpl() {
        return self.getAsImplVec().sub(other);
    }

    /// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn mul(self: *const Self, other: Vector3FloatImpl()) Vector3FloatImpl() {
        return self.getAsImplVec().mul(other);
    }

    /// If the return value is null, that means a divide by 0 would have occurred.
    /// Otherwise, the divison result is returned.
    pub fn div(self: *const Self, other: Vector3FloatImpl()) ?Vector3FloatImpl() {
        return self.getAsImplVec().div(other);
    }

    pub fn dot(self: *const Self, other: Vector3FloatImpl()) Float {
        return self.getAsImplVec().dot(other);
    }

    pub fn cross(self: *const Self, other: Vector3FloatImpl()) Vector3FloatImpl() {
        return self.getAsImplVec().cross(other);
    }

    pub fn getAsImplVec(self: *const Self) Vector3FloatImpl() {
        if (self.asImpl()) |impl| {
            return impl.*;
        } else {
            return .{ .x = 0, .y = 0 };
        }
    }

    fn asImpl(self: *const Self) ?*const Vector3FloatImpl() {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asImplMut(self: *Self) ?*Vector3FloatImpl() {
        return @ptrCast(@alignCast(self.inner));
    }
};

/// 4 component 64 bit float vector. By default, initializes to { 0, 0, 0, 0 }.
/// The math operations return the implementation structure, rather than a `Vec4f`,
/// sacrificing convenience in exchange for not allocating more memory than necessary.
/// The resulting value however has an function to turn into a `Vec4f`.
pub const Vec4f = extern struct {
    const Self = @This();

    inner: ?*anyopaque = null,

    pub fn init(inX: Float, inY: Float, inZ: Float, inW: Float, state: *const CubicScriptState) Allocator.Error!Self {
        if (inX == 0.0 and inY == 0.0 and inZ == 0.0 and inW == 0.0) {
            return Self{};
        }

        const impl = try state.allocator.create(Vector4FloatImpl());
        impl.* = Vector4FloatImpl(){ .x = inX, .y = inY, .z = inZ, .w = inW };
        return Self{ .inner = @ptrCast(impl) };
    }

    pub fn deinit(self: *Self, state: *const CubicScriptState) void {
        if (self.asImplMut()) |impl| {
            state.allocator.destroy(impl);
            self.inner = null;
        }
    }

    pub fn clone(self: *const Self, state: *const CubicScriptState) Allocator.Error!Self {
        if (self.asImpl()) |impl| {
            return impl.toVec4f(state);
        } else {
            return Self{};
        }
    }

    pub fn x(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.x;
        } else {
            return 0;
        }
    }

    pub fn y(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.y;
        } else {
            return 0;
        }
    }

    pub fn z(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.z;
        } else {
            return 0;
        }
    }

    pub fn w(self: *const Self) Int {
        if (self.asImpl()) |impl| {
            return impl.w;
        } else {
            return 0;
        }
    }

    pub fn setX(self: *Self, inX: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.x = inX;
        } else {
            const impl = try state.allocator.create(Vector4FloatImpl());
            impl.* = Vector4FloatImpl(){ .x = inX, .y = 0, .z = 0, .w = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setY(self: *Self, inY: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.y = inY;
        } else {
            const impl = try state.allocator.create(Vector4FloatImpl());
            impl.* = Vector4FloatImpl(){ .x = 0, .y = inY, .z = 0, .w = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setZ(self: *Self, inZ: Int, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.z = inZ;
        } else {
            const impl = try state.allocator.create(Vector4FloatImpl());
            impl.* = Vector4FloatImpl(){ .x = 0, .y = 0, .z = inZ, .w = 0 };
            self.inner = @ptrCast(impl);
        }
    }

    pub fn setW(self: *Self, inW: Float, state: *const CubicScriptState) Allocator.Error!void {
        if (self.asImplMut()) |impl| {
            impl.w = inW;
        } else {
            const impl = try state.allocator.create(Vector4FloatImpl());
            impl.* = Vector4FloatImpl(){ .x = 0, .y = 0, .z = 0, .w = inW };
            self.inner = @ptrCast(impl);
        }
    }

    /// Returns a tuple of the resulting addition, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn add(self: *const Self, other: Vector4FloatImpl()) Vector4FloatImpl() {
        return self.getAsImplVec().add(other);
    }

    /// Returns a tuple of the resulting subtraction, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn sub(self: *const Self, other: Vector4FloatImpl()) Vector4FloatImpl() {
        return self.getAsImplVec().sub(other);
    }

    /// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow occurred.
    /// If overflow occurrs, the result is wrapped around.
    pub fn mul(self: *const Self, other: Vector4FloatImpl()) Vector4FloatImpl() {
        return self.getAsImplVec().mul(other);
    }

    /// If the return value is null, that means a divide by 0 would have occurred.
    /// Otherwise, the divison result is returned.
    pub fn div(self: *const Self, other: Vector4FloatImpl()) ?Vector4FloatImpl() {
        return self.getAsImplVec().div(other);
    }

    pub fn dot(self: *const Self, other: Vector4FloatImpl()) Float {
        return self.getAsImplVec().dot(other);
    }

    pub fn getAsImplVec(self: *const Self) Vector4FloatImpl() {
        if (self.asImpl()) |impl| {
            return impl.*;
        } else {
            return .{ .x = 0, .y = 0 };
        }
    }

    fn asImpl(self: *const Self) ?*const Vector4FloatImpl() {
        return @ptrCast(@alignCast(self.inner));
    }

    fn asImplMut(self: *Self) ?*Vector4FloatImpl() {
        return @ptrCast(@alignCast(self.inner));
    }
};

// https://www.youtube.com/watch?v=PxUkTxA8OWU
fn GenericVectorInt(comptime Vec: type) type {
    // https://ziglang.org/documentation/master/#Wrapping-Operations
    return struct {
        /// Returns a tuple of the resulting addition, as well as a bool for if integer overflow occurred.
        /// If overflow occurrs, the result is wrapped around.
        pub fn add(self: Vec, other: Vec) struct { Vec, bool } {
            var result: Vec = undefined;
            var didOverflow = false;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                const lhs: Int = @field(self, field.name);
                const rhs: Int = @field(other, field.name);

                const temp = math.addOverflow(lhs, rhs);

                @field(result, field.name) = temp.@"0";
                if (temp.@"1") {
                    didOverflow = true;
                }
            }
            return .{ result, didOverflow };
        }

        /// Returns a tuple of the resulting subtraction, as well as a bool for if integer overflow occurred.
        /// If overflow occurrs, the result is wrapped around.
        pub fn sub(self: Vec, other: Vec) struct { Vec, bool } {
            var result: Vec = undefined;
            var didOverflow = false;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                const lhs: Int = @field(self, field.name);
                const rhs: Int = @field(other, field.name);

                const temp = math.subOverflow(lhs, rhs);

                @field(result, field.name) = temp.@"0";
                if (temp.@"1") {
                    didOverflow = true;
                }
            }
            return .{ result, didOverflow };
        }

        /// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow occurred.
        /// If overflow occurrs, the result is wrapped around.
        pub fn mul(self: Vec, other: Vec) struct { Vec, bool } {
            var result: Vec = undefined;
            var didOverflow = false;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                const lhs: Int = @field(self, field.name);
                const rhs: Int = @field(other, field.name);

                const temp = math.mulOverflow(lhs, rhs);

                @field(result, field.name) = temp.@"0";
                if (temp.@"1") {
                    didOverflow = true;
                }
            }
            return .{ result, didOverflow };
        }

        /// If the return value is null, that means a divide by 0 would have occurred.
        /// Otherwise, the divison result is returned.
        pub fn div(self: Vec, other: Vec) ?Vec {
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                if (@field(other, field.name) == 0) {
                    return null;
                }
            }
            var result: Vec = undefined;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                const lhs: Int = @field(self, field.name);
                const rhs: Int = @field(other, field.name);

                @field(result, field.name) = @divTrunc(lhs, rhs);
            }
            return result;
        }

        pub fn dot(self: Vec, other: Vec) struct { Int, bool } {
            var result: Int = 0;
            var didOverflow = false;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                const tempMul = math.mulOverflow(@field(self, field.name), @field(other, field.name));
                if (tempMul.@"1") {
                    didOverflow = true;
                }
                const tempAdd = math.addOverflow(result, tempMul.@"0");
                if (tempAdd.@"1") {
                    didOverflow = true;
                }
                result = tempAdd.@"0";
            }
            return result;
        }

        pub fn cross(self: Vec, other: Vec) struct { Vec, bool } {
            if (@typeInfo(Vec).Struct.fields.len != 3) @compileError("Only available for vectors of length 3.");
            const vecFields = @typeInfo(Vec).Struct.fields;
            var didOverflow = false;

            const y1z2 = math.mulOverflow(@field(self, vecFields[1].name), @field(other, vecFields[2].name));
            const z1y2 = math.mulOverflow(@field(self, vecFields[2].name), @field(other, vecFields[1].name));

            const x1z2 = math.mulOverflow(@field(self, vecFields[0].name), @field(other, vecFields[2].name));
            const z1x2 = math.mulOverflow(@field(self, vecFields[2].name), @field(other, vecFields[0].name));

            const x1y2 = math.mulOverflow(@field(self, vecFields[0].name), @field(other, vecFields[1].name));
            const y1x2 = math.mulOverflow(@field(self, vecFields[1].name), @field(other, vecFields[0].name));

            if (y1z2.@"1" == true or z1y2.@"1" == true or x1z2.@"1" == true or z1x2.@"1" == true or x1y2.@"1" == true or y1x2.@"1") {
                didOverflow = true;
            }

            const x = math.subOverflow(y1z2, z1y2);
            const y = math.subOverflow(x1z2, z1x2);
            const z = math.subOverflow(x1y2, y1x2);

            if (x.@"1" == true or y.@"1" == true or z.@"1" == true) {
                didOverflow = true;
            }

            const outVec = Vec{
                .x = x.@"0",
                .y = y.@"0",
                .z = z.@"0",
            };

            return .{ outVec, didOverflow };
        }
    };
}

// https://www.youtube.com/watch?v=PxUkTxA8OWU
fn GenericVectorFloat(comptime Vec: type) type {
    return struct {
        /// Returns the resulting float additions.
        pub fn add(self: Vec, other: Vec) Vec {
            var result: Vec = undefined;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) + @field(other, field.name);
            }
            return result;
        }

        /// Returns the resulting float subtractions.
        pub fn sub(self: Vec, other: Vec) Vec {
            var result: Vec = undefined;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) + @field(other, field.name);
            }
            return result;
        }

        /// Returns the resulting float multiplications.
        pub fn mul(self: Vec, other: Vec) Vec {
            var result: Vec = undefined;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) + @field(other, field.name);
            }
            return result;
        }

        /// If the return value is null, that means a divide by 0 would have occurred.
        /// Otherwise, the divison result is returned.
        pub fn div(self: Vec, other: Vec) ?Vec {
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                if (@field(other, field.name) == 0.0) {
                    return null;
                }
            }
            var result: Vec = undefined;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) + @field(other, field.name);
            }
            return result;
        }

        pub fn dot(self: Vec, other: Vec) Vec {
            var result: Float = 0;
            inline for (@typeInfo(Vec).Struct.fields) |field| {
                result += @field(self, field.name) * @field(other, field.name);
            }
            return result;
        }

        /// https://github.com/PixelGuys/Cubyz/commit/b3ea5d517ce7f9e86b7ba25cb0fc5d91b80b36b1
        pub fn cross(self: Vec, other: Vec) Vec {
            if (@typeInfo(Vec).Struct.fields.len != 3) @compileError("Only available for vectors of length 3.");
            return Vec{
                .x = (self.y * other.z) - (self.z * other.y),
                .y = (self.z * other.x) - (self.x * other.z),
                .z = (self.x * other.y) - (self.y * other.x),
            };
        }
    };
}

pub fn Vector2IntImpl() type {
    return extern struct {
        x: Int,
        y: Int,

        pub usingnamespace GenericVectorInt(@This());
        pub fn toVec2i(self: @This(), state: *const CubicScriptState) Allocator.Error!Vec2i {
            return Vec2i.init(self.x, self.y, state);
        }
    };
}

pub fn Vector3IntImpl() type {
    return extern struct {
        x: Int,
        y: Int,
        z: Int,

        pub usingnamespace GenericVectorInt(@This());
        pub fn toVec3i(self: @This(), state: *const CubicScriptState) Allocator.Error!Vec3i {
            return Vec3i.init(self.x, self.y, self.z, state);
        }
    };
}

pub fn Vector4IntImpl() type {
    return extern struct {
        x: Int,
        y: Int,
        z: Int,
        w: Int,

        pub usingnamespace GenericVectorInt(@This());
        pub fn toVec4i(self: @This(), state: *const CubicScriptState) Allocator.Error!Vec4i {
            return Vec4i.init(self.x, self.y, self.z, self.w, state);
        }
    };
}

pub fn Vector2FloatImpl() type {
    return extern struct {
        x: Float,
        y: Float,

        pub usingnamespace GenericVectorFloat(@This());
        pub fn toVec2f(self: @This(), state: *const CubicScriptState) Allocator.Error!Vec2i {
            return Vec2f.init(self.x, self.y, state);
        }
    };
}

pub fn Vector3FloatImpl() type {
    return extern struct {
        x: Float,
        y: Float,
        z: Float,

        pub usingnamespace GenericVectorFloat(@This());
        pub fn toVec3f(self: @This(), state: *const CubicScriptState) Allocator.Error!Vec3i {
            return Vec3f.init(self.x, self.y, self.z, state);
        }
    };
}

pub fn Vector4FloatImpl() type {
    return extern struct {
        x: Float,
        y: Float,
        z: Float,
        w: Float,

        pub usingnamespace GenericVectorFloat(@This());
        pub fn toVec4f(self: @This(), state: *const CubicScriptState) Allocator.Error!Vec4i {
            return Vec4f.init(self.x, self.y, self.z, self.w, state);
        }
    };
}

test "Vec2i" {
    var state = try CubicScriptState.init(std.testing.allocator);
    defer state.deinit();
    {
        var v = Vec2i{};
        defer v.deinit(state);

        try expect(v.x() == 0);
        try expect(v.y() == 0);

        const result = v.add(.{ .x = 0, .y = 0 });
        try expect(result.@"0".x == 0);
        try expect(result.@"0".y == 0);
        try expect(result.@"1" == false);

        var vClone = try v.clone(state);
        defer vClone.deinit(state);

        try expect(vClone.x() == 0);
        try expect(vClone.y() == 0);
    }
    {
        var v = try Vec2i.init(1, 1, state);
        defer v.deinit(state);

        try expect(v.x() == 1);
        try expect(v.y() == 1);

        const result = v.add(.{ .x = -1, .y = 1 });
        try expect(result.@"0".x == 0);
        try expect(result.@"0".y == 2);
        try expect(result.@"1" == false);

        var vClone = try v.clone(state);
        defer vClone.deinit(state);

        try expect(vClone.x() == 1);
        try expect(vClone.y() == 1);
    }
    {
        var v = try Vec2i.init(MAX_INT, MIN_INT, state);
        defer v.deinit(state);

        try expect(v.x() == MAX_INT);
        try expect(v.y() == MIN_INT);

        const result = v.add(.{ .x = 1, .y = 1 });
        try expect(result.@"0".x == MIN_INT);
        try expect(result.@"0".y == MIN_INT + 1);
        try expect(result.@"1" == true);

        var vClone = try v.clone(state);
        defer vClone.deinit(state);

        try expect(vClone.x() == MAX_INT);
        try expect(vClone.y() == MIN_INT);
    }
    {
        var v = try Vec2i.init(MAX_INT, MIN_INT, state);
        defer v.deinit(state);

        try expect(v.x() == MAX_INT);
        try expect(v.y() == MIN_INT);

        const result = v.add(.{ .x = -1, .y = -1 });
        try expect(result.@"0".x == MAX_INT - 1);
        try expect(result.@"0".y == MAX_INT);
        try expect(result.@"1" == true);
    }
}
