const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const global_allocator = @import("state/global_allocator.zig");

comptime {
    _ = @import("c_export.zig");
}

pub const CubicScriptState = @import("state/CubicScriptState.zig");
pub const allocator = global_allocator.allocator;
pub const setAllocator = global_allocator.setAllocator;
pub const sync_queue = @import("state/sync_queue.zig");

pub const String = @import("types/string.zig").String;
pub const Array = @import("types/array.zig").Array;
pub const Map = @import("types/map.zig").Map;
pub const Set = @import("types/set.zig").Set;
pub const Option = @import("types/option.zig").Option;
pub const Result = @import("types/result.zig").Result;
pub const Class = @import("types/class.zig").Class;
pub const OwnedInterface = @import("types/interface.zig").OwnedInterface;
pub const InterfaceRef = @import("types/interface.zig").InterfaceRef;
pub const ValueConstRef = @import("types/references.zig").ValueConstRef;
pub const ValueMutRef = @import("types/references.zig").ValueMutRef;
pub const Unique = @import("types/references.zig").Unique;
pub const Shared = @import("types/references.zig").Shared;
pub const Weak = @import("types/references.zig").Weak;
pub const FunctionPtr = @import("types/function.zig").FunctionPtr;
pub const Vec2i = vector_types.Vec2i;
pub const Vec3i = vector_types.Vec3i;
pub const Vec4i = vector_types.Vec4i;
pub const Vec2f = vector_types.Vec2f;
pub const Vec3f = vector_types.Vec3f;
pub const Vec4f = vector_types.Vec4f;
pub const Mat3f = @import("types/matrix.zig").Mat3f;
pub const Mat4f = @import("types/matrix.zig").Mat4f;

const vector_types = @import("types/vector.zig");

pub const Bytecode = @import("state/Bytecode.zig");

pub const ValueTag = enum(c_int) {
    None = 0,
    Bool = 1,
    Int = 2,
    Float = 3,
    String = 4,
    Array = 5,
    Map = 6,
    Set = 7,
    Option = 8,
    Result = 9,
    Class = 10,
    OwnedInterface = 11,
    InterfaceRef = 12,
    ConstRef = 13,
    MutRef = 14,
    Unique = 15,
    Shared = 16,
    Weak = 17,
    FunctionPtr = 18,
    Vec2i,
    Vec3i,
    Vec4i,
    Vec2f,
    Vec3f,
    Vec4f,
    Mat3f,
    Mat4f,
    Quat, // maybe unnecessary

    pub fn asUsize(self: @This()) usize {
        return @intCast(@as(c_int, @intFromEnum(self)));
    }

    pub fn asU8(self: @This()) u8 {
        return @intCast(@as(c_int, @intFromEnum(self)));
    }

    pub fn asU5(self: @This()) u5 {
        return @intCast(@as(c_int, @intFromEnum(self)));
    }
};

/// Untagged union representing all primitive value types and classes.
pub const RawValue = extern union {
    actualValue: usize,
    boolean: bool,
    int: i64,
    float: f64,
    string: String,
    array: Array,
    map: Map,
    set: Set,
    option: Option,
    result: Result,
    class: Class,
    ownedInterface: OwnedInterface,
    interfaceRef: *InterfaceRef,
    constRef: ValueConstRef,
    mutRef: ValueMutRef,
    unique: Unique,
    shared: Shared,
    weak: Weak,
    functionPtr: FunctionPtr,
    vec2i: Vec2i,
    vec3i: Vec3i,
    vec4i: Vec4i,
    vec2f: Vec2f,
    vec3f: Vec3f,
    vec4f: Vec4f,
    mat3f: Mat3f,
    mat4f: Mat4f,

    /// In some cases, it's more convenient to just deinit here.
    /// If `tag` is `.Interface`, the programmer must ensure
    /// that `self` owns the interface, rather than is holding a reference to it.
    pub fn deinit(self: *RawValue, tag: ValueTag) void {
        switch (tag) {
            .Bool, .Int, .Float, .ConstRef, .MutRef, .InterfaceRef, .FunctionPtr => {},
            .String => {
                self.string.deinit();
            },
            .Array => {
                self.array.deinit();
            },
            .Map => {
                self.map.deinit();
            },
            .Set => {
                self.set.deinit();
            },
            .Option => {
                self.option.deinit();
            },
            .Result => {
                self.result.deinit();
            },
            .Class => {
                self.class.deinit();
            },
            .OwnedInterface => {
                self.ownedInterface.deinit();
            },
            .Unique => {
                self.unique.deinit();
            },
            .Shared => {
                self.shared.deinit();
            },
            .Weak => {
                self.weak.deinit();
            },
            .Vec2i => {
                self.vec2i.deinit();
            },
            .Vec3i => {
                self.vec3i.deinit();
            },
            .Vec4i => {
                self.vec4i.deinit();
            },
            .Vec2f => {
                self.vec2f.deinit();
            },
            .Vec3f => {
                self.vec3f.deinit();
            },
            .Vec4f => {
                self.vec4f.deinit();
            },
            .Mat3f => {
                self.mat3f.deinit();
            },
            .Mat4f => {
                self.mat4f.deinit();
            },
            else => {
                @panic("Unsupported");
            },
        }
    }

    /// Makes a unique clone of the self raw value, and the tag.
    /// Performs the necessary allocations for whatever the type is.
    pub fn clone(self: *const RawValue, tag: ValueTag) RawValue {
        switch (tag) {
            .Bool, .Int, .Float => {
                return self.*;
            },
            .String => {
                return RawValue{ .string = self.string.clone() };
            },
            .Array => {
                return RawValue{ .array = self.array.clone() };
            },
            else => {
                @panic("Unsupported");
            },
        }
    }
};

/// Compatible with C
pub const TaggedValue = extern struct {
    value: RawValue,
    tag: ValueTag,

    /// For zig/c compatibility
    pub fn initBool(inBool: bool) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Bool, .value = .{ .boolean = inBool } };
    }
    /// For zig/c compatibility
    pub fn initInt(inInt: i64) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Int, .value = .{ .int = inInt } };
    }

    /// For zig/c compatibility
    pub fn initFloat(inFloat: f64) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Float, .value = .{ .float = inFloat } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inString`.
    pub fn initString(inString: String) TaggedValue {
        return TaggedValue{ .tag = ValueTag.String, .value = .{ .string = inString } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inArray`.
    pub fn initArray(inArray: Array) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Array, .value = .{ .array = inArray } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inMap`.
    pub fn initMap(inMap: Map) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Map, .value = .{ .map = inMap } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inVec`.
    pub fn initVec2i(inVec: Vec2i) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Vec2i, .value = .{ .vec2i = inVec } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inVec`.
    pub fn initVec3i(inVec: Vec3i) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Vec3i, .value = .{ .vec3i = inVec } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inVec`.
    pub fn initVec4i(inVec: Vec4i) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Vec4i, .value = .{ .vec4i = inVec } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inVec`.
    pub fn initVec2f(inVec: Vec2f) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Vec2f, .value = .{ .vec2f = inVec } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inVec`.
    pub fn initVec3f(inVec: Vec3f) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Vec3f, .value = .{ .vec3f = inVec } };
    }

    /// For zig/c compatibility.
    /// Takes ownership of `inVec`.
    pub fn initVec4f(inVec: Vec4f) TaggedValue {
        return TaggedValue{ .tag = ValueTag.Vec4f, .value = .{ .vec4f = inVec } };
    }

    pub fn deinit(self: *TaggedValue) void {
        self.value.deinit(self.tag);
    }
};

pub const ScriptFunctionArgs = @import("types/function.zig").ScriptFunctionArgs;

pub const Ordering = enum(i64) {
    Less = -1,
    Equal = 0,
    Greater = 1,
};
