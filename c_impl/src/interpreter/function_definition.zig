const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/interpreter.h");
    @cInclude("interpreter/function_definition.h");
    @cInclude("interpreter/bytecode.h");
    @cInclude("primitives/primitives_context.h");
    @cInclude("primitives/string/string.h");
    @cInclude("program/program.h");
});

test "init deinit" {
    var builder = c.FunctionBuilder{};
    defer c.cubs_function_builder_deinit(&builder);
}

test "push bytecode" {
    {
        var builder = c.FunctionBuilder{ .stackSpaceRequired = 3 };
        defer c.cubs_function_builder_deinit(&builder);

        const bytecode = c.operands_make_add_dst(false, 2, 0, 1);
        c.cubs_function_builder_push_bytecode(&builder, bytecode);

        try expect(builder.bytecodeLen == 1);
    }
    {
        var builder = c.FunctionBuilder{ .stackSpaceRequired = 4 };
        defer c.cubs_function_builder_deinit(&builder);

        const b1 = c.operands_make_add_dst(false, 2, 0, 1);
        const b2 = c.operands_make_add_dst(false, 3, 1, 2);
        c.cubs_function_builder_push_bytecode(&builder, b1);
        c.cubs_function_builder_push_bytecode(&builder, b2);

        try expect(builder.bytecodeLen == 2);
    }
}

test "push bytecode many" {
    {
        var builder = c.FunctionBuilder{ .stackSpaceRequired = 3 };
        defer c.cubs_function_builder_deinit(&builder);

        var bytecode = [2]c.Bytecode{ undefined, undefined };
        c.operands_make_load_immediate_long(@ptrCast(&bytecode), c.cubsValueTagFloat, 0, @bitCast(@as(f64, -0.123456789)));

        c.cubs_function_builder_push_bytecode_many(&builder, &bytecode, 2);

        try expect(builder.bytecodeLen == 2);
    }
    {
        var builder = c.FunctionBuilder{ .stackSpaceRequired = 3 };
        defer c.cubs_function_builder_deinit(&builder);

        var b1 = [2]c.Bytecode{ undefined, undefined };
        c.operands_make_load_immediate_long(@ptrCast(&b1), c.cubsValueTagFloat, 0, @bitCast(@as(f64, -0.123456789)));

        var b2 = [3]c.Bytecode{ undefined, undefined, undefined };

        var immediateString = c.cubs_string_init_unchecked(.{ .str = "hello world!".ptr, .len = "hello world!".len });
        defer c.cubs_string_deinit(&immediateString);

        c.operands_make_load_clone_from_ptr(&b2, 0, @ptrCast(&immediateString), &c.CUBS_STRING_CONTEXT);

        c.cubs_function_builder_push_bytecode_many(&builder, &b1, 2);
        c.cubs_function_builder_push_bytecode_many(&builder, &b2, 3);
    }
}

test "build nop" {
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var builder = c.FunctionBuilder{ .stackSpaceRequired = 0 };
    defer c.cubs_function_builder_deinit(&builder);

    const bytecode = c.cubs_bytecode_encode(c.OpCodeNop, null);

    c.cubs_function_builder_push_bytecode(&builder, bytecode);

    _ = c.cubs_function_builder_build(&builder, &program);
}

test "build and execute" {
    {
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var builder = c.FunctionBuilder{ .stackSpaceRequired = 0 };
        defer c.cubs_function_builder_deinit(&builder);

        {
            const bytecode = c.cubs_bytecode_encode(c.OpCodeNop, null);
            c.cubs_function_builder_push_bytecode(&builder, bytecode);
        }

        const func = c.cubs_function_builder_build(&builder, &program);
        const bytecodeStart = c.cubs_function_bytecode_start(func);

        c.cubs_interpreter_push_frame(0, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(bytecodeStart));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);
    }
    {
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var builder = c.FunctionBuilder{ .stackSpaceRequired = 1 };
        defer c.cubs_function_builder_deinit(&builder);

        {
            const bytecode = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_BOOL, 0, 1);
            c.cubs_function_builder_push_bytecode(&builder, bytecode);
        }

        const func = c.cubs_function_builder_build(&builder, &program);
        const bytecodeStart = c.cubs_function_bytecode_start(func);

        c.cubs_interpreter_push_frame(1, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(bytecodeStart));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_BOOL_CONTEXT);
        try expect(@as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == true);
    }
}
