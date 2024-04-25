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
pub const Shared = @import("types/references.zig").Shared;
pub const Weak = @import("types/references.zig").Weak;
pub const Vec2i = vector_types.Vec2i;
pub const Vec3i = vector_types.Vec3i;
pub const Vec4i = vector_types.Vec4i;
pub const Vec2f = vector_types.Vec2f;
pub const Vec3f = vector_types.Vec3f;
pub const Vec4f = vector_types.Vec4f;

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
    Shared = 11,
    ConstRef,
    MutRef,
    Vec2i,
    Vec3i,
    Vec4i,
    Vec2f,
    Vec3f,
    Vec4f,
    Mat4f,
    // TODO function pointer

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
    shared: Shared,
    vec2i: Vec2i,
    vec3i: Vec3i,
    vec4i: Vec4i,
    vec2f: Vec2f,
    vec3f: Vec3f,
    vec4f: Vec4f,
    // TODO other primitive types

    /// In some cases, it's more convenient to just deinit here.
    pub fn deinit(self: *RawValue, tag: ValueTag) void {
        switch (tag) {
            .Bool, .Int, .Float => {},
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
            .Shared => {
                self.shared.deinit();
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

const TAGGED_REF_PTR_BITMASK = 0xFFFFFFFFFFFF;
const TAGGED_REF_TAG_BITMASK: usize = ~@as(usize, TAGGED_REF_PTR_BITMASK);
const TAGGED_REF_SHIFT = 48;

pub const TaggedValueMutRef = extern struct {
    taggedPtr: usize,

    pub fn init(inTag: ValueTag, inValue: *RawValue) @This() {
        const maskTag: usize = @shlExact(inTag.asUsize(), TAGGED_REF_SHIFT);
        return .{ .taggedPtr = maskTag | @intFromPtr(inValue) };
    }

    pub fn tag(self: *const @This()) ValueTag {
        const mask = self.taggedPtr & TAGGED_REF_TAG_BITMASK;
        return @enumFromInt(@shrExact(mask, TAGGED_REF_SHIFT));
    }

    pub fn value(self: *const @This()) *RawValue {
        const mask = self.taggedPtr & TAGGED_REF_PTR_BITMASK;
        return @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(mask))));
    }
};

pub const TaggedValueConstRef = extern struct {
    taggedPtr: usize,

    pub fn init(inTag: ValueTag, inValue: *const RawValue) @This() {
        const maskTag: usize = @shlExact(inTag.asUsize(), TAGGED_REF_SHIFT);
        return .{ .taggedPtr = maskTag | @intFromPtr(inValue) };
    }

    pub fn tag(self: *const @This()) ValueTag {
        const mask = self.taggedPtr & TAGGED_REF_TAG_BITMASK;
        return @enumFromInt(@shrExact(mask, TAGGED_REF_SHIFT));
    }

    pub fn value(self: *const @This()) *const RawValue {
        const mask = self.taggedPtr & TAGGED_REF_PTR_BITMASK;
        return @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(mask))));
    }
};

/// Zero initialized means none option.
pub const OptionalTaggedValueMutRef = extern struct {
    taggedPtr: usize = 0,

    pub fn init(inTag: ValueTag, inValue: *RawValue) @This() {
        const maskTag: usize = @shlExact(inTag.asUsize(), TAGGED_REF_SHIFT);
        return .{ .taggedPtr = maskTag | @intFromPtr(inValue) };
    }

    pub fn isNone(self: *const @This()) bool {
        return self.taggedPtr == 0;
    }

    /// Asserts `!self.isNone()`.
    pub fn tag(self: *const @This()) ValueTag {
        assert(!self.isNone());
        const mask = self.taggedPtr & TAGGED_REF_TAG_BITMASK;
        return @enumFromInt(@shrExact(mask, TAGGED_REF_SHIFT));
    }

    /// Asserts `!self.isNone()`.
    pub fn value(self: *const @This()) *RawValue {
        assert(!self.isNone());
        const mask = self.taggedPtr & TAGGED_REF_PTR_BITMASK;
        return @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(mask))));
    }
};

/// Zero initialized means none option.
pub const OptionalTaggedValueConstRef = extern struct {
    taggedPtr: usize = 0,

    pub fn init(inTag: ValueTag, inValue: *const RawValue) @This() {
        const maskTag: usize = @shlExact(inTag.asUsize(), TAGGED_REF_SHIFT);
        return .{ .taggedPtr = maskTag | @intFromPtr(inValue) };
    }

    pub fn isNone(self: *const @This()) bool {
        return self.taggedPtr == 0;
    }

    /// Asserts `!self.isNone()`.
    pub fn tag(self: *const @This()) ValueTag {
        assert(!self.isNone());
        const mask = self.taggedPtr & TAGGED_REF_TAG_BITMASK;
        return @enumFromInt(@shrExact(mask, TAGGED_REF_SHIFT));
    }

    /// Asserts `!self.isNone()`.
    pub fn value(self: *const @This()) *const RawValue {
        assert(!self.isNone());
        const mask = self.taggedPtr & TAGGED_REF_PTR_BITMASK;
        return @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(mask))));
    }
};

pub const Ordering = enum(i64) {
    Less = -1,
    Equal = 0,
    Greater = 1,
};
