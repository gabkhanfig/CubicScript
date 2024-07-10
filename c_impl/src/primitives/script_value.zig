const std = @import("std");
const expect = std.testing.expect;
const primitive_context = @cImport({
    @cInclude("primitives/primitives_context.h");
});

pub const String = @import("string/string.zig").String;
pub const Array = @import("array/array.zig").Array;
pub const Set = @import("set/set.zig").Set;
pub const Map = @import("map/map.zig").Map;
pub const Option = @import("option/option.zig").Option;
pub const Error = @import("error/error.zig").Error;
pub const Result = @import("result/result.zig").Result;
pub const Vec2i = @import("vector/vector.zig").Vec2i;
pub const Vec3i = @import("vector/vector.zig").Vec3i;
pub const Vec4i = @import("vector/vector.zig").Vec4i;
pub const Vec2f = @import("vector/vector.zig").Vec2f;
pub const Vec3f = @import("vector/vector.zig").Vec3f;
pub const Vec4f = @import("vector/vector.zig").Vec4f;

pub const CubsError = @import("error/error.zig").CubsError;

pub const ValueTag = enum(c_int) {
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
    userClass = 19,
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
    userStruct = 37,
    structRtti = 38,
};

pub const TypeContext = extern struct {
    sizeOfType: usize,
    powOf8Size: usize,
    tag: ValueTag,
    onDeinit: ?*const fn (self: *anyopaque) callconv(.C) void = null,
    clone: ?*const fn (dst: *anyopaque, self: *const anyopaque) callconv(.C) void = null,
    eql: ?*const fn (self: *const anyopaque, other: *const anyopaque) callconv(.C) bool = null,
    hash: ?*const fn (self: *const anyopaque) callconv(.C) usize = null,
    name: [*c]const u8,
    nameLength: usize,

    /// Automatically generate a struct context for script use
    pub fn auto(comptime T: type) *const TypeContext {
        if (T == void) {
            @compileError("Cannot generate TypeContext for void");
        }

        if (T == bool) {
            return @ptrCast(&primitive_context.CUBS_BOOL_CONTEXT);
        } else if (T == i64) {
            return @ptrCast(&primitive_context.CUBS_INT_CONTEXT);
        } else if (T == f64) {
            return @ptrCast(&primitive_context.CUBS_FLOAT_CONTEXT);
        } else if (T == String) {
            return @ptrCast(&primitive_context.CUBS_STRING_CONTEXT);
        }
        // if (@hasDecl(T, "SCRIPT_SELF_TAG")) {
        // comptime {
        //     const tag: ValueTag = T.SCRIPT_SELF_TAG;
        //     switch (tag) {
        //         else => {
        //             @compileError("Unsupported primitive context type");
        //         },
        //     }
        // }
        // } else {
        const context = comptime generate(T);
        return &context;
        // }
    }

    fn generate(comptime T: type) TypeContext {
        var context: TypeContext = undefined;
        context.sizeOfType = @sizeOf(T);
        context.powOf8Size = blk: {
            if (@sizeOf(T) & 7 != 0) {
                break :blk @sizeOf(T) + (@sizeOf(usize) - @mod(@sizeOf(T), @sizeOf(usize)));
            } else {
                break :blk @sizeOf(T);
            }
        };
        context.tag = .userStruct;

        context.onDeinit = null;
        if (std.meta.hasFn(T, "deinit")) {
            context.onDeinit = @ptrCast(&T.deinit);
        }

        const name = unqualifiedTypeName(T);
        context.name = name.ptr;
        context.nameLength = name.len;

        return context;
    }

    fn unqualifiedTypeName(comptime T: type) []const u8 {
        const fullyQualifiedName = @typeName(T);

        var unqualifiedName: []const u8 = fullyQualifiedName;
        if (std.mem.lastIndexOf(u8, fullyQualifiedName, ".")) |i| {
            unqualifiedName = fullyQualifiedName[(i + 1)..];
        }
        return unqualifiedName;
    }

    test auto {
        { // primitives
            const ValidatePrimitiveAuto = struct {
                fn validate(comptime T: type, context: *const primitive_context.CubsTypeContext) !void {
                    try expect(@intFromPtr(TypeContext.auto(T)) == @intFromPtr(context));
                }
            };
            const validate = ValidatePrimitiveAuto.validate;

            try validate(bool, &primitive_context.CUBS_BOOL_CONTEXT);
            try validate(i64, &primitive_context.CUBS_INT_CONTEXT);
            try validate(f64, &primitive_context.CUBS_FLOAT_CONTEXT);
            try validate(String, &primitive_context.CUBS_STRING_CONTEXT);
        }
        { // plain struct
            const Example = extern struct {
                num: i64,
            };
            const context = auto(Example);
            try expect(context.sizeOfType == @sizeOf(Example));
            try expect(context.tag == .userStruct);
            try expect(context.onDeinit == null);
            try expect(std.mem.eql(u8, context.name[0..context.nameLength], "Example"));
        }
    }
};

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
    } else if (T == String) {
        return .string;
    } else if (@hasDecl(T, "SCRIPT_SELF_TAG")) {
        return T.SCRIPT_SELF_TAG;
    } else {
        return .userStruct;
    }
}
