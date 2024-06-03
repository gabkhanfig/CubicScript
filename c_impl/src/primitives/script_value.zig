const std = @import("std");

const c = struct {
    extern fn cubs_raw_value_deinit(self: *RawValue, tag: ValueTag) void;
    extern fn cubs_raw_value_clone(self: *const RawValue, tag: ValueTag) RawValue;
    extern fn cubs_raw_value_eql(self: *const RawValue, other: *const RawValue, tag: ValueTag) bool;

    extern fn cubs_tagged_value_deinit(self: *CTaggedValue) void;
    extern fn cubs_tagged_value_clone(self: *const RawValue) CTaggedValue;
    extern fn cubs_tagged_value_eql(self: *const CTaggedValue, other: *const CTaggedValue) bool;
};

pub const String = @import("string/string.zig").String;
pub const Array = @import("array/array.zig").Array;
pub const Set = @import("set/set.zig").Set;
pub const Map = @import("map/map.zig").Map;
pub const Option = @import("option/option.zig").Option;

pub const ValueTag = enum(c_int) {
    none = 0,
    bool = 1,
    int = 2,
    float = 3,
    char = 4,
    string = 5,
    stringIter = 6,
    array = 7,
    arrayConstIter = 8,
    arrayMutIter = 9,
    set = 10,
    setIter = 11,
    map = 12,
    mapConstIter = 13,
    mapMutIter = 14,
    option = 15,
    err = 16,
    result = 17,
    taggedUnion = 18,
    class = 19,
    ownedInterface = 20,
    interfaceRef = 21,
    constRef = 22,
    mutRef = 23,
    unique = 24,
    shared = 25,
    weak = 26,
    functionPtr = 27,
    future = 28,
    vec2i = 29,
    vec3i = 30,
    vec4i = 31,
    vec2f = 32,
    vec3f = 33,
    vec4f = 34,
    mat3f = 35,
    mat4f = 36,
};

pub const RawValue = extern union {
    boolean: bool,
    int: i64,
    float: f64,
    string: String,
    array: Array(anyopaque),
    set: Set(anyopaque),
    map: Map(anyopaque, anyopaque),
    option: Option(anyopaque),
    // result: Result,
    // class: Class,
    // ownedInterface: OwnedInterface,
    // interfaceRef: *InterfaceRef,
    // constRef: ValueConstRef,
    // mutRef: ValueMutRef,
    // unique: Unique,
    // shared: Shared,
    // weak: Weak,
    // functionPtr: FunctionPtr,
    // vec2i: Vec2i,
    // vec3i: Vec3i,
    // vec4i: Vec4i,
    // vec2f: Vec2f,
    // vec3f: Vec3f,
    // vec4f: Vec4f,
    // mat3f: Mat3f,
    // mat4f: Mat4f,

    pub fn deinit(self: *RawValue, tag: ValueTag) void {
        c.cubs_raw_value_deinit(self, tag);
    }

    pub fn clone(self: *const RawValue, tag: ValueTag) RawValue {
        return c.cubs_raw_value_clone(self, tag);
    }

    pub fn eql(self: *const RawValue, other: *const RawValue, tag: ValueTag) bool {
        return c.cubs_raw_value_eql(self, other, tag);
    }
};

/// Compatible with C. Corresponds to `CubsTaggedValue`.
pub const CTaggedValue = extern struct {
    value: RawValue,
    tag: ValueTag,

    pub fn deinit(self: *CTaggedValue) void {
        c.cubs_tagged_value_deinit(self);
    }

    pub fn clone(self: *const CTaggedValue) CTaggedValue {
        return c.cubs_tagged_value_clone(self);
    }

    pub fn eql(self: *const CTaggedValue, other: *const CTaggedValue) bool {
        return c.cubs_tagged_value_eql(self, other);
    }
};

/// Zig version of `CTaggedValue` using language specific tagged unions.
/// Can be converted to an from the c representation.
pub const TaggedValue = union(ValueTag) {
    const Self = @This();

    comptime {
        if (@sizeOf(Self) != @sizeOf(CTaggedValue)) {
            @compileError("Tagged union script value incorrect size");
        }
        if (@alignOf(Self) != @alignOf(CTaggedValue)) {
            @compileError("Tagged union script value incorrect alignment");
        }
    }

    none: void,
    bool: bool,
    int: i64,
    float: f64,
    char: void,
    string: String,
    stringIter: void,
    array: Array(anyopaque),
    arrayConstIter: void,
    arrayMutIter: void,
    set: Set(anyopaque),
    setIter: void,
    map: Map(anyopaque, anyopaque),
    mapConstIter: void,
    mapMutIter: void,
    option: Option(anyopaque),
    err: void,
    result: void,
    taggedUnion: void,
    class: void,
    ownedInterface: void,
    interfaceRef: void,
    constRef: void,
    mutRef: void,
    unique: void,
    shared: void,
    weak: void,
    functionPtr: void,
    future: void,
    vec2i: void,
    vec3i: void,
    vec4i: void,
    vec2f: void,
    vec3f: void,
    vec4f: void,
    mat3f: void,
    mat4f: void,

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .int => |_| {},
            .bool => |_| {},
            .float => |_| {},
            .string => |*str| {
                str.deinit();
            },
            .array => |*a| {
                a.deinit();
            },
            .set => |*s| {
                s.deinit();
            },
            .map => |*m| {
                m.deinit();
            },
            else => {},
        }
    }

    pub fn clone(self: *const TaggedValue) CTaggedValue {
        return c.cubs_raw_value_clone(self.value(), self.tag());
    }

    pub fn eql(self: *const TaggedValue, other: *const TaggedValue) bool {
        return c.cubs_raw_value_eql(self.value(), other.value(), self.tag());
    }

    pub fn fromCRepr(consumeValue: CTaggedValue) Self {
        const valueTag = consumeValue.tag;
        const raw = consumeValue.value;
        switch (valueTag) {
            .none => {
                return Self{ .none = {} };
            },
            .bool => {
                return Self{ .bool = raw.boolean };
            },
            .int => {
                return Self{ .int = raw.int };
            },
            .float => {
                return Self{ .float = raw.float };
            },
            .string => {
                return Self{ .string = raw.string };
            },
            .array => {
                return Self{ .array = raw.array };
            },
            .set => {
                return Self{ .set = raw.set };
            },
            .map => {
                return Self{ .map = raw.map };
            },
            else => {
                unreachable;
            },
        }
    }

    /// Consumes `self`, turning it into the C representation of `CTaggedValue`
    pub fn intoCRepr(self: *Self) CTaggedValue {
        const cVal = @call(std.builtin.CallModifier.always_inline, zigToCTaggedValueTemp, .{self.*});
        self.* = undefined; // prevent use after free
        return cVal;
    }

    pub fn tag(self: *const Self) ValueTag {
        return @as(ValueTag, self.*);
    }

    pub fn value(self: *const Self) *const RawValue {
        switch (self.*) {
            ValueTag.bool => |*bv| {
                return @ptrCast(@alignCast(bv));
            },
            ValueTag.int => |*num| {
                return @ptrCast(@alignCast(num));
            },
            ValueTag.float => |*num| {
                return @ptrCast(@alignCast(num));
            },
            ValueTag.string => |*s| {
                return @ptrCast(@alignCast(s));
            },
            ValueTag.set => |*s| {
                return @ptrCast(@alignCast(s));
            },
            ValueTag.map => |*m| {
                return @ptrCast(@alignCast(m));
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn valueMut(self: *Self) *RawValue {
        return @constCast(self.value());
    }

    test "values occupy same offset" {
        const OffsetContainer = struct {
            offset: usize,
            tag: ValueTag,

            fn appendTagged(tagged: *const Self, offsetsArray: *std.ArrayList(@This())) std.mem.Allocator.Error!void {
                const offset: usize = @intFromPtr(tagged.value()) - @intFromPtr(tagged);
                //std.debug.print("offset of tag {s} is {}\n", .{ @tagName(tagged.tag()), offset });
                try offsetsArray.append(.{ .offset = offset, .tag = tagged.tag() });
            }
        };
        var offsets = std.ArrayList(OffsetContainer).init(std.testing.allocator);
        defer offsets.deinit();

        var tagBool = Self{ .bool = true };
        defer tagBool.deinit();
        try OffsetContainer.appendTagged(&tagBool, &offsets);

        var tagInt = Self{ .int = 16 };
        defer tagInt.deinit();
        try OffsetContainer.appendTagged(&tagInt, &offsets);

        var tagFloat = Self{ .float = 16.99 };
        defer tagFloat.deinit();
        try OffsetContainer.appendTagged(&tagFloat, &offsets);

        var tagString = Self{ .string = String.initUnchecked("suh") };
        defer tagString.deinit();
        try OffsetContainer.appendTagged(&tagString, &offsets);

        var _tempSet = Set(i64).init();
        var tagSet = Self{ .set = _tempSet.into(anyopaque) };
        defer tagSet.deinit();
        try OffsetContainer.appendTagged(&tagSet, &offsets);

        var _tempMap = Map(i64, f64).init();
        var tagMap = Self{ .map = _tempMap.into(anyopaque, anyopaque) };
        defer tagMap.deinit();
        try OffsetContainer.appendTagged(&tagMap, &offsets);

        var offsetsSet = std.AutoHashMap(usize, void).init(std.testing.allocator);
        defer offsetsSet.deinit();

        for (offsets.items) |offset| {
            try offsetsSet.put(offset.offset, {});
            if (offsetsSet.count() > 1) {
                std.debug.print("Found inconsistent tagged union value offset for tag {s}\n", .{@tagName(offset.tag)});
                return error.SkipZigTest;
            }
        }
    }

    test value {
        const val = Self{ .bool = true };
        try std.testing.expect(val.tag() == .bool);
        try std.testing.expect(val.value().boolean == true);
    }
};

/// Creates a temporary instance of `CTaggedValue` that uses the same memory.
/// The temporary instance mustn't be deinitialized. It only exists for interop.
pub fn zigToCTaggedValueTemp(val: TaggedValue) CTaggedValue {
    return CTaggedValue{ .value = val.value().*, .tag = val.tag() };
}

pub fn validateTypeMatchesTag(comptime T: type, tag: ValueTag) void {
    const assert = std.debug.assert;
    if (std.debug.runtime_safety) {
        if (T == bool) {
            assert(tag == .bool);
        } else if (T == i64) {
            assert(tag == .int);
        } else if (T == f64) {
            assert(tag == .float);
        } else {
            assert(tag == T.SCRIPT_SELF_TAG);
        }
    }
}

pub fn scriptTypeToTag(comptime T: type) ValueTag {
    if (T == bool) {
        return .bool;
    } else if (T == i64) {
        return .int;
    } else if (T == f64) {
        return .float;
    } else {
        return T.SCRIPT_SELF_TAG;
    }
}
