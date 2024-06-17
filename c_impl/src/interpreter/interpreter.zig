const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/interpreter.h");
    @cInclude("interpreter/stack.h");
    @cInclude("interpreter/bytecode.h");
});

test "nop" {
    c.cubs_interpreter_push_frame(1, null, null, null);
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

        c.cubs_interpreter_push_frame(1, null, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_register_value_tag_at(0) == c.cubsValueTagBool);
        try expect(c.cubs_interpreter_register_value_at(0).boolean == true);
    }
    { // false
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_BOOL, 0, 0);

        c.cubs_interpreter_push_frame(1, null, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_register_value_tag_at(0) == c.cubsValueTagBool);
        try expect(c.cubs_interpreter_register_value_at(0).boolean == false);
    }
}

test "load immediate int" {
    { // positive
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_INT, 0, 10);

        c.cubs_interpreter_push_frame(1, null, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_register_value_tag_at(0) == c.cubsValueTagInt);
        try expect(c.cubs_interpreter_register_value_at(0).intNum == 10);
    }
    { // negative
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_INT, 0, -10);

        c.cubs_interpreter_push_frame(1, null, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_register_value_tag_at(0) == c.cubsValueTagInt);
        try expect(c.cubs_interpreter_register_value_at(0).intNum == -10);
    }
}

test "load immediate float" {
    { // positive
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_FLOAT, 0, @intFromFloat(10.0));

        c.cubs_interpreter_push_frame(1, null, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_register_value_tag_at(0) == c.cubsValueTagFloat);
        try expect(c.cubs_interpreter_register_value_at(0).floatNum == 10);
    }
    { // negative
        var bytecode = [_]c.Bytecode{undefined};
        bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_FLOAT, 0, @intFromFloat(-10.0));

        c.cubs_interpreter_push_frame(1, null, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_register_value_tag_at(0) == c.cubsValueTagFloat);
        try expect(c.cubs_interpreter_register_value_at(0).floatNum == -10);
    }
}

test "load immediate long" {
    { // int
        var bytecode = [3]c.Bytecode{ undefined, undefined, undefined };
        c.operands_make_load_immediate_long(@ptrCast(&bytecode), c.cubsValueTagInt, 0, @bitCast(@as(i64, -1234567890)));

        c.cubs_interpreter_push_frame(1, null, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_register_value_tag_at(0) == c.cubsValueTagInt);
        try expect(c.cubs_interpreter_register_value_at(0).intNum == -1234567890);
    }
    { // float
        var bytecode = [3]c.Bytecode{ undefined, undefined, undefined };
        c.operands_make_load_immediate_long(@ptrCast(&bytecode), c.cubsValueTagFloat, 0, @bitCast(@as(f64, -0.123456789)));

        c.cubs_interpreter_push_frame(1, null, null, null);
        defer c.cubs_interpreter_pop_frame();

        c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
        try expect(c.cubs_interpreter_execute_operation(null) == 0);

        try expect(c.cubs_interpreter_register_value_tag_at(0) == c.cubsValueTagFloat);
        try expect(c.cubs_interpreter_register_value_at(0).floatNum == -0.123456789);
    }
}
