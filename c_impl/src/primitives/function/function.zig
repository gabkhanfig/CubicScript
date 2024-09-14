const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const script_value = @import("../script_value.zig");
const String = script_value.String;
const TypeContext = script_value.TypeContext;
const Program = @import("../../program/program.zig").Program;

pub const CubsFunction = extern struct {
    const Self = @This();

    /// If is null, function cannot be called
    func: CubsFunctionPtr = std.mem.zeroes(CubsFunctionPtr),
    funcType: CubsFunctionType = std.mem.zeroes(CubsFunctionType),

    pub extern fn cubs_function_init_c(func: CubsCFunctionPtr) Self;
    pub extern fn cubs_function_start_call(self: *const Self) CubsFunctionCallArgs;
};

pub const CubsCFunctionPtr = *const fn (CubsCFunctionHandler) callconv(.C) c_int;

pub const CubsFunctionPtr = extern union { externC: CubsCFunctionPtr, script: *const anyopaque };

pub const CubsFunctionType = enum(c_int) {
    C = 0,
    Script = 1,
};

pub const CubsFunctionCallArgs = extern struct {
    const Self = @This();

    func: *const CubsFunction,
    _inner: [2]c_int,

    pub extern fn cubs_function_push_arg(self: *Self, arg: *anyopaque, typeContext: *const TypeContext) callconv(.C) void;
    pub extern fn cubs_function_call(self: Self, outReturn: CubsFunctionReturn) callconv(.C) c_int;
};

/// If `value != null`, `context` must not equal `null`.
pub const CubsFunctionReturn = extern struct {
    value: ?*anyopaque,
    context: ?**const TypeContext,
};

pub const CubsCFunctionHandler = extern struct {
    const Self = @This();

    //program: *const Program,
    _frameBaseOffset: usize,
    _offsetForArgs: c_int,
    argCount: c_int,
    outReturn: CubsFunctionReturn,

    pub extern fn cubs_function_take_arg(self: *const Self, argIndex: usize, outArg: *anyopaque, outContext: ?**const TypeContext) callconv(.C) void;
    pub extern fn cubs_function_return_set_value(self: Self, returnValue: *anyopaque, returnContext: *const TypeContext) callconv(.C) void;
};

test "call C function" {
    const Example = struct {
        fn example(_: CubsCFunctionHandler) callconv(.C) c_int {
            return 0;
        }
    };

    const f = CubsFunction.cubs_function_init_c(&Example.example);
    const a = CubsFunction.cubs_function_start_call(&f);
    try expect(CubsFunctionCallArgs.cubs_function_call(a, std.mem.zeroes(CubsFunctionReturn)) == 0);
}

test "push C arg" {
    const Example = struct {
        fn example(_: CubsCFunctionHandler) callconv(.C) c_int {
            return 0;
        }
    };

    const f = CubsFunction.cubs_function_init_c(&Example.example);
    var a = CubsFunction.cubs_function_start_call(&f);

    var num: i64 = 5;

    CubsFunctionCallArgs.cubs_function_push_arg(&a, @ptrCast(&num), TypeContext.auto(i64));
    try expect(CubsFunctionCallArgs.cubs_function_call(a, std.mem.zeroes(CubsFunctionReturn)) == 0);
}

test "take C arg" {
    const Example = struct {
        fn example(args: CubsCFunctionHandler) callconv(.C) c_int {
            var num: i64 = undefined;
            var context: *const TypeContext = undefined;
            CubsCFunctionHandler.cubs_function_take_arg(&args, 0, @ptrCast(&num), &context);
            expect(num == 5) catch {
                std.debug.print("Test fail. Expected C function argument to be 5", .{});
            };
            return 0;
        }
    };

    const f = CubsFunction.cubs_function_init_c(&Example.example);
    var a = CubsFunction.cubs_function_start_call(&f);

    var num: i64 = 5;

    CubsFunctionCallArgs.cubs_function_push_arg(&a, @ptrCast(&num), TypeContext.auto(i64));
    try expect(CubsFunctionCallArgs.cubs_function_call(a, std.mem.zeroes(CubsFunctionReturn)) == 0);
}

test "multiple arguments" {
    const Example = struct {
        fn example(args: CubsCFunctionHandler) callconv(.C) c_int {
            var arg0: String = undefined;
            var context0: *const TypeContext = undefined;
            var arg1: i64 = undefined;
            var context1: *const TypeContext = undefined;
            var arg2: String = undefined;
            var context2: *const TypeContext = undefined;

            CubsCFunctionHandler.cubs_function_take_arg(&args, 0, @ptrCast(&arg0), &context0);
            assert(context0 == TypeContext.auto(String));
            assert(arg0.eqlSlice("hello world!"));

            arg0.deinit();

            CubsCFunctionHandler.cubs_function_take_arg(&args, 1, @ptrCast(&arg1), &context1);
            assert(context1 == TypeContext.auto(i64));
            assert(arg1 == 10);

            CubsCFunctionHandler.cubs_function_take_arg(&args, 2, @ptrCast(&arg2), &context2);
            assert(context2 == TypeContext.auto(String));
            assert(arg0.eqlSlice("hello world!"));

            arg2.deinit();

            return 0;
        }
    };

    const f = CubsFunction.cubs_function_init_c(&Example.example);
    var a = CubsFunction.cubs_function_start_call(&f);

    var a0 = String.initUnchecked("hello world!");
    var a1: i64 = 10;
    var a2 = String.initUnchecked("well hello to this truly glorious world!");

    CubsFunctionCallArgs.cubs_function_push_arg(&a, @ptrCast(&a0), TypeContext.auto(String));
    CubsFunctionCallArgs.cubs_function_push_arg(&a, @ptrCast(&a1), TypeContext.auto(i64));
    CubsFunctionCallArgs.cubs_function_push_arg(&a, @ptrCast(&a2), TypeContext.auto(String));
    try expect(CubsFunctionCallArgs.cubs_function_call(a, std.mem.zeroes(CubsFunctionReturn)) == 0);
}

test "return" {
    const Example = struct {
        fn example(args: CubsCFunctionHandler) callconv(.C) c_int {
            var out: i64 = 10;
            const context: *const TypeContext = TypeContext.auto(i64);
            CubsCFunctionHandler.cubs_function_return_set_value(args, @ptrCast(&out), context);
            return 0;
        }
    };

    const f = CubsFunction.cubs_function_init_c(&Example.example);
    const a = CubsFunction.cubs_function_start_call(&f);

    var num: i64 = undefined;
    var cxt: *const TypeContext = undefined;

    try expect(CubsFunctionCallArgs.cubs_function_call(a, .{ .value = @ptrCast(&num), .context = &cxt }) == 0);
    try expect(num == 10);
    try expect(cxt == TypeContext.auto(i64));
}

// pub const Function = extern struct {
//     const Self = @This();

//     pub fn initC(func: CFunctionPtr) Self {
//         return c.cubs_function_init_c(func);
//     }

//     pub fn startCall(self: *const Self) FunctionCallArgs {
//         return c.cubs_function_start_call(self);
//     }

//     /// Same as union `CubsFunctionPtr` in `function.h`
//     pub const Ptr = extern union {};

//     pub const c = struct {};

//     test initC {
//         const Example = struct {
//             fn example(_: CFunctionHandler) callconv(.C) c_int {
//                 return 0;
//             }
//         };

//         const f = Self.initC(&Example.example);
//         _ = f;
//     }

//     test startCall {
//         const Example = struct {
//             fn example(_: CFunctionHandler) callconv(.C) c_int {
//                 return 0;
//             }
//         };

//         const f = Self.initC(&Example.example);
//         const a = f.startCall();
//         _ = a;
//     }
// };

// pub const FunctionCallArgs = extern struct {
//     const Self = @This();

//     func: *const Function,
//     _inner: [2]c_int,

//     pub fn pushArg(self: *Self, arg: anytype) void {
//         const argType = @TypeOf(arg);
//         const typeInfo = @typeInfo(argType);
//         if (typeInfo == .Pointer) {
//             @compileError("Passing pointer types not yet implemented");
//         }

//         var mutArg: argType = arg;
//         const context = TypeContext.auto(argType);
//         c.cubs_function_push_arg(self, @ptrCast(&mutArg), context);
//     }

//     pub fn call(self: Self, comptime RetT: type) !if (RetT == void) void else struct { value: RetT, context: *const TypeContext } {
//         const typeInfo = @typeInfo(RetT);
//         if (typeInfo == .Pointer) {
//             @compileError("Returning pointer types not yet implemented");
//         }

//         if (RetT == void) {
//             const result = c.cubs_function_call(self, std.mem.zeroes(FunctionReturn));
//             if (result == 0) {
//                 return;
//             } else {
//                 return error.Unknown;
//             }
//         } else {
//             var outValue: RetT = undefined;
//             var outContext: *const TypeContext = undefined;
//             const result = c.cubs_function_call(self, .{ .value = @ptrCast(&outValue), .context = &outContext });
//             if (result == 0) {
//                 return .{ .value = outValue, .context = outContext };
//             } else {
//                 return error.Unknown;
//             }
//         }
//     }

//     pub const c = struct {};

//     test "pushArg and call" {
//         {
//             const Example = struct {
//                 fn example(_: CFunctionHandler) callconv(.C) c_int {
//                     return 0;
//                 }
//             };

//             const f = Function.initC(&Example.example);
//             var a = f.startCall();

//             a.pushArg(@as(i64, 10));
//             try a.call(void);
//         }
//     }
// };
