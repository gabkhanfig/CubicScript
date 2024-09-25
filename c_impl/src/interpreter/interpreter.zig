const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/interpreter.h");
    @cInclude("interpreter/bytecode.h");
    @cInclude("interpreter/operations.h");
    @cInclude("primitives/context.h");
    @cInclude("primitives/string/string.h");
    @cInclude("primitives/array/array.h");
    @cInclude("primitives/set/set.h");
    @cInclude("primitives/map/map.h");
    @cInclude("program/program.h");
});

test "push frame no return" {
    c.cubs_interpreter_push_frame(1, null, null);
    defer c.cubs_interpreter_pop_frame();

    const frame = c.cubs_interpreter_current_stack_frame();
    try expect(frame.frameLength == 1);
    try expect(frame.basePointerOffset == 0);
}

test "nested push frame" {
    c.cubs_interpreter_push_frame(100, null, null);
    defer c.cubs_interpreter_pop_frame();

    {
        const frame = c.cubs_interpreter_current_stack_frame();
        try expect(frame.frameLength == 100);
        try expect(frame.basePointerOffset == 0);
    }

    c.cubs_interpreter_push_frame(100, null, null);
    defer c.cubs_interpreter_pop_frame();

    {
        const frame = c.cubs_interpreter_current_stack_frame();
        try expect(frame.frameLength == 100);
        try expect(frame.basePointerOffset == (100 + 4));
    }
}

test "unwind" {
    const frameLength = 10;
    { // all null
        c.cubs_interpreter_push_frame(frameLength, null, null);
        defer c.cubs_interpreter_pop_frame();

        for (0..frameLength) |i| {
            c.cubs_interpreter_stack_set_null_context_at(i);
        }

        c.cubs_interpreter_stack_unwind_frame();
    }
    { // one int
        c.cubs_interpreter_push_frame(frameLength, null, null);
        defer c.cubs_interpreter_pop_frame();

        for (0..frameLength) |i| {
            c.cubs_interpreter_stack_set_null_context_at(i);
        }

        @as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = 10;
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_INT_CONTEXT);

        c.cubs_interpreter_stack_unwind_frame();
    }
    { // one heap string (must explicitly deallocate)
        c.cubs_interpreter_push_frame(frameLength, null, null);
        defer c.cubs_interpreter_pop_frame();

        for (0..frameLength) |i| {
            c.cubs_interpreter_stack_set_null_context_at(i);
        }

        const str = "holy guacamole i am a decently long string on the heap";
        @as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* = c.cubs_string_init_unchecked(.{ .str = str.ptr, .len = str.len });
        c.cubs_interpreter_stack_set_context_at(0, &c.CUBS_STRING_CONTEXT);

        // If unwinding doesn't work properly, a memory leak will be detected by the test runner
        c.cubs_interpreter_stack_unwind_frame();
    }
}

test "push function arg" {
    { // one arg
        const val: i64 = 55;
        c.cubs_interpreter_push_script_function_arg(@ptrCast(&val), &c.CUBS_INT_CONTEXT, 0);

        c.cubs_interpreter_push_frame(1, null, null);
        defer c.cubs_interpreter_pop_frame();

        try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 55);
    }
    { // multiple args, 1 "slot" per arg
        const val1: i64 = 55;
        const val2: i64 = 56;
        c.cubs_interpreter_push_script_function_arg(@ptrCast(&val1), &c.CUBS_INT_CONTEXT, 0);
        c.cubs_interpreter_push_script_function_arg(@ptrCast(&val2), &c.CUBS_INT_CONTEXT, 1);

        c.cubs_interpreter_push_frame(2, null, null);
        defer c.cubs_interpreter_pop_frame();

        try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 55);
        try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(1)))).* == 56);
    }
    { // multiple args, wide args
        const str1 = "hello world!";
        const str2 = "hello to this truly glorious and magnificent world!";
        const sVal1 = c.cubs_string_init_unchecked(.{ .str = str1.ptr, .len = str1.len });
        const sVal2 = c.cubs_string_init_unchecked(.{ .str = str2.ptr, .len = str2.len });

        c.cubs_interpreter_push_script_function_arg(@ptrCast(&sVal1), &c.CUBS_STRING_CONTEXT, 0);
        c.cubs_interpreter_push_script_function_arg(@ptrCast(&sVal2), &c.CUBS_STRING_CONTEXT, 4);

        c.cubs_interpreter_push_frame(8, null, null);
        defer c.cubs_interpreter_pop_frame();

        try expect(c.cubs_string_eql_slice(@as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))), .{ .str = str1.ptr, .len = str1.len }));
        try expect(c.cubs_string_eql_slice(@as(*c.CubsString, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(4)))), .{ .str = str2.ptr, .len = str2.len }));

        c.cubs_interpreter_stack_unwind_frame();
    }
}

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
