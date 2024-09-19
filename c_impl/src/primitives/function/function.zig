const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const script_value = @import("../script_value.zig");
const String = script_value.String;
const TypeContext = script_value.TypeContext;
const Program = @import("../../program/program.zig").Program;

pub fn Function(comptime RetT: type, comptime argsT: anytype) type {
    return extern struct {
        comptime {
            const ArgsType = @TypeOf(argsT);
            const argsTypeInfo = @typeInfo(ArgsType);
            if (argsTypeInfo != .Struct) {
                @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
            }

            const fieldsInfo = argsTypeInfo.Struct.fields;
            for (fieldsInfo) |field| {
                if (field.type != type) {
                    @compileError("expected variadic argument of types");
                }
            }
        }

        const Self = @This();

        /// If is null, function cannot be called
        func: CubsFunctionPtr = std.mem.zeroes(CubsFunctionPtr),
        funcType: CubsFunctionType = std.mem.zeroes(CubsFunctionType),

        /// Automatically generates the necessary code to extract all arguments
        pub fn init(comptime func: anytype) Self {
            const fInfo = blk: {
                const funcType = @TypeOf(func);
                const funcInfo = @typeInfo(funcType);
                if (funcInfo != .Fn) {
                    @compileError("expected function argument, found " ++ @typeName(funcType));
                }
                break :blk funcInfo.Fn;
            };

            { // return validation
                if (fInfo.return_type) |return_type| {
                    if (return_type != void and RetT == void) {
                        @compileError("function has return value, but no return value expected");
                    }
                    if (return_type != RetT) {
                        @compileError("expected function with return type of " ++ @typeName(RetT) ++ ", found " ++ @typeName(return_type));
                    }
                } else {
                    if (RetT != void) {
                        @compileError("function has no return value, but return value of " ++ @typeName(RetT) ++ " expected");
                    }
                }
            }
            { // argument validation
                const ArgsType = @TypeOf(argsT);
                const argsTypeInfo = @typeInfo(ArgsType);
                const fieldsInfo = argsTypeInfo.Struct.fields;
                if (fieldsInfo.len != fInfo.params.len) {
                    @compileError("function takes different number of arguments than expected");
                }

                inline for (fInfo.params, 0..) |param, i| {
                    if (param.type) |t| {
                        if (t != argsT[i]) {
                            @compileError("expected arugment type to be " ++ @typeName(argsT[i]) ++ ", found " ++ @typeName(t));
                        }
                    } else {
                        @compileError("CubicScript does not support void arguments");
                    }
                }
            }

            const Generated = struct {
                fn fun(handler: CubsCFunctionHandler) callconv(.C) c_int {
                    comptime var argsTypes: [fInfo.params.len]type = undefined;
                    inline for (fInfo.params, 0..) |param, i| {
                        argsTypes[i] = param.type.?;
                    }

                    var args: std.meta.Tuple(&argsTypes) = undefined;
                    inline for (fInfo.params, 0..) |param, i| {
                        var ctx: *const TypeContext = undefined;
                        handler.cubs_function_take_arg(i, @ptrCast(&args[i]), &ctx);
                        if (std.debug.runtime_safety) {
                            if (ctx != TypeContext.auto(param.type.?)) {
                                const message = std.fmt.allocPrint(
                                    std.heap.c_allocator,
                                    "script type mismatch. {s} != {s}",
                                    .{ ctx.name, TypeContext.auto(param.type.?).name },
                                ) catch unreachable;
                                @panic(message);
                            }
                        }
                    }

                    var ret: RetT = @call(.auto, func, args);
                    if (RetT != void) {
                        handler.cubs_function_return_set_value(@ptrCast(&ret), TypeContext.auto(RetT));
                    }

                    return 0;
                }
            };

            return Self.initC(&Generated.fun);
        }

        pub fn initC(func: CubsCFunctionPtr) Self {
            return Self{ .func = .{ .externC = func }, .funcType = .C };
        }

        // TODO convert comptime_int to i64, and comptime_float to f64
        pub fn call(self: *const Self, args: anytype) !RetT {
            const ArgsType = @TypeOf(args);
            const argsInfo = @typeInfo(ArgsType);
            if (argsInfo != .Struct) {
                @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
            }

            const argsTypeInfo = @typeInfo(@TypeOf(argsT));

            {
                const fieldsTypeInfo = argsTypeInfo.Struct.fields;
                const fieldsInfo = argsTypeInfo.Struct.fields;
                if (fieldsInfo.len != fieldsTypeInfo.len) {
                    @compileError("expected the same number of arguments for the function call as in the function definition");
                }

                comptime {
                    for (0..argsTypeInfo.Struct.fields.len) |fieldIndex| {
                        const fieldType = argsT[fieldIndex];
                        const definitionFieldType: type = argsT[fieldIndex];

                        if (fieldType != definitionFieldType) {
                            @compileError("expected type of " ++ @typeName(ArgsType) ++ " to match the definition arg type of " ++ @typeName(@TypeOf(argsT)));
                        }
                    }
                }
            }

            {
                var callArgs = self.asRaw().cubs_function_start_call();
                inline for (0..argsTypeInfo.Struct.fields.len) |i| {
                    var arg = args[i];
                    callArgs.cubs_function_push_arg(@ptrCast(&arg), TypeContext.auto(@TypeOf(args[i])));
                }

                const result = blk: {
                    if (RetT == void) {
                        const r = callArgs.cubs_function_call(std.mem.zeroes(CubsFunctionReturn));
                        if (r == 0) {
                            return;
                        } else {
                            break :blk r;
                        }
                    } else {
                        var retVal: RetT = undefined;
                        var retContext: *const TypeContext = undefined;
                        const r = callArgs.cubs_function_call(.{ .value = @ptrCast(&retVal), .context = &retContext });
                        if (r == 0) {
                            return retVal;
                        } else {
                            break :blk r;
                        }
                    }
                };
                // result is non-zero here
                _ = result;
                return error.Unknown;
            }

            return undefined;
        }

        pub fn asRaw(self: *const Self) *const CubsFunction {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsFunction {
            return @ptrCast(self);
        }
    };
}

pub const CubsFunction = extern struct {
    const Self = @This();

    /// If is null, function cannot be called
    func: CubsFunctionPtr = std.mem.zeroes(CubsFunctionPtr),
    funcType: CubsFunctionType = std.mem.zeroes(CubsFunctionType),

    pub extern fn cubs_function_init_c(func: CubsCFunctionPtr) Self;
    pub extern fn cubs_function_start_call(self: *const Self) CubsFunctionCallArgs;
};

pub const CubsCFunctionPtr = *const fn (CubsCFunctionHandler) callconv(.C) c_int;

pub const CubsScriptFunctionPtr = extern struct {
    program: *const Program,
    fullyQualifiedName: String,
    name: String,
    /// If NULL, the function does not return any value
    returnType: ?*const TypeContext,
    /// If NULL, the function take no arguments, otherwise valid when `i < argsLen`.
    argsTypes: ?[*]*const TypeContext,
    /// If zero, the function take no arguments
    argsLen: usize,
    _stackSpaceRequired: usize,
    _bytecodeCount: usize,
};

pub const CubsFunctionPtr = extern union { externC: CubsCFunctionPtr, script: *const CubsScriptFunctionPtr };

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

test "ziggy C function many args no return" {
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

    const f = Function(void, .{ String, i64, String }).initC(&Example.example);
    try f.call(.{
        String.initUnchecked("hello world!"),
        @as(i64, 10),
        String.initUnchecked("well hello to this truly glorious world!"),
    });
}

test "ziggy C function many args with return" {
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

            var ret = String.initUnchecked("this is the string that is being returned!");
            args.cubs_function_return_set_value(@ptrCast(&ret), TypeContext.auto(String));

            return 0;
        }
    };

    const f = Function(String, .{ String, i64, String }).initC(&Example.example);
    var s = try f.call(.{
        String.initUnchecked("hello world!"),
        @as(i64, 10),
        String.initUnchecked("well hello to this truly glorious world!"),
    });
    defer s.deinit();

    try expect(s.eqlSlice("this is the string that is being returned!"));
}

test "zig function many args no return" {
    const Example = struct {
        fn example(arg0: String, arg1: i64, arg2: String) void {
            assert(arg0.eqlSlice("hello world!"));
            assert(arg1 == 10);
            assert(arg2.eqlSlice("well hello to this truly glorious world!"));

            var mutA0 = arg0;
            mutA0.deinit();

            var mutA2 = arg2;
            mutA2.deinit();
        }
    };

    const f = Function(void, .{ String, i64, String }).init(Example.example);
    try f.call(.{
        String.initUnchecked("hello world!"),
        @as(i64, 10),
        String.initUnchecked("well hello to this truly glorious world!"),
    });
}

test "zig function many args and return" {
    const Example = struct {
        fn example(arg0: String, arg1: i64, arg2: String) String {
            assert(arg0.eqlSlice("hello world!"));
            assert(arg1 == 10);
            assert(arg2.eqlSlice("well hello to this truly glorious world!"));

            var mutA0 = arg0;
            mutA0.deinit();

            var mutA2 = arg2;
            mutA2.deinit();

            return String.initUnchecked("this is the string that is being returned!");
        }
    };

    const f = Function(String, .{ String, i64, String }).init(Example.example);
    var s = try f.call(.{
        String.initUnchecked("hello world!"),
        @as(i64, 10),
        String.initUnchecked("well hello to this truly glorious world!"),
    });
    defer s.deinit();

    try expect(s.eqlSlice("this is the string that is being returned!"));
}
