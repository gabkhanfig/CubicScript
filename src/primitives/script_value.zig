const std = @import("std");
const expect = std.testing.expect;
const primitive_context = @cImport({
    @cInclude("primitives/context.h");
});

pub const String = @import("string/string.zig").String;
pub const Array = @import("array/array.zig").Array;
pub const Set = @import("set/set.zig").Set;
pub const Map = @import("map/map.zig").Map;
pub const Option = @import("option/option.zig").Option;
pub const Error = @import("error/error.zig").Error;
pub const Result = @import("result/result.zig").Result;
pub const Unique = @import("sync_ptr/sync_ptr.zig").Unique;
pub const Shared = @import("sync_ptr/sync_ptr.zig").Shared;
pub const Weak = @import("sync_ptr/sync_ptr.zig").Weak;
pub const Function = @import("function/function.zig").Function;
pub const Vec2i = @import("vector/vector.zig").Vec2i;
pub const Vec3i = @import("vector/vector.zig").Vec3i;
pub const Vec4i = @import("vector/vector.zig").Vec4i;
pub const Vec2f = @import("vector/vector.zig").Vec2f;
pub const Vec3f = @import("vector/vector.zig").Vec3f;
pub const Vec4f = @import("vector/vector.zig").Vec4f;

pub const c = struct {
    pub const CubsString = @import("string/string.zig").CubsString;
    pub const CubsArray = @import("array/array.zig").CubsArray;
    pub const CubsSet = @import("set/set.zig").CubsSet;
    pub const CubsMap = @import("map/map.zig").CubsMap;
    pub const CubsOption = @import("option/option.zig").CubsOption;
    pub const CubsError = @import("error/error.zig").CubsError;
    pub const CubsResult = @import("result/result.zig").CubsResult;
    pub const CubsUnique = @import("sync_ptr/sync_ptr.zig").CubsUnique;
    pub const CubsShared = @import("sync_ptr/sync_ptr.zig").CubsShared;
    pub const CubsWeak = @import("sync_ptr/sync_ptr.zig").CubsWeak;
    pub const CubsFunction = @import("function/function.zig").CubsFunction;
    pub const CubsCFunctionPtr = @import("function/function.zig").CubsCFunctionPtr;
    pub const CubsFunctionPtr = @import("function/function.zig").CubsFunctionPtr;
    pub const CubsFunctionType = @import("function/function.zig").CubsFunctionType;
    pub const CubsFunctionCallArgs = @import("function/function.zig").CubsFunctionCallArgs;
    pub const CubsFunctionReturn = @import("function/function.zig").CubsFunctionReturn;
    pub const CubsCFunctionHandler = @import("function/function.zig").CubsCFunctionHandler;
};

// pub const ValueTag = enum(c_int) {
//     bool = 1,
//     int = 2,
//     float = 3,
//     char = 4,
//     string = 5,
//     stringIter = 6,
//     array = 7,
//     arrayConstIter = 8,
//     arrayMutIter = 9,
//     set = 10,
//     setIter = 11,
//     map = 12,
//     mapConstIter = 13,
//     mapMutIter = 14,
//     option = 15,
//     err = 16,
//     result = 17,
//     taggedUnion = 18,
//     userClass = 19,
//     ownedInterface = 20,
//     interfaceRef = 21,
//     constRef = 22,
//     mutRef = 23,
//     unique = 24,
//     shared = 25,
//     weak = 26,
//     functionPtr = 27,
//     future = 28,
//     vec2i = 29,
//     vec3i = 30,
//     vec4i = 31,
//     vec2f = 32,
//     vec3f = 33,
//     vec4f = 34,
//     mat3f = 35,
//     mat4f = 36,
// };

/// Corresponds with CubsTypeContext in C
pub const TypeContext = extern struct {
    /// Corresponds with CubsTypeMemberContext in C
    pub const Member = extern struct {
        byteOffset: usize,
        name: c.CubsString.CubsStringSlice,
        context: *const TypeContext,
    };

    sizeOfType: usize,
    onDeinit: c.CubsFunction = std.mem.zeroes(c.CubsFunction),
    clone: c.CubsFunction = std.mem.zeroes(c.CubsFunction),
    eql: c.CubsFunction = std.mem.zeroes(c.CubsFunction),
    hash: c.CubsFunction = std.mem.zeroes(c.CubsFunction),
    name: [*c]const u8,
    nameLength: usize,
    members: [*c]const Member,
    memberLen: usize,

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
        } else if (T == String or T == c.CubsString) {
            return @ptrCast(&primitive_context.CUBS_STRING_CONTEXT);
        } else if (T == c.CubsArray) {
            return @ptrCast(&primitive_context.CUBS_ARRAY_CONTEXT);
        } else if (T == c.CubsSet) {
            return @ptrCast(&primitive_context.CUBS_SET_CONTEXT);
        } else if (T == c.CubsMap) {
            return @ptrCast(&primitive_context.CUBS_MAP_CONTEXT);
        } else if (T == c.CubsOption) {
            return @ptrCast(&primitive_context.CUBS_OPTION_CONTEXT);
        } else if (T == c.CubsError) {
            return @ptrCast(&primitive_context.CUBS_ERROR_CONTEXT);
        } else if (T == c.CubsResult) {
            return @ptrCast(&primitive_context.CUBS_RESULT_CONTEXT);
        } else if (T == c.CubsUnique) {
            return @ptrCast(&primitive_context.CUBS_UNIQUE_CONTEXT);
        } else if (T == c.CubsShared) {
            return @ptrCast(&primitive_context.CUBS_SHARED_CONTEXT);
        } else if (T == c.CubsWeak) {
            return @ptrCast(&primitive_context.CUBS_WEAK_CONTEXT);
        } else if (@hasDecl(T, "ValueType")) {
            if (T == Array(T.ValueType)) {
                return @ptrCast(&primitive_context.CUBS_ARRAY_CONTEXT);
            } else if (T == Option(T.ValueType)) {
                return @ptrCast(&primitive_context.CUBS_OPTION_CONTEXT);
            } else if (T == Error(T.ValueType)) {
                return @ptrCast(&primitive_context.CUBS_ERROR_CONTEXT);
            } else if (T == Unique(T.ValueType)) {
                return @ptrCast(&primitive_context.CUBS_UNIQUE_CONTEXT);
            } else if (T == Shared(T.ValueType)) {
                return @ptrCast(&primitive_context.CUBS_SHARED_CONTEXT);
            } else if (T == Weak(T.ValueType)) {
                return @ptrCast(&primitive_context.CUBS_WEAK_CONTEXT);
            } else {
                if (@hasDecl(T, "ErrorMetadataType")) {
                    if (T == Result(T.ValueType, T.ErrorMetadataType)) {
                        return @ptrCast(&primitive_context.CUBS_RESULT_CONTEXT);
                    }
                } else if (@hasDecl(T, "KeyType")) {
                    if (T == Map(T.KeyType, T.ValueType)) {
                        return @ptrCast(&primitive_context.CUBS_MAP_CONTEXT);
                    }
                }
            }
        } else if (@hasDecl(T, "KeyType")) {
            if (T == Set(T.ValueType)) {
                return @ptrCast(&primitive_context.CUBS_SET_CONTEXT);
            }
        } else {
            const context = comptime generate(T);
            return &context;
        }
    }

    fn generate(comptime T: type) TypeContext {
        var context: TypeContext = undefined;
        context.sizeOfType = @sizeOf(T);

        context.onDeinit = std.mem.zeroes(c.CubsFunction);
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
            try expect(@intFromPtr(context.onDeinit.func.externC) == 0);
            try expect(std.mem.eql(u8, context.name[0..context.nameLength], "Example"));
        }
    }
};

// pub fn validateTypeMatchesTag(comptime T: type, tag: ValueTag) void {
//     const assert = std.debug.assert;
//     if (std.debug.runtime_safety) {
//         if (T == bool) {
//             assert(tag == .bool);
//         } else if (T == i64) {
//             assert(tag == .int);
//         } else if (T == f64) {
//             assert(tag == .float);
//         } else {
//             assert(tag == T.SCRIPT_SELF_TAG);
//         }
//     }
// }

// pub fn scriptTypeToTag(comptime T: type) ValueTag {
//     if (T == bool) {
//         return .bool;
//     } else if (T == i64) {
//         return .int;
//     } else if (T == f64) {
//         return .float;
//     } else if (T == String) {
//         return .string;
//     } else if (@hasDecl(T, "SCRIPT_SELF_TAG")) {
//         return T.SCRIPT_SELF_TAG;
//     } else {
//         return .userStruct;
//     }
// }
