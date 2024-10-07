const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/bytecode.h");
    @cInclude("interpreter/operations.h");
    @cInclude("interpreter/stack.h");
    @cInclude("primitives/context.h");
    @cInclude("primitives/string/string.h");
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
