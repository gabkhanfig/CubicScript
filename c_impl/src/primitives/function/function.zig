const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const script_value = @import("../script_value.zig");
const String = script_value.String;
const TypeContext = script_value.TypeContext;
const Program = @import("../../program/program.zig").Program;

pub const Function = extern struct {
    const Self = @This();

    _inner: *const anyopaque,
    funcType: FunctionPtrType,

    pub const CFunctionPtr = *const fn (CFunctionHandler) c_int;

    pub const c = struct {
        pub extern fn cubs_function_init_c(func: CFunctionPtr) Self;
        pub extern fn cubs_function_start_call(self: *const Self) FunctionCallArgs;
    };

    pub const FunctionPtrType = enum(c_int) {
        C = 0,
        Script = 1,
    };
};

pub const FunctionCallArgs = extern struct {
    const Self = @This();

    func: *const Function,
    _inner: [2]c_int,

    pub const c = struct {
        pub extern fn cubs_function_push_arg(self: *Self, arg: *anyopaque, typeContext: *const TypeContext) callconv(.C) void;
        pub extern fn cubs_function_call(self: Self, program: *const Program, outReturn: FunctionReturn) callconv(.C) void;
    };
};

pub const FunctionReturn = extern struct {
    value: *anyopaque,
    context: **const TypeContext,
};

pub const CFunctionHandler = extern struct {
    const Self = @This();

    program: *const Program,
    _frameBaseOffset: usize,
    _offsetForArgs: c_int,
    argCount: c_int,
    outReturn: FunctionReturn,

    pub const c = struct {
        pub extern fn cubs_function_take_arg(self: Self, argIndex: usize, outArg: *anyopaque, outContext: **const TypeContext) callconv(.C) void;
        pub extern fn cubs_function_return_set_value(self: *const Self, returnValue: *anyopaque, returnContext: *const TypeContext) callconv(.C) void;
    };
};
