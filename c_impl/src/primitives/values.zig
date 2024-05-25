const std = @import("std");

const c = struct {
    extern fn cubs_raw_value_deinit(self: *RawValue, tag: ValueTag) void;
    extern fn cubs_raw_value_clone(self: *const RawValue, tag: ValueTag) RawValue;
    extern fn cubs_raw_value_eql(self: *const RawValue, other: *const RawValue, tag: ValueTag) bool;

    extern fn cubs_tagged_value_deinit(self: *CTaggedValue) void;
    extern fn cubs_tagged_value_clone(self: *const RawValue) CTaggedValue;
    extern fn cubs_tagged_value_eql(self: *const CTaggedValue, other: *const CTaggedValue) bool;
};

const String = @import("string.zig").String;
const Array = @import("array.zig").Array;
const Map = @import("map.zig").Map;

pub const ValueTag = enum(c_int) {
    none = 0,
    bool = 1,
    int = 2,
    float = 3,
    string = 4,
    array = 5,
    set = 6,
    map = 7,
    option = 8,
    result = 9,
    class = 10,
    ownedInterface = 11,
    interfaceRef = 12,
    constRef = 13,
    mutRef = 14,
    unique = 15,
    shared = 16,
    weak = 17,
    functionPtr = 18,
    vec2i = 19,
    vec3i = 20,
    vec4i = 21,
    vec2f = 22,
    vec3f = 23,
    vec4f = 24,
    mat3f = 25,
    mat4f = 26,
};

pub const RawValue = extern union {
    boolean: bool,
    int: i64,
    float: f64,
    string: String,
    array: Array,
    map: Map,
    // set: Set,
    // option: Option,
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
    string: String,
    array: Array,
    set: void,
    map: Map,
    option: void,
    result: void,
    class: void,
    ownedInterface: void,
    interfaceRef: void,
    constRef: void,
    mutRef: void,
    unique: void,
    shared: void,
    weak: void,
    functionPtr: void,
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
            .none => |_| {},
            .int => |_| {},
            .bool => |_| {},
            .float => |_| {},
            .string => |*str| {
                str.deinit();
            },
            .array => |*a| {
                a.deinit();
            },
            .map => |*m| {
                m.deinit();
            },
            else => {},
        }
    }

    pub fn fromCRepr(consumeValue: *CTaggedValue) Self {
        const valueTag = consumeValue.tag;
        const raw = consumeValue.value;
        consumeValue.* = undefined;
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
            ValueTag.none => |*vv| {
                return @ptrCast(@alignCast(vv));
            },
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

        var tagNone = Self{ .none = {} };
        defer tagNone.deinit();
        try OffsetContainer.appendTagged(&tagNone, &offsets);

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
