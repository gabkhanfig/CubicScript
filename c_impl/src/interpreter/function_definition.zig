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
