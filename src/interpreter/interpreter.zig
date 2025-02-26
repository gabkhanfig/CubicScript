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
    @cInclude("primitives/reference/reference.h");
    @cInclude("primitives/sync_ptr/sync_ptr.h");
    @cInclude("program/program.h");
    @cInclude("program/program_internal.h");
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
        2,
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

test "sync / unsync one thread 3 values" {
    var bytecode: [3]c.Bytecode = undefined;
    c.cubs_operands_make_sync(
        &bytecode,
        2,
        c.SYNC_TYPE_SYNC,
        3,
        &[_]c.SyncLockSource{
            .{ .src = 0, .lock = c.SYNC_LOCK_TYPE_READ },
            .{ .src = 2, .lock = c.SYNC_LOCK_TYPE_WRITE },
            .{ .src = 4, .lock = c.SYNC_LOCK_TYPE_READ },
        },
    );
    c.cubs_operands_make_sync(&bytecode[2], 1, c.SYNC_TYPE_UNSYNC, 0, null);

    c.cubs_interpreter_push_frame(6, null, null);
    defer c.cubs_interpreter_pop_frame();

    const val1 = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
    val1.* = Unique(i64).init(8);
    defer val1.deinit();
    c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);

    const val2 = @as(*Shared(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
    val2.* = Shared(i64).init(8);
    defer val2.deinit();
    c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_SHARED_CONTEXT);

    var u = Unique(i64).init(8);
    defer u.deinit();

    const val3 = @as(*Weak(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4))));
    val3.* = u.makeWeak();
    defer val3.deinit();
    c.cubs_interpreter_stack_set_context_at(4, &c.CUBS_WEAK_CONTEXT);

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
    try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

    try expect(val1.get().* == 8);
    try expect(val2.getMut().* == 8);
    try expect(val3.get().* == 8);

    try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync
}

test "sync / unsync one thread 6 values (2 inline bytecode, 4 extended bytecode)" {
    var bytecode: [3]c.Bytecode = undefined;
    c.cubs_operands_make_sync(
        &bytecode,
        2,
        c.SYNC_TYPE_SYNC,
        6,
        &[_]c.SyncLockSource{
            .{ .src = 0, .lock = c.SYNC_LOCK_TYPE_READ },
            .{ .src = 2, .lock = c.SYNC_LOCK_TYPE_WRITE },
            .{ .src = 4, .lock = c.SYNC_LOCK_TYPE_READ },
            .{ .src = 6, .lock = c.SYNC_LOCK_TYPE_WRITE },
            .{ .src = 8, .lock = c.SYNC_LOCK_TYPE_READ },
            .{ .src = 10, .lock = c.SYNC_LOCK_TYPE_WRITE },
        },
    );
    c.cubs_operands_make_sync(&bytecode[2], 1, c.SYNC_TYPE_UNSYNC, 0, null);

    c.cubs_interpreter_push_frame(12, null, null);
    defer c.cubs_interpreter_pop_frame();

    for (0..6) |i| {
        const at = i * (@sizeOf(Unique(i64)) / 8);
        const val = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(at))));
        val.* = Unique(i64).init(@intCast(i));
        c.cubs_interpreter_stack_set_context_at(at, &c.CUBS_UNIQUE_CONTEXT);
    }

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
    try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

    for (0..6) |i| {
        const at = i * (@sizeOf(Unique(i64)) / 8);
        const val = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(at))));
        try expect(val.get().* == @as(i64, @intCast(i)));
    }

    try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync

    for (0..6) |i| {
        const at = i * (@sizeOf(Unique(i64)) / 8);
        const val = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(at))));
        defer val.deinit();
    }
}

test "sync / unsync one thread 7 values (2 inline bytecode, 4 extended bytecode, 1 extra extended bytecode)" {
    var bytecode: [4]c.Bytecode = undefined;
    c.cubs_operands_make_sync(
        &bytecode,
        3,
        c.SYNC_TYPE_SYNC,
        7,
        &[_]c.SyncLockSource{
            .{ .src = 0, .lock = c.SYNC_LOCK_TYPE_READ },
            .{ .src = 2, .lock = c.SYNC_LOCK_TYPE_WRITE },
            .{ .src = 4, .lock = c.SYNC_LOCK_TYPE_READ },
            .{ .src = 6, .lock = c.SYNC_LOCK_TYPE_WRITE },
            .{ .src = 8, .lock = c.SYNC_LOCK_TYPE_READ },
            .{ .src = 10, .lock = c.SYNC_LOCK_TYPE_WRITE },
            .{ .src = 12, .lock = c.SYNC_LOCK_TYPE_WRITE },
        },
    );
    c.cubs_operands_make_sync(&bytecode[3], 1, c.SYNC_TYPE_UNSYNC, 0, null);

    c.cubs_interpreter_push_frame(14, null, null);
    defer c.cubs_interpreter_pop_frame();

    for (0..7) |i| {
        const at = i * (@sizeOf(Unique(i64)) / 8);
        const val = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(at))));
        val.* = Unique(i64).init(@intCast(i));
        c.cubs_interpreter_stack_set_context_at(at, &c.CUBS_UNIQUE_CONTEXT);
    }

    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
    try expect(c.cubs_interpreter_execute_operation(null) == 0); // sync

    for (0..7) |i| {
        const at = i * (@sizeOf(Unique(i64)) / 8);
        const val = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(at))));
        try expect(val.get().* == @as(i64, @intCast(i)));
    }

    try expect(c.cubs_interpreter_execute_operation(null) == 0); // unsync

    for (0..7) |i| {
        const at = i * (@sizeOf(Unique(i64)) / 8);
        const val = @as(*Unique(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(at))));
        defer val.deinit();
    }
}

test "sync / unsync multithread one value write" {
    var bytecode: [2]c.Bytecode = undefined;
    c.cubs_operands_make_sync(
        &bytecode,
        1,
        c.SYNC_TYPE_SYNC,
        1,
        &[_]c.SyncLockSource{.{ .src = 0, .lock = c.SYNC_LOCK_TYPE_WRITE }},
    );
    c.cubs_operands_make_sync(&bytecode[1], 1, c.SYNC_TYPE_UNSYNC, 0, null);

    const ThreadTest = struct {
        fn add(s: Shared(i64), n: usize, b: []const c.Bytecode) void {
            c.cubs_interpreter_push_frame(2, null, null);
            defer c.cubs_interpreter_pop_frame();

            const val = @as(*Shared(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            val.* = s.clone();
            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);

            for (0..n) |_| {
                c.cubs_interpreter_set_instruction_pointer(@ptrCast(&b[0]));
                expect(c.cubs_interpreter_execute_operation(null) == 0) catch unreachable; // sync

                val.getMut().* += 1;

                expect(c.cubs_interpreter_execute_operation(null) == 0) catch unreachable; // unsync

            }

            val.deinit();
        }
    };

    var shared = Shared(i64).init(0);
    defer shared.deinit();

    const num = 10000;

    const t1 = try std.Thread.spawn(.{}, ThreadTest.add, .{ shared, num, &bytecode });
    const t2 = try std.Thread.spawn(.{}, ThreadTest.add, .{ shared, num, &bytecode });

    t1.join();
    t2.join();

    try expect(shared.get().* == (num * 2));
}

// This test is explicitly to ensure that out of order access of sync objects will still work, and avoid deadlock
test "sync / unsync multithread many value write random" {
    const COUNT = 3;

    const ThreadTest = struct {
        fn add(s: [COUNT]Shared(i64), n: usize) void {
            var lockSources: [3]c.SyncLockSource = undefined;
            { // randomize order
                var rnd = std.rand.DefaultPrng.init(@intCast(std.Thread.getCurrentId()));
                const randomNum = rnd.random().intRangeLessThan(usize, 0, COUNT); // 0 (inclusive) - COUNT (exclusive)

                for (0..COUNT) |i| {
                    const source = @as(u16, @intCast(@mod(i + randomNum, COUNT))) * 2;
                    lockSources[i] = c.SyncLockSource{ .src = source, .lock = c.SYNC_LOCK_TYPE_WRITE };
                }
            }

            var bytecode: [3]c.Bytecode = undefined;
            c.cubs_operands_make_sync(&bytecode, 2, c.SYNC_TYPE_SYNC, COUNT, &lockSources);
            c.cubs_operands_make_sync(&bytecode[2], 1, c.SYNC_TYPE_UNSYNC, 0, null);

            c.cubs_interpreter_push_frame(COUNT * 2, null, null);
            defer c.cubs_interpreter_pop_frame();

            for (0..COUNT) |i| {
                const val = @as(*Shared(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(i * 2))));
                val.* = s[i].clone();
                c.cubs_interpreter_stack_set_context_at(i * 2, &c.CUBS_SHARED_CONTEXT);
            }

            for (0..n) |_| {
                c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode[0]));
                expect(c.cubs_interpreter_execute_operation(null) == 0) catch unreachable; // sync

                for (0..COUNT) |i| {
                    const val = @as(*Shared(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(i * 2))));
                    val.getMut().* += 1;
                }

                expect(c.cubs_interpreter_execute_operation(null) == 0) catch unreachable; // unsyncs
            }

            for (0..COUNT) |i| {
                const val = @as(*Shared(i64), @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(i * 2))));
                val.deinit();
            }
        }
    };

    {
        var shared = [_]Shared(i64){ Shared(i64).init(0), Shared(i64).init(0), Shared(i64).init(0) };

        const num = 10000;

        var threads: [8]std.Thread = undefined;
        for (0..threads.len) |i| {
            threads[i] = try std.Thread.spawn(.{}, ThreadTest.add, .{ shared, num });
        }

        for (0..threads.len) |i| {
            threads[i].join();
        }

        for (&shared) |*sVal| {
            try expect(sVal.get().* == (num * threads.len));
            sVal.deinit();
        }
    }
}

test "move" {
    { // 1 byte (bool)
        const bytecode = c.cubs_operands_make_move(1, 0);
        c.cubs_interpreter_push_frame(2, null, null);
        defer c.cubs_interpreter_pop_frame();

        @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = true;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == null);
        try expect(@as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* == true);
        try expect(c.cubs_interpreter_stack_context_at(1) == &c.CUBS_BOOL_CONTEXT);
    }
    { // 8 bytes, full stack slot (64 bit int)
        const bytecode = c.cubs_operands_make_move(1, 0);
        c.cubs_interpreter_push_frame(2, null, null);
        defer c.cubs_interpreter_pop_frame();

        @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = 55;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == null);
        try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* == 55);
        try expect(c.cubs_interpreter_stack_context_at(1) == &c.CUBS_INT_CONTEXT);
    }
    { // 32 bytes, multiple stack slots (string)
        const bytecode = c.cubs_operands_make_move(4, 0);
        c.cubs_interpreter_push_frame(8, null, null);
        defer c.cubs_interpreter_pop_frame();

        const s = "hello to this fantastical world!";
        const slice = c.CubsStringSlice{ .str = s.ptr, .len = s.len };
        @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = c.cubs_string_init_unchecked(slice);
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == null);
        try expect(c.cubs_string_eql_slice(@as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4)))), slice));
        try expect(c.cubs_interpreter_stack_context_at(4) == &c.CUBS_STRING_CONTEXT);
        c.cubs_string_deinit(@as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4)))));
    }
}

test "clone" {
    { // 1 byte (bool)
        const bytecode = c.cubs_operands_make_clone(1, 0);
        c.cubs_interpreter_push_frame(2, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));

        src.* = true;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_BOOL_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(src.* == true);
        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == true);
        try expect(c.cubs_interpreter_stack_context_at(1) == &c.CUBS_BOOL_CONTEXT);
    }
    { // 8 bytes, full stack slot (64 bit int)
        const bytecode = c.cubs_operands_make_clone(1, 0);
        c.cubs_interpreter_push_frame(2, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));

        src.* = 55;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(src.* == 55);
        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == 55);
        try expect(c.cubs_interpreter_stack_context_at(1) == &c.CUBS_INT_CONTEXT);
    }
    { // 32 bytes, multiple stack slots (string)
        const bytecode = c.cubs_operands_make_clone(4, 0);
        c.cubs_interpreter_push_frame(8, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4))));

        const s = "hello to this fantastical world!";
        const slice = c.CubsStringSlice{ .str = s.ptr, .len = s.len };
        src.* = c.cubs_string_init_unchecked(slice);
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_string_eql_slice(src, slice));
        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_STRING_CONTEXT);
        try expect(c.cubs_string_eql_slice(dst, slice));
        try expect(c.cubs_interpreter_stack_context_at(4) == &c.CUBS_STRING_CONTEXT);
        c.cubs_string_deinit(src);
        c.cubs_string_deinit(dst);
    }
}

test "equal" {
    { // i64 equal true
        const bytecode = c.cubs_operands_make_compare(c.COMPARE_OP_EQUAL, 2, 0, 1);
        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src1 = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src2 = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);

        src1.* = 25;
        src2.* = 25;

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == true);
    }
    { // i64 equal false
        const bytecode = c.cubs_operands_make_compare(c.COMPARE_OP_EQUAL, 2, 0, 1);
        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src1 = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src2 = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);

        src1.* = 25;
        src2.* = 26;

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == false);
    }
    { // string equal true
        const bytecode = c.cubs_operands_make_compare(c.COMPARE_OP_EQUAL, 8, 0, 4);
        c.cubs_interpreter_push_frame(9, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src1 = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src2 = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(8))));

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(4, &c.CUBS_STRING_CONTEXT);

        const s1 = "holy guacamole this is excellent!";
        const s2 = s1;
        src1.* = c.cubs_string_init_unchecked(.{ .str = s1.ptr, .len = s1.len });
        src2.* = c.cubs_string_init_unchecked(.{ .str = s2.ptr, .len = s2.len });

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(8) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == true);

        c.cubs_string_deinit(src1);
        c.cubs_string_deinit(src2);
    }
    { // string equal false
        const bytecode = c.cubs_operands_make_compare(c.COMPARE_OP_EQUAL, 8, 0, 4);
        c.cubs_interpreter_push_frame(9, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src1 = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src2 = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(8))));

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(4, &c.CUBS_STRING_CONTEXT);

        const s1 = "holy guacamole this is excellent!";
        const s2 = "holy guacamole this isn't cool...";
        src1.* = c.cubs_string_init_unchecked(.{ .str = s1.ptr, .len = s1.len });
        src2.* = c.cubs_string_init_unchecked(.{ .str = s2.ptr, .len = s2.len });

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(8) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == false);

        c.cubs_string_deinit(src1);
        c.cubs_string_deinit(src2);
    }
}

test "not equal" {
    { // i64 not equal false
        const bytecode = c.cubs_operands_make_compare(c.COMPARE_OP_NOT_EQUAL, 2, 0, 1);
        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src1 = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src2 = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);

        src1.* = 25;
        src2.* = 25;

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == false);
    }
    { // i64 not equal true
        const bytecode = c.cubs_operands_make_compare(c.COMPARE_OP_NOT_EQUAL, 2, 0, 1);
        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src1 = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src2 = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);

        src1.* = 25;
        src2.* = 26;

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == true);
    }
    { // string not equal false
        const bytecode = c.cubs_operands_make_compare(c.COMPARE_OP_NOT_EQUAL, 8, 0, 4);
        c.cubs_interpreter_push_frame(9, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src1 = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src2 = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(8))));

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(4, &c.CUBS_STRING_CONTEXT);

        const s1 = "holy guacamole this is excellent!";
        const s2 = s1;
        src1.* = c.cubs_string_init_unchecked(.{ .str = s1.ptr, .len = s1.len });
        src2.* = c.cubs_string_init_unchecked(.{ .str = s2.ptr, .len = s2.len });

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(8) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == false);

        c.cubs_string_deinit(src1);
        c.cubs_string_deinit(src2);
    }
    { // string not equal true
        const bytecode = c.cubs_operands_make_compare(c.COMPARE_OP_NOT_EQUAL, 8, 0, 4);
        c.cubs_interpreter_push_frame(9, null, null);
        defer c.cubs_interpreter_pop_frame();

        const src1 = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src2 = @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4))));
        const dst = @as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(8))));

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(4, &c.CUBS_STRING_CONTEXT);

        const s1 = "holy guacamole this is excellent!";
        const s2 = "holy guacamole this isn't cool...";
        src1.* = c.cubs_string_init_unchecked(.{ .str = s1.ptr, .len = s1.len });
        src2.* = c.cubs_string_init_unchecked(.{ .str = s2.ptr, .len = s2.len });

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(8) == &c.CUBS_BOOL_CONTEXT);
        try expect(dst.* == true);

        c.cubs_string_deinit(src1);
        c.cubs_string_deinit(src2);
    }
}

test "dereference" {
    { // const ref
        const bytecode = c.cubs_operands_make_dereference(2, 0);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_CONST_REF_CONTEXT);
        const src = @as(*c.CubsConstRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        const value: i64 = 56;
        const ref = c.CubsConstRef{ .ref = @ptrCast(&value), .context = &c.CUBS_INT_CONTEXT };
        src.* = ref;

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == value);
    }
    { // mut ref
        const bytecode = c.cubs_operands_make_dereference(2, 0);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_MUT_REF_CONTEXT);
        const src = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        var value: i64 = 56;
        const ref = c.CubsMutRef{ .ref = @ptrCast(&value), .context = &c.CUBS_INT_CONTEXT };
        src.* = ref;

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == value);
    }
    { // unique sync ptr
        const bytecode = c.cubs_operands_make_dereference(2, 0);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);
        const src = @as(*c.CubsUnique, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        var value: i64 = 56;
        src.* = c.cubs_unique_init(@ptrCast(&value), &c.CUBS_INT_CONTEXT);
        defer c.cubs_unique_deinit(src);
        c.cubs_unique_lock_exclusive(src);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        c.cubs_unique_unlock_exclusive(src);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == value);
    }
    { // shared sync ptr
        const bytecode = c.cubs_operands_make_dereference(2, 0);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
        const src = @as(*c.CubsShared, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        var value: i64 = 56;
        src.* = c.cubs_shared_init(@ptrCast(&value), &c.CUBS_INT_CONTEXT);
        defer c.cubs_shared_deinit(src);
        c.cubs_shared_lock_exclusive(src);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        c.cubs_shared_unlock_exclusive(src);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == value);
    }
    { // weak sync ptr
        const bytecode = c.cubs_operands_make_dereference(2, 0);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);
        const src = @as(*c.CubsWeak, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        var value: i64 = 56;
        var unique = c.cubs_unique_init(@ptrCast(&value), &c.CUBS_INT_CONTEXT);
        defer c.cubs_unique_deinit(&unique);

        src.* = c.cubs_unique_make_weak(&unique);
        defer c.cubs_weak_deinit(src);

        c.cubs_weak_lock_exclusive(src);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        c.cubs_weak_unlock_exclusive(src);

        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == value);
    }
}

test "set reference" {
    { // mut ref
        const bytecode = c.cubs_operands_make_set_reference(0, 2);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_MUT_REF_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
        const dst = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        src.* = 58;
        var value: i64 = 50;
        dst.* = c.CubsMutRef{ .ref = @ptrCast(&value), .context = &c.CUBS_INT_CONTEXT };

        try expect(@as(*const i64, @alignCast(@ptrCast(dst.ref))).* == 50);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(@as(*const i64, @alignCast(@ptrCast(dst.ref))).* == 58);
    }
    { // unique
        const bytecode = c.cubs_operands_make_set_reference(0, 2);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
        const dst = @as(*c.CubsUnique, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        src.* = 58;
        var value: i64 = 50;
        dst.* = c.cubs_unique_init(@ptrCast(&value), &c.CUBS_INT_CONTEXT);
        defer c.cubs_unique_deinit(dst);

        c.cubs_unique_lock_exclusive(dst);
        defer c.cubs_unique_unlock_exclusive(dst);

        try expect(@as(*const i64, @alignCast(@ptrCast(c.cubs_unique_get(dst)))).* == 50);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(@as(*const i64, @alignCast(@ptrCast(c.cubs_unique_get(dst)))).* == 58);
    }
    { // shared
        const bytecode = c.cubs_operands_make_set_reference(0, 2);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
        const dst = @as(*c.CubsShared, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        src.* = 58;
        var value: i64 = 50;
        dst.* = c.cubs_shared_init(@ptrCast(&value), &c.CUBS_INT_CONTEXT);
        defer c.cubs_shared_deinit(dst);

        c.cubs_shared_lock_exclusive(dst);
        defer c.cubs_shared_unlock_exclusive(dst);

        try expect(@as(*const i64, @alignCast(@ptrCast(c.cubs_shared_get(dst)))).* == 50);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(@as(*const i64, @alignCast(@ptrCast(c.cubs_shared_get(dst)))).* == 58);
    }
    { // weak
        const bytecode = c.cubs_operands_make_set_reference(0, 2);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
        c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
        const dst = @as(*c.CubsWeak, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        var value: i64 = 50;
        var unique = c.cubs_unique_init(@ptrCast(&value), &c.CUBS_INT_CONTEXT);
        defer c.cubs_unique_deinit(&unique);

        src.* = 58;
        dst.* = c.cubs_unique_make_weak(&unique);
        defer c.cubs_weak_deinit(dst);

        c.cubs_weak_lock_exclusive(dst);
        defer c.cubs_weak_unlock_exclusive(dst);

        try expect(@as(*const i64, @alignCast(@ptrCast(c.cubs_weak_get(dst)))).* == 50);

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(@as(*const i64, @alignCast(@ptrCast(c.cubs_weak_get(dst)))).* == 58);
    }
}

const OneMemberStruct = extern struct { num: i64 };
const oneContext = c.CubsTypeContext{
    .sizeOfType = @sizeOf(OneMemberStruct),
    .name = "OneMemberStruct",
    .members = &[_]c.CubsTypeMemberContext{c.CubsTypeMemberContext{
        .byteOffset = 0,
        .context = &c.CUBS_INT_CONTEXT,
        .name = .{ .str = "num", .len = 3 },
    }},
    .membersLen = 1,
};

const TwoMemberStruct = extern struct { num1: i64, num2: i64 };
const twoContext = c.CubsTypeContext{
    .sizeOfType = @sizeOf(TwoMemberStruct),
    .members = &[_]c.CubsTypeMemberContext{
        c.CubsTypeMemberContext{
            .byteOffset = 0,
            .context = &c.CUBS_INT_CONTEXT,
            .name = .{ .str = "num1", .len = 4 },
        },
        c.CubsTypeMemberContext{
            .byteOffset = 8,
            .context = &c.CUBS_INT_CONTEXT,
            .name = .{ .str = "num2", .len = 4 },
        },
    },
    .membersLen = 2,
};

test "struct get member from value" {
    { // one member
        const bytecode = c.cubs_operands_make_get_member(1, 0, 0);

        c.cubs_interpreter_push_frame(2, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &oneContext);
        const src = @as(*OneMemberStruct, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        src.* = .{ .num = 99 };

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        const dst = @as(*const i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));
        try expect(c.cubs_interpreter_stack_context_at(1) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == 99);
    }
    { // two member, first member
        const bytecode = c.cubs_operands_make_get_member(2, 0, 0);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &twoContext);
        const src = @as(*TwoMemberStruct, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        src.* = .{ .num1 = 91, .num2 = 92 };

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        const dst = @as(*const i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == 91);
    }
    { // two member, second member
        const bytecode = c.cubs_operands_make_get_member(2, 0, 1);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &twoContext);
        const src = @as(*TwoMemberStruct, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        src.* = .{ .num1 = 91, .num2 = 92 };

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        const dst = @as(*const i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
        try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
        try expect(dst.* == 92);
    }
}

test "struct get member from reference" {
    // These two will be copied and used through the following test cases
    var oneVal = OneMemberStruct{ .num = 51 };
    var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };

    { // const ref
        { // one member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_CONST_REF_CONTEXT);
            const src = @as(*c.CubsConstRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = .{ .ref = @ptrCast(&oneVal), .context = &oneContext };

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 51);
        }
        { // two member, first member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_CONST_REF_CONTEXT);
            const src = @as(*c.CubsConstRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = .{ .ref = @ptrCast(&twoVal), .context = &twoContext };

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 52);
        }
        { // two member, second member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_CONST_REF_CONTEXT);
            const src = @as(*c.CubsConstRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = .{ .ref = @ptrCast(&twoVal), .context = &twoContext };

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 53);
        }
    }
    { // mut ref
        { // one member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_MUT_REF_CONTEXT);
            const src = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = .{ .ref = @ptrCast(&oneVal), .context = &oneContext };

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 51);
        }
        { // two member, first member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_MUT_REF_CONTEXT);
            const src = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = .{ .ref = @ptrCast(&twoVal), .context = &twoContext };

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 52);
        }
        { // two member, second member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_MUT_REF_CONTEXT);
            const src = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = .{ .ref = @ptrCast(&twoVal), .context = &twoContext };

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 53);
        }
    }
    { // sync unique
        { // one member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);
            const src = @as(*c.CubsUnique, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = c.cubs_unique_init(@ptrCast(&oneVal), &oneContext);
            defer c.cubs_unique_deinit(src);
            c.cubs_unique_lock_exclusive(src);
            defer c.cubs_unique_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 51);
        }
        { // two member, first member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);
            const src = @as(*c.CubsUnique, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = c.cubs_unique_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_unique_deinit(src);
            c.cubs_unique_lock_exclusive(src);
            defer c.cubs_unique_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 52);
        }
        { // two member, second member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);
            const src = @as(*c.CubsUnique, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = c.cubs_unique_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_unique_deinit(src);
            c.cubs_unique_lock_exclusive(src);
            defer c.cubs_unique_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 53);
        }
    }
    { // sync shared
        { // one member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
            const src = @as(*c.CubsShared, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = c.cubs_shared_init(@ptrCast(&oneVal), &oneContext);
            defer c.cubs_shared_deinit(src);
            c.cubs_shared_lock_exclusive(src);
            defer c.cubs_shared_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 51);
        }
        { // two member, first member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
            const src = @as(*c.CubsShared, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = c.cubs_shared_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_shared_deinit(src);
            c.cubs_shared_lock_exclusive(src);
            defer c.cubs_shared_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 52);
        }
        { // two member, second member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
            const src = @as(*c.CubsShared, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            src.* = c.cubs_shared_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_shared_deinit(src);
            c.cubs_shared_lock_exclusive(src);
            defer c.cubs_shared_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 53);
        }
    }
    { // sync weak
        { // one member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);
            const src = @as(*c.CubsWeak, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            var unique = c.cubs_unique_init(@ptrCast(&oneVal), &oneContext);
            defer c.cubs_unique_deinit(&unique);

            src.* = c.cubs_unique_make_weak(&unique);
            defer c.cubs_weak_deinit(src);
            c.cubs_weak_lock_exclusive(src);
            defer c.cubs_weak_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 51);
        }
        { // two member, first member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);
            const src = @as(*c.CubsWeak, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            var unique = c.cubs_unique_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_unique_deinit(&unique);

            src.* = c.cubs_unique_make_weak(&unique);
            defer c.cubs_weak_deinit(src);
            c.cubs_weak_lock_exclusive(src);
            defer c.cubs_weak_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 52);
        }
        { // two member, second member
            const bytecode = c.cubs_operands_make_get_member(2, 0, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);
            const src = @as(*c.CubsWeak, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const dst = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            var unique = c.cubs_unique_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_unique_deinit(&unique);

            src.* = c.cubs_unique_make_weak(&unique);
            defer c.cubs_weak_deinit(src);
            c.cubs_weak_lock_exclusive(src);
            defer c.cubs_weak_unlock_exclusive(src);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(c.cubs_interpreter_stack_context_at(2) == &c.CUBS_INT_CONTEXT);
            try expect(dst.* == 53);
        }
    }
}

test "struct set member from value" {
    { // one member
        const bytecode = c.cubs_operands_make_set_member(0, 1, 0);

        c.cubs_interpreter_push_frame(2, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &oneContext);
        c.cubs_interpreter_stack_set_context_at(1, &c.CUBS_INT_CONTEXT);
        const dst = @as(*OneMemberStruct, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));

        src.* = 58;
        dst.* = .{ .num = 50 };

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(dst.num == 58);
    }
    { // two member, first member
        const bytecode = c.cubs_operands_make_set_member(0, 2, 0);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &twoContext);
        c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
        const dst = @as(*TwoMemberStruct, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        src.* = 58;
        dst.* = .{ .num1 = 50, .num2 = 51 };

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(dst.num1 == 58);
        try expect(dst.num2 == 51);
    }
    { // two member, second member
        const bytecode = c.cubs_operands_make_set_member(0, 2, 1);

        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &twoContext);
        c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
        const dst = @as(*TwoMemberStruct, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

        src.* = 58;
        dst.* = .{ .num1 = 50, .num2 = 51 };

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(dst.num1 == 50);
        try expect(dst.num2 == 58);
    }
}

test "struct set member from reference" {
    // These two will be copied and used through the following test cases
    // var oneVal = OneMemberStruct{ .num = 51 };
    // var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };

    { // mut ref
        { // one member
            var oneVal = OneMemberStruct{ .num = 51 };

            const bytecode = c.cubs_operands_make_set_member(0, 2, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_MUT_REF_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));

            dst.* = .{ .ref = @ptrCast(&oneVal), .context = &oneContext };
            src.* = 55;

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(oneVal.num == 55);
        }
        { // two member, first member
            var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };

            const bytecode = c.cubs_operands_make_set_member(0, 2, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_MUT_REF_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            dst.* = .{ .ref = @ptrCast(&twoVal), .context = &twoContext };

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(twoVal.num1 == 55);
            try expect(twoVal.num2 == 53);
        }
        { // two member, second member
            var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };

            const bytecode = c.cubs_operands_make_set_member(0, 2, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_MUT_REF_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            dst.* = .{ .ref = @ptrCast(&twoVal), .context = &twoContext };

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(twoVal.num1 == 52);
            try expect(twoVal.num2 == 55);
        }
    }
    { // sync unique
        { // one member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsUnique, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var oneVal = OneMemberStruct{ .num = 51 };
            dst.* = c.cubs_unique_init(@ptrCast(&oneVal), &oneContext);
            defer c.cubs_unique_deinit(dst);
            c.cubs_unique_lock_exclusive(dst);
            defer c.cubs_unique_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const OneMemberStruct, @ptrCast(@alignCast(c.cubs_unique_get(dst)))).num == 55);
        }
        { // two member, first member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsUnique, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };
            dst.* = c.cubs_unique_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_unique_deinit(dst);
            c.cubs_unique_lock_exclusive(dst);
            defer c.cubs_unique_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_unique_get(dst)))).num1 == 55);
            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_unique_get(dst)))).num2 == 53);
        }
        { // two member, second member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_UNIQUE_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsUnique, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };
            dst.* = c.cubs_unique_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_unique_deinit(dst);
            c.cubs_unique_lock_exclusive(dst);
            defer c.cubs_unique_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_unique_get(dst)))).num1 == 52);
            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_unique_get(dst)))).num2 == 55);
        }
    }
    { // sync shared
        { // one member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsShared, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var oneVal = OneMemberStruct{ .num = 51 };
            dst.* = c.cubs_shared_init(@ptrCast(&oneVal), &oneContext);
            defer c.cubs_shared_deinit(dst);
            c.cubs_shared_lock_exclusive(dst);
            defer c.cubs_shared_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const OneMemberStruct, @ptrCast(@alignCast(c.cubs_shared_get(dst)))).num == 55);
        }
        { // two member, first member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsShared, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };
            dst.* = c.cubs_shared_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_shared_deinit(dst);
            c.cubs_shared_lock_exclusive(dst);
            defer c.cubs_shared_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_shared_get(dst)))).num1 == 55);
            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_shared_get(dst)))).num2 == 53);
        }
        { // two member, second member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_SHARED_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsShared, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };
            dst.* = c.cubs_shared_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_shared_deinit(dst);
            c.cubs_shared_lock_exclusive(dst);
            defer c.cubs_shared_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_shared_get(dst)))).num1 == 52);
            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_shared_get(dst)))).num2 == 55);
        }
    }
    { // sync weak
        { // one member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsWeak, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var oneVal = OneMemberStruct{ .num = 51 };
            var unique = c.cubs_unique_init(@ptrCast(&oneVal), &oneContext);
            defer c.cubs_unique_deinit(&unique);

            dst.* = c.cubs_unique_make_weak(&unique);
            defer c.cubs_weak_deinit(dst);
            c.cubs_weak_lock_exclusive(dst);
            defer c.cubs_weak_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const OneMemberStruct, @ptrCast(@alignCast(c.cubs_weak_get(dst)))).num == 55);
        }
        { // two member, first member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 0);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsWeak, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };
            var unique = c.cubs_unique_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_unique_deinit(&unique);

            dst.* = c.cubs_unique_make_weak(&unique);
            defer c.cubs_weak_deinit(dst);
            c.cubs_weak_lock_exclusive(dst);
            defer c.cubs_weak_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_weak_get(dst)))).num1 == 55);
            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_weak_get(dst)))).num2 == 53);
        }
        { // two member, second member
            const bytecode = c.cubs_operands_make_set_member(0, 2, 1);
            c.cubs_interpreter_push_frame(3, null, null);
            defer c.cubs_interpreter_pop_frame();

            c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_WEAK_CONTEXT);
            c.cubs_interpreter_stack_set_context_at(2, &c.CUBS_INT_CONTEXT);
            const dst = @as(*c.CubsWeak, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
            const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(2))));
            src.* = 55;

            var twoVal = TwoMemberStruct{ .num1 = 52, .num2 = 53 };
            var unique = c.cubs_unique_init(@ptrCast(&twoVal), &twoContext);
            defer c.cubs_unique_deinit(&unique);

            dst.* = c.cubs_unique_make_weak(&unique);
            defer c.cubs_weak_deinit(dst);
            c.cubs_weak_lock_exclusive(dst);
            defer c.cubs_weak_unlock_exclusive(dst);

            c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
            try expect(c.cubs_interpreter_execute_operation(null) == 0);

            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_weak_get(dst)))).num1 == 52);
            try expect(@as(*const TwoMemberStruct, @ptrCast(@alignCast(c.cubs_weak_get(dst)))).num2 == 55);
        }
    }
}

test "make reference" {
    { // immutable
        const bytecode = c.cubs_operands_make_reference(1, 0, false);
        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);

        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*c.CubsConstRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));
        src.* = 66;

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(1) == &c.CUBS_CONST_REF_CONTEXT);
        try expect(dst.context == &c.CUBS_INT_CONTEXT);
        try expect(@as(*const i64, @ptrCast(@alignCast(dst.ref))) == src); // same pointer
        try expect(@as(*const i64, @ptrCast(@alignCast(dst.ref))).* == 66); // same value
    }
    { // mutable
        const bytecode = c.cubs_operands_make_reference(1, 0, true);
        c.cubs_interpreter_push_frame(3, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);

        const src = @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0))));
        const dst = @as(*c.CubsMutRef, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1))));
        src.* = 66;

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(1) == &c.CUBS_MUT_REF_CONTEXT);
        try expect(dst.context == &c.CUBS_INT_CONTEXT);
        try expect(@as(*const i64, @ptrCast(@alignCast(dst.ref))) == src); // same pointer
        try expect(@as(*const i64, @ptrCast(@alignCast(dst.ref))).* == 66); // same value
    }
}
