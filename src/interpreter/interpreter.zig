const std = @import("std");
const expect = std.testing.expect;
const Unique = @import("../primitives/sync_ptr/sync_ptr.zig").Unique;
const Shared = @import("../primitives/sync_ptr/sync_ptr.zig").Shared;
const Weak = @import("../primitives/sync_ptr/sync_ptr.zig").Weak;

const c = @cImport({
    @cInclude("interpreter/interpreter.h");
    @cInclude("interpreter/bytecode.h");
    @cInclude("interpreter/operations.h");
    @cInclude("interpreter/stack.h");
    @cInclude("primitives/context.h");
    @cInclude("primitives/string/string.h");
    @cInclude("primitives/array/array.h");
    @cInclude("primitives/set/set.h");
    @cInclude("primitives/map/map.h");
    @cInclude("program/program.h");
});

fn ScriptContextTestRuntimeError(comptime errTag: c.CubsProgramRuntimeError) type {
    return struct {
        fn init(shouldExpectError: bool) c.CubsProgramContext {
            const ptr = std.heap.c_allocator.create(@This()) catch unreachable;
            ptr.* = .{ .shouldExpectError = shouldExpectError };
            return c.CubsProgramContext{
                .ptr = @ptrCast(ptr),
                .vtable = &.{
                    .errorCallback = @ptrCast(&@This().errorCallback),
                    .deinit = @ptrCast(&@This().deinit),
                },
            };
        }

        fn deinit(self: *@This()) callconv(.C) void {
            if (self.shouldExpectError) {
                expect(self.didErrorHappen) catch {
                    const message = std.fmt.allocPrint(std.heap.c_allocator, "Expected an instance of CubsProgramRuntimeError error {}, found no error", .{errTag}) catch unreachable;
                    @panic(message);
                };
            } else {
                expect(!self.didErrorHappen) catch {
                    const message = std.fmt.allocPrint(std.heap.c_allocator, "Expected no CubsProgramRuntimeError error, instead found {}", .{errTag}) catch unreachable;
                    @panic(message);
                };
            }
            std.heap.c_allocator.destroy(self);
        }

        fn errorCallback(self: *@This(), _: *const c.CubsProgram, _: *anyopaque, err: c.CubsProgramRuntimeError, _: [*c]const u8, _: usize) void {
            if (err == errTag) {
                self.didErrorHappen = true;
            } else {
                @panic("unexpected error");
            }
        }

        shouldExpectError: bool,
        didErrorHappen: bool = false,
    };
}

test "nop" {
    c.cubs_interpreter_push_frame(1, null, null);
    defer c.cubs_interpreter_pop_frame();

    const bytecode = [_]c.Bytecode{
        c.cubs_bytecode_encode(c.OpCodeNop, null),
    };
    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    const result = c.cubs_interpreter_execute_operation(null);
    try expect(result == 0);
}

test "load immediate bool" {
    { // true
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_BOOL, 0, 1);

        c.cubs_interpreter_push_frame(1, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_BOOL_CONTEXT);
        try expect(@as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == true);
    }
    { // false
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_BOOL, 0, 0);

        c.cubs_interpreter_push_frame(1, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_BOOL_CONTEXT);
        try expect(@as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == false);
    }
}

test "load immediate int" {
    { // positive
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_INT, 0, 10);

        c.cubs_interpreter_push_frame(1, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
        try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 10);
    }
    { // negative
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_INT, 0, -10);

        c.cubs_interpreter_push_frame(1, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
        try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == -10);
    }
}

test "load immediate long" {
    { // int
        var bytecode = [2]c.Bytecode{ undefined, undefined };
        c.operands_make_load_immediate_long(@ptrCast(&bytecode), c.cubsValueTagInt, 0, @bitCast(@as(i64, -1234567890)));

        c.cubs_interpreter_push_frame(1, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
        try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == -1234567890);
    }
    { // float
        var bytecode = [2]c.Bytecode{ undefined, undefined };
        c.operands_make_load_immediate_long(@ptrCast(&bytecode), c.cubsValueTagFloat, 0, @bitCast(@as(f64, -0.123456789)));

        c.cubs_interpreter_push_frame(1, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_FLOAT_CONTEXT);
        try expect(@as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == -0.123456789);
    }
}

test "load default" {
    c.cubs_interpreter_push_frame(10, null, null);
    defer c.cubs_interpreter_pop_frame();
    { // bool
        var bytecode: c.Bytecode = undefined;
        c.operands_make_load_default(&bytecode, c.cubsValueTagBool, 0, null, null);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_BOOL_CONTEXT);
        try expect(@as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == false);
    }
    { // int
        var bytecode: c.Bytecode = undefined;
        c.operands_make_load_default(&bytecode, c.cubsValueTagInt, 0, null, null);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
        try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 0);
    }
    { // float
        var bytecode: c.Bytecode = undefined;
        c.operands_make_load_default(&bytecode, c.cubsValueTagFloat, 0, null, null);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_FLOAT_CONTEXT);
        try expect(@as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 0.0);
    }
    { // string
        var bytecode: c.Bytecode = undefined;
        c.operands_make_load_default(&bytecode, c.cubsValueTagString, 0, null, null);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_STRING_CONTEXT);
        const string: *c.CubsString = @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)));
        try expect(string.len == 0);
        try expect(c.cubs_string_eql_slice(string, c.CubsStringSlice{ .str = "".ptr, .len = "".len }));
    }
}

test "load clone" {
    c.cubs_interpreter_push_frame(10, null, null);
    defer c.cubs_interpreter_pop_frame();
    {
        var bytecode = [3]c.Bytecode{ undefined, undefined, undefined };

        var immediateString = c.cubs_string_init_unchecked(.{ .str = "hello world!".ptr, .len = "hello world!".len });
        defer c.cubs_string_deinit(&immediateString);

        c.operands_make_load_clone_from_ptr(&bytecode, 0, @ptrCast(&immediateString), &c.CUBS_STRING_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_STRING_CONTEXT);
        const stackString: *c.CubsString = @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)));
        try expect(stackString.len == "hello world!".len);
        try expect(c.cubs_string_eql(stackString, &immediateString));

        c.cubs_string_deinit(stackString);
    }
}

test "add dst int" {
    c.cubs_interpreter_push_frame(3, null, null);
    defer c.cubs_interpreter_pop_frame();

    var bytecode = c.operands_make_add_dst(false, 2, 0, 1);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = 2;
    c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* = 4;

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
    try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2)))).* == 6);
}

test "add assign int" {
    c.cubs_interpreter_push_frame(2, null, null);
    defer c.cubs_interpreter_pop_frame();

    var bytecode = c.operands_make_add_assign(false, 0, 1);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = 2;
    c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* = 4;

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
    try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 6);
}

test "add dst overflow" {
    c.cubs_interpreter_push_frame(3, null, null);
    defer c.cubs_interpreter_pop_frame();

    var context = ScriptContextTestRuntimeError(c.cubsProgramRuntimeErrorAdditionIntegerOverflow).init(true);

    var program = c.cubs_program_init(.{ .context = &context });
    defer c.cubs_program_deinit(&program);

    var bytecode = c.operands_make_add_dst(false, 2, 0, 1);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = std.math.maxInt(i64);
    c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* = 1;

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(&program) == c.cubsProgramRuntimeErrorAdditionIntegerOverflow);
}

test "add assign overflow" {
    c.cubs_interpreter_push_frame(2, null, null);
    defer c.cubs_interpreter_pop_frame();

    var context = ScriptContextTestRuntimeError(c.cubsProgramRuntimeErrorAdditionIntegerOverflow).init(true);

    var program = c.cubs_program_init(.{ .context = &context });
    defer c.cubs_program_deinit(&program);

    var bytecode = c.operands_make_add_assign(false, 0, 1);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = std.math.maxInt(i64);
    c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* = 1;

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(&program) == c.cubsProgramRuntimeErrorAdditionIntegerOverflow);
}

test "add dst float" {
    c.cubs_interpreter_push_frame(3, null, null);
    defer c.cubs_interpreter_pop_frame();

    var bytecode = c.operands_make_add_dst(false, 2, 0, 1);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_FLOAT_CONTEXT);
    @as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = 2.5;
    c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_FLOAT_CONTEXT);
    @as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* = 4.5;

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_FLOAT_CONTEXT);
    try expect(std.math.approxEqAbs(
        f64,
        @as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2)))).*,
        7.0,
        std.math.floatEps(f64),
    ));
}

test "add assign float" {
    c.cubs_interpreter_push_frame(2, null, null);
    defer c.cubs_interpreter_pop_frame();

    var bytecode = c.operands_make_add_assign(false, 0, 1);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_FLOAT_CONTEXT);
    @as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = 2.5;
    c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_FLOAT_CONTEXT);
    @as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* = 4.5;

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_FLOAT_CONTEXT);
    try expect(std.math.approxEqAbs(
        f64,
        @as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).*,
        7.0,
        std.math.floatEps(f64),
    ));
}

test "add dst string" {
    c.cubs_interpreter_push_frame(12, null, null);
    defer c.cubs_interpreter_pop_frame();

    const s1 = "hello? it is a pleasure to meet you.";
    const s2 = " And it is a pleasure to meet you as well!";
    const concat = s1 ++ s2;

    var bytecode = c.operands_make_add_dst(false, 8, 0, 4);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);
    @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = c.cubs_string_init_unchecked(.{ .str = s1.ptr, .len = s1.len });
    c.cubs_interpreter_stack_set_context_at(4, &c.CUBS_STRING_CONTEXT);
    @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4)))).* = c.cubs_string_init_unchecked(.{ .str = s2.ptr, .len = s2.len });

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(c.cubs_interpreter_stack_context_at(8) == &c.CUBS_STRING_CONTEXT);
    try expect(c.cubs_string_eql_slice(
        @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(8)))),
        .{ .str = concat.ptr, .len = concat.len },
    ));

    c.cubs_interpreter_stack_unwind_frame();
}

test "add assign string" {
    c.cubs_interpreter_push_frame(8, null, null);
    defer c.cubs_interpreter_pop_frame();

    const s1 = "hello? it is a pleasure to meet you.";
    const s2 = " And it is a pleasure to meet you as well!";
    const concat = s1 ++ s2;

    var bytecode = c.operands_make_add_assign(false, 0, 4);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);
    @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = c.cubs_string_init_unchecked(.{ .str = s1.ptr, .len = s1.len });
    c.cubs_interpreter_stack_set_context_at(4, &c.CUBS_STRING_CONTEXT);
    @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4)))).* = c.cubs_string_init_unchecked(.{ .str = s2.ptr, .len = s2.len });

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_STRING_CONTEXT);
    try expect(c.cubs_string_eql_slice(
        @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))),
        .{ .str = concat.ptr, .len = concat.len },
    ));

    c.cubs_interpreter_stack_unwind_frame();
}

test "return no value" {
    c.cubs_interpreter_push_frame(0, null, null);
    // explicitly dont pop frame, as return will

    var bytecode = c.operands_make_return(false, 0);

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);
}

test "return 1 stack-slot value" {
    var outValue: i64 = undefined;
    var outContext: *const c.CubsTypeContext = undefined;

    c.cubs_interpreter_push_frame(1, &outValue, @ptrCast(&outContext));
    // explicitly dont pop frame, as return will

    var bytecode = c.operands_make_return(true, 0);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = 10;

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(outValue == 10);
    try expect(outContext == &c.CUBS_INT_CONTEXT);
}

test "return multi stack-slot value" {
    var outValue: c.CubsString = undefined;
    defer c.cubs_string_deinit(&outValue);

    var outContext: *const c.CubsTypeContext = undefined;

    c.cubs_interpreter_push_frame(4, &outValue, @ptrCast(&outContext));
    // explicitly dont pop frame, as return will

    var bytecode = c.operands_make_return(true, 0);

    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);
    const s = "hello? it is a pleasure to meet you.";
    @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = c.cubs_string_init_unchecked(.{ .str = s.ptr, .len = s.len });

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(c.cubs_string_eql_slice(&outValue, .{ .str = s.ptr, .len = s.len }));
    try expect(outContext == &c.CUBS_STRING_CONTEXT);
}

test "call immediate C no args no return" {
    const Example = struct {
        var flag: bool = false;

        fn example(_: c.CubsCFunctionHandler) callconv(.C) c_int {
            flag = true;
            return 0;
        }
    };

    var bytecode: [2]c.Bytecode = undefined;
    c.cubs_operands_make_call_immediate(
        &bytecode,
        2,
        0,
        null,
        false,
        0,
        c.CubsFunction{ .func = .{ .externC = &Example.example }, .funcType = c.cubsFunctionPtrTypeC },
    );

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);
    try expect(Example.flag == true);
}

test "call immediate C one arg no return" {
    const Example = struct {
        var flag: bool = false;

        fn example(arg: c.CubsCFunctionHandler) callconv(.C) c_int {
            std.debug.assert(arg.argCount == 1);

            var num: i64 = undefined;
            var ctx: *const c.CubsTypeContext = undefined;

            c.cubs_function_take_arg(&arg, 0, @ptrCast(&num), @ptrCast(&ctx));
            std.debug.assert(num == 10);
            std.debug.assert(ctx == &c.CUBS_INT_CONTEXT);

            flag = true;
            return 0;
        }
    };

    c.cubs_interpreter_push_frame(1, null, null);
    defer c.cubs_interpreter_pop_frame();

    @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = 10;
    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);

    var bytecode: [3]c.Bytecode = undefined;
    c.cubs_operands_make_call_immediate(
        &bytecode,
        3,
        1,
        &[_]u16{0},
        false,
        0,
        c.CubsFunction{ .func = .{ .externC = &Example.example }, .funcType = c.cubsFunctionPtrTypeC },
    );

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);
    try expect(Example.flag == true);
}

test "call immediate C four args no return" {
    const Example = struct {
        var flag: bool = false;

        fn example(arg: c.CubsCFunctionHandler) callconv(.C) c_int {
            std.debug.assert(arg.argCount == 4);

            for (0..4) |i| {
                var num: i64 = undefined;
                var ctx: *const c.CubsTypeContext = undefined;

                c.cubs_function_take_arg(&arg, i, @ptrCast(&num), @ptrCast(&ctx));
                std.debug.assert(num == @as(i64, @intCast(i)));
                std.debug.assert(ctx == &c.CUBS_INT_CONTEXT);
            }

            flag = true;
            return 0;
        }
    };

    c.cubs_interpreter_push_frame(4, null, null);
    defer c.cubs_interpreter_pop_frame();

    for (0..4) |i| {
        @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(i)))).* = @as(i64, @intCast(i));
        c.cubs_interpreter_stack_set_context_at(i, &c.CUBS_INT_CONTEXT);
    }

    var bytecode: [3]c.Bytecode = undefined;
    c.cubs_operands_make_call_immediate(
        &bytecode,
        3,
        4,
        &[_]u16{ 0, 1, 2, 3 },
        false,
        0,
        c.CubsFunction{ .func = .{ .externC = &Example.example }, .funcType = c.cubsFunctionPtrTypeC },
    );

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);
    try expect(Example.flag == true);
}

test "call immediate C many args no return" {
    const Example = struct {
        var flag: bool = false;

        fn example(arg: c.CubsCFunctionHandler) callconv(.C) c_int {
            std.debug.assert(arg.argCount == 7);

            for (0..7) |i| {
                var num: i64 = undefined;
                var ctx: *const c.CubsTypeContext = undefined;

                c.cubs_function_take_arg(&arg, i, @ptrCast(&num), @ptrCast(&ctx));
                std.debug.assert(num == @as(i64, @intCast(i)));
                std.debug.assert(ctx == &c.CUBS_INT_CONTEXT);
            }

            flag = true;
            return 0;
        }
    };

    c.cubs_interpreter_push_frame(7, null, null);
    defer c.cubs_interpreter_pop_frame();

    for (0..7) |i| {
        @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(i)))).* = @as(i64, @intCast(i));
        c.cubs_interpreter_stack_set_context_at(i, &c.CUBS_INT_CONTEXT);
    }

    var bytecode: [4]c.Bytecode = undefined;
    c.cubs_operands_make_call_immediate(
        &bytecode,
        4,
        7,
        &[_]u16{ 0, 1, 2, 3, 4, 5, 6 },
        false,
        0,
        c.CubsFunction{ .func = .{ .externC = &Example.example }, .funcType = c.cubsFunctionPtrTypeC },
    );

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);
    try expect(Example.flag == true);
}

test "call immediate C no args with return" {
    const Example = struct {
        var flag: bool = false;

        fn example(arg: c.CubsCFunctionHandler) callconv(.C) c_int {
            std.debug.assert(arg.argCount == 0);
            std.debug.assert(arg.outReturn.value != null);
            std.debug.assert(arg.outReturn.context != null);

            var out: i64 = 10;

            c.cubs_function_return_set_value(arg, @ptrCast(&out), @ptrCast(&c.CUBS_INT_CONTEXT));

            flag = true;
            return 0;
        }
    };

    c.cubs_interpreter_push_frame(1, null, null);
    defer c.cubs_interpreter_pop_frame();

    var bytecode: [2]c.Bytecode = undefined;
    c.cubs_operands_make_call_immediate(
        &bytecode,
        4,
        0,
        null,
        true,
        0,
        c.CubsFunction{ .func = .{ .externC = &Example.example }, .funcType = c.cubsFunctionPtrTypeC },
    );

    c.cubs_interpreter_stack_set_null_context_at(0);
    try expect(c.cubs_interpreter_stack_context_at(0) != &c.CUBS_INT_CONTEXT);

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);
    try expect(Example.flag == true);
    try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);

    try expect(@as(*const i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 10);
}

test "jump forward 2" {
    var bytecode: [3]c.Bytecode = undefined;
    bytecode[0] = c.cubs_operands_make_jump(c.JUMP_TYPE_DEFAULT, 2, 0);
    bytecode[1] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    bytecode[2] = c.cubs_bytecode_encode(c.OpCodeNop, null);

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);
    try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[2]);
}

test "jump backwards 1" {
    var bytecode: [3]c.Bytecode = undefined;
    bytecode[0] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    bytecode[1] = c.cubs_operands_make_jump(c.JUMP_TYPE_DEFAULT, -1, 0);
    bytecode[2] = c.cubs_bytecode_encode(c.OpCodeNop, null);

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[1]));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);
    try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[0]);
}

test "jump if true forward 2" {
    var bytecode: [3]c.Bytecode = undefined;
    bytecode[0] = c.cubs_operands_make_jump(c.JUMP_TYPE_IF_TRUE, 2, 0);
    bytecode[1] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    bytecode[2] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    { // true
        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = true;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
        try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[2]);
    }
    { // false
        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = false;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
        try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[1]);
    }
}

test "jump if true backwards 1" {
    var bytecode: [3]c.Bytecode = undefined;
    bytecode[0] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    bytecode[1] = c.cubs_operands_make_jump(c.JUMP_TYPE_IF_TRUE, -1, 0);
    bytecode[2] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    { // true
        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = true;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[1]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
        try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[0]);
    }
    { // false
        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = false;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[1]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
        try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[2]);
    }
}

test "jump if false forward 2" {
    var bytecode: [3]c.Bytecode = undefined;
    bytecode[0] = c.cubs_operands_make_jump(c.JUMP_TYPE_IF_FALSE, 2, 0);
    bytecode[1] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    bytecode[2] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    { // true
        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = true;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
        try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[1]);
    }
    { // false
        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = false;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
        try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[2]);
    }
}

test "jump if false backwards 1" {
    var bytecode: [3]c.Bytecode = undefined;
    bytecode[0] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    bytecode[1] = c.cubs_operands_make_jump(c.JUMP_TYPE_IF_FALSE, -1, 0);
    bytecode[2] = c.cubs_bytecode_encode(c.OpCodeNop, null);
    { // true
        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = true;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[1]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
        try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[2]);
    }
    { // false
        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = false;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[1]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
        try expect(c.cubs_interpreter_get_instruction_pointer() == &bytecode[0]);
    }
}

test "deinit" {
    const bytecode = c.cubs_operands_make_deinit(0);

    c.cubs_interpreter_push_frame(4, null, null);
    defer c.cubs_interpreter_pop_frame();

    const s = "hello to this truly glorious world!";
    @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = c.cubs_string_init_unchecked(.{ .str = s.ptr, .len = s.len });
    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    try expect(c.cubs_interpreter_execute_operation(null) == 0);

    try expect(c.cubs_interpreter_stack_context_at(0) == null);
}

test "sync / unsync one thread one read" {
    var bytecode: [2]c.Bytecode = undefined;
    c.cubs_operands_make_sync(
        &bytecode,
        1,
        c.SYNC_TYPE_SYNC,
        1,
        &[_]c.SyncLockSource{.{ .src = 0, .lock = c.SYNC_LOCK_TYPE_READ }},
    );
    c.cubs_operands_make_sync(&bytecode[1], 1, c.SYNC_TYPE_UNSYNC, 0, null);

    c.cubs_interpreter_push_frame(2, null, null);
    defer c.cubs_interpreter_pop_frame();

    { // unique
        const val = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        val.* = Unique(i64).init(8);
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

        try expect(val.get().* == 8);

        try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync
        val.deinit();
    }
    { // shared
        const val = @as(*Shared(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        val.* = Shared(i64).init(8);
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

        try expect(val.get().* == 8);

        try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync
        val.deinit();
    }
    { // weak
        var u = Unique(i64).init(8);
        defer u.deinit();

        const val = @as(*Weak(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        val.* = u.makeWeak();
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

        try expect(val.get().* == 8);

        try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync
        val.deinit();
    }
}

test "sync / unsync one thread one write" {
    var bytecode: [2]c.Bytecode = undefined;
    c.cubs_operands_make_sync(
        &bytecode,
        1,
        c.SYNC_TYPE_SYNC,
        1,
        &[_]c.SyncLockSource{.{ .src = 0, .lock = c.SYNC_LOCK_TYPE_WRITE }},
    );
    c.cubs_operands_make_sync(&bytecode[1], 1, c.SYNC_TYPE_UNSYNC, 0, null);

    c.cubs_interpreter_push_frame(2, null, null);
    defer c.cubs_interpreter_pop_frame();

    { // unique
        const val = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        val.* = Unique(i64).init(8);
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

        try expect(val.getMut().* == 8);

        try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync
        val.deinit();
    }
    { // shared
        const val = @as(*Shared(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        val.* = Shared(i64).init(8);
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

        try expect(val.getMut().* == 8);

        try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync
        val.deinit();
    }
    { // weak
        var u = Unique(i64).init(8);
        defer u.deinit();

        const val = @as(*Weak(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        val.* = u.makeWeak();
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
        try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

        try expect(val.getMut().* == 8);

        try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync
        val.deinit();
    }
}

test "sync / unsync one thread two values" {
    var bytecode: [2]c.Bytecode = undefined;
    c.cubs_operands_make_sync(
        &bytecode,
        1,
        c.SYNC_TYPE_SYNC,
        1,
        &[_]c.SyncLockSource{ .{ .src = 0, .lock = c.SYNC_LOCK_TYPE_READ }, .{ .src = 2, .lock = c.SYNC_LOCK_TYPE_WRITE } },
    );
    c.cubs_operands_make_sync(&bytecode[1], 1, c.SYNC_TYPE_UNSYNC, 0, null);

    c.cubs_interpreter_push_frame(4, null, null);
    defer c.cubs_interpreter_pop_frame();

    const val1 = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
    val1.* = Unique(i64).init(8);
    defer val1.deinit();
    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);

    const val2 = @as(*Shared(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
    val2.* = Shared(i64).init(8);
    defer val2.deinit();
    c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_SHARED_CONTEXT);

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
    try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

    try expect(val1.get().* == 8);
    try expect(val2.getMut().* == 8);

    try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync
}
