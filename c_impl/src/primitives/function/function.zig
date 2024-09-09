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

    pub fn initC(func: CFunctionPtr) Self {
        return c.cubs_function_init_c(func);
    }

    pub fn startCall(self: *const Self) FunctionCallArgs {
        return c.cubs_function_start_call(self);
    }

    pub const CFunctionPtr = *const fn (CFunctionHandler) callconv(.C) c_int;

    pub const c = struct {
        pub extern fn cubs_function_init_c(func: CFunctionPtr) Self;
        pub extern fn cubs_function_start_call(self: *const Self) FunctionCallArgs;
    };

    pub const FunctionPtrType = enum(c_int) {
        C = 0,
        Script = 1,
    };

    test initC {
        const Example = struct {
            fn example(_: CFunctionHandler) callconv(.C) c_int {
                return 0;
            }
        };

        const f = Self.initC(&Example.example);
        _ = f;
    }

    test startCall {
        const Example = struct {
            fn example(_: CFunctionHandler) callconv(.C) c_int {
                return 0;
            }
        };

        const f = Self.initC(&Example.example);
        const a = f.startCall();
        _ = a;
    }
};

pub const FunctionCallArgs = extern struct {
    const Self = @This();

    func: *const Function,
    _inner: [2]c_int,

    pub const c = struct {
        pub extern fn cubs_function_push_arg(self: *Self, arg: *anyopaque, typeContext: *const TypeContext) callconv(.C) void;
        pub extern fn cubs_function_call(self: Self, outReturn: FunctionReturn) callconv(.C) c_int;
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
        pub extern fn cubs_function_take_arg(self: *const Self, argIndex: usize, outArg: *anyopaque, outContext: ?**const TypeContext) callconv(.C) void;
        pub extern fn cubs_function_return_set_value(self: Self, returnValue: *anyopaque, returnContext: *const TypeContext) callconv(.C) void;
    };
};

test "call C function" {
    const Example = struct {
        fn example(_: CFunctionHandler) callconv(.C) c_int {
            return 0;
        }
    };

    const f = Function.initC(&Example.example);
    const a = f.startCall();
    try expect(FunctionCallArgs.c.cubs_function_call(a, std.mem.zeroes(FunctionReturn)) == 0);
}

test "push C arg" {
    const Example = struct {
        fn example(_: CFunctionHandler) callconv(.C) c_int {
            return 0;
        }
    };

    const f = Function.initC(&Example.example);
    var a = f.startCall();

    var num: i64 = 5;

    FunctionCallArgs.c.cubs_function_push_arg(&a, @ptrCast(&num), TypeContext.auto(i64));
    try expect(FunctionCallArgs.c.cubs_function_call(a, std.mem.zeroes(FunctionReturn)) == 0);
}

test "take C arg" {
    const Example = struct {
        fn example(args: CFunctionHandler) callconv(.C) c_int {
            var num: i64 = undefined;
            var context: *const TypeContext = undefined;
            CFunctionHandler.c.cubs_function_take_arg(&args, 0, @ptrCast(&num), &context);
            expect(num == 5) catch {
                std.debug.print("Test fail. Expected C function argument to be 5", .{});
            };
            return 0;
        }
    };

    const f = Function.initC(&Example.example);
    var a = f.startCall();

    var num: i64 = 5;

    FunctionCallArgs.c.cubs_function_push_arg(&a, @ptrCast(&num), TypeContext.auto(i64));
    try expect(FunctionCallArgs.c.cubs_function_call(a, std.mem.zeroes(FunctionReturn)) == 0);
}

test "multiple arguments" {
    const Example = struct {
        fn example(args: CFunctionHandler) callconv(.C) c_int {
            var arg0: String = undefined;
            var context0: *const TypeContext = undefined;
            var arg1: i64 = undefined;
            var context1: *const TypeContext = undefined;
            var arg2: String = undefined;
            var context2: *const TypeContext = undefined;

            CFunctionHandler.c.cubs_function_take_arg(&args, 0, @ptrCast(&arg0), &context0);
            expect(context0 == TypeContext.auto(String)) catch {
                std.debug.print("Expected argument 0 to be string context", .{});
            };
            expect(arg0.eqlSlice("hello world!")) catch {
                std.debug.print("Test fail. Expected first C function argument to be \"hello world!\"", .{});
            };

            arg0.deinit();

            CFunctionHandler.c.cubs_function_take_arg(&args, 1, @ptrCast(&arg1), &context1);
            expect(context0 == TypeContext.auto(i64)) catch {
                std.debug.print("Expected argument 1 to be string context", .{});
            };
            expect(arg1 == 10) catch {
                std.debug.print("Test fail. Expected second C function argument to be 10", .{});
            };

            CFunctionHandler.c.cubs_function_take_arg(&args, 2, @ptrCast(&arg2), &context2);
            expect(context2 == TypeContext.auto(String)) catch {
                std.debug.print("Expected argument 2 to be string context", .{});
            };
            expect(arg0.eqlSlice("hello world!")) catch {
                std.debug.print("Test fail. Expected first C function argument to be \"well hello to this truly glorious world!\"", .{});
            };

            arg2.deinit();

            return 0;
        }
    };

    const f = Function.initC(&Example.example);
    var a = f.startCall();

    var a0 = String.initUnchecked("hello world!");
    var a1: i64 = 10;
    var a2 = String.initUnchecked("well hello to this truly glorious world!");

    FunctionCallArgs.c.cubs_function_push_arg(&a, @ptrCast(&a0), TypeContext.auto(String));
    FunctionCallArgs.c.cubs_function_push_arg(&a, @ptrCast(&a1), TypeContext.auto(i64));
    FunctionCallArgs.c.cubs_function_push_arg(&a, @ptrCast(&a2), TypeContext.auto(String));
    try expect(FunctionCallArgs.c.cubs_function_call(a, std.mem.zeroes(FunctionReturn)) == 0);
}
