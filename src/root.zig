const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const global_allocator = @import("state/global_allocator.zig");

pub const allocator = global_allocator.allocator;
pub const setAllocator = global_allocator.setAllocator;

comptime {
    _ = @import("c_export.zig");
}

pub const CubicScriptState = @import("state/CubicScriptState.zig");

pub const Bytecode = @import("state/Bytecode.zig");

pub const String = @import("types/string.zig").String;

pub const Array = @import("types/array.zig").Array;

pub const Map = @import("types/map.zig").Map;

pub const Set = @import("types/set.zig").Set;

pub const Vec2i = vector_types.Vec2i;

pub const Vec3i = vector_types.Vec3i;

pub const Vec4i = vector_types.Vec4i;

pub const Vec2f = vector_types.Vec2f;

pub const Vec3f = vector_types.Vec3f;

pub const Vec4f = vector_types.Vec4f;

pub const Option = @import("types/option.zig").Option;

pub const vector_types = @import("types/vector.zig");

pub const ValueTag = enum(c_uint) { // Reasonable default enum size for C
    None = 0,
    Bool = 1,
    Int = 2,
    Float = 3,
    String = 4,
    Array = 5,
    Map = 6,
    Set = 7,
    Vec2i = 8,
    Vec3i = 9,
    Vec4i = 10,
    Vec2f = 11,
    Vec3f = 12,
    Vec4f = 13,
    Mat4f = 14,
    ConstRef = 15,
    MutRef = 16,
    Option = 17,
    Error = 18,
    Class = 19,
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
    vec2i: Vec2i,
    vec3i: Vec3i,
    vec4i: Vec4i,
    vec2f: Vec2f,
    vec3f: Vec3f,
    vec4f: Vec4f,
    // TODO other primitive types

    /// In some cases, it's more convenient to just deinit here.
    pub fn deinit(self: *RawValue, tag: ValueTag, state: *const CubicScriptState) void {
        switch (tag) {
            .Bool, .Int, .Float => {},
            .String => {
                self.string.deinit(state);
            },
            .Array => {
                self.array.deinit(state);
            },
            .Map => {
                self.map.deinit(state);
            },
            .Set => {
                self.set.deinit(state);
            },
            .Vec2i => {
                self.vec2i.deinit(state);
            },
            .Vec3i => {
                self.vec3i.deinit(state);
            },
            .Vec4i => {
                self.vec4i.deinit(state);
            },
            .Vec2f => {
                self.vec2f.deinit(state);
            },
            .Vec3f => {
                self.vec3f.deinit(state);
            },
            .Vec4f => {
                self.vec4f.deinit(state);
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

    pub fn deinit(self: *TaggedValue, state: *const CubicScriptState) void {
        self.value.deinit(self.tag, state);
    }
};

pub const TaggedValueMutRef = extern struct {
    value: *RawValue,
    tag: ValueTag,
};

pub const TaggedValueConstRef = extern struct {
    value: *const RawValue,
    tag: ValueTag,
};

pub const OptionalTaggedValueMutRef = extern struct {
    value: ?*RawValue,
    tag: ValueTag,
};

pub const OptionalTaggedValueConstRef = extern struct {
    value: ?*const RawValue,
    tag: ValueTag,
};

pub const Ordering = enum(i64) {
    Less = -1,
    Equal = 0,
    Greater = 1,
};
