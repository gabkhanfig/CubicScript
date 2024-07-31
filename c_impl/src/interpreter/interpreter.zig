const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/interpreter.h");
    @cInclude("interpreter/bytecode.h");
    @cInclude("primitives/primitives_context.h");
    @cInclude("primitives/string/string.h");
    @cInclude("primitives/array/array.h");
    @cInclude("primitives/set/set.h");
    @cInclude("primitives/map/map.h");
});

// test "push frame no return" {
//     c.cubs_interpreter_push_frame(1, null, null, null);
//     defer c.cubs_interpreter_pop_frame();

//     const frame = c.cubs_interpreter_current_stack_frame();
//     try expect(frame.frameLength == 1);
//     try expect(frame.basePointerOffset == 0);
// }

// test "nested push frame" {
//     c.cubs_interpreter_push_frame(100, null, null, null);
//     defer c.cubs_interpreter_pop_frame();

//     {
//         const frame = c.cubs_interpreter_current_stack_frame();
//         try expect(frame.frameLength == 100);
//         try expect(frame.basePointerOffset == 0);
//     }

//     c.cubs_interpreter_push_frame(100, null, null, null);
//     defer c.cubs_interpreter_pop_frame();

//     {
//         const frame = c.cubs_interpreter_current_stack_frame();
//         try expect(frame.frameLength == 100);
//         try expect(frame.basePointerOffset == (100 + 4));
//     }
// }

// test "nop" {
//     c.cubs_interpreter_push_frame(1, null, null, null);
//     defer c.cubs_interpreter_pop_frame();

//     const bytecode = [_]c.Bytecode{
//         c.cubs_bytecode_encode(c.OpCodeNop, null),
//     };
//     c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//     const result = c.cubs_interpreter_execute_operation(null);
//     try expect(result == 0);
// }

// test "load immediate bool" {
//     { // true
//         var bytecode = [_]c.Bytecode{undefined};
//         bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_BOOL, 0, 1);

//         c.cubs_interpreter_push_frame(1, null, null, null);
//         defer c.cubs_interpreter_pop_frame();

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_BOOL_CONTEXT);
//         try expect(@as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == true);
//     }
//     { // false
//         var bytecode = [_]c.Bytecode{undefined};
//         bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_BOOL, 0, 0);

//         c.cubs_interpreter_push_frame(1, null, null, null);
//         defer c.cubs_interpreter_pop_frame();

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_BOOL_CONTEXT);
//         try expect(@as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == false);
//     }
// }

// test "load immediate int" {
//     { // positive
//         var bytecode = [_]c.Bytecode{undefined};
//         bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_INT, 0, 10);

//         c.cubs_interpreter_push_frame(1, null, null, null);
//         defer c.cubs_interpreter_pop_frame();

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
//         try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 10);
//     }
//     { // negative
//         var bytecode = [_]c.Bytecode{undefined};
//         bytecode[0] = c.operands_make_load_immediate(c.LOAD_IMMEDIATE_INT, 0, -10);

//         c.cubs_interpreter_push_frame(1, null, null, null);
//         defer c.cubs_interpreter_pop_frame();

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
//         try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == -10);
//     }
// }

// test "load immediate long" {
//     { // int
//         var bytecode = [2]c.Bytecode{ undefined, undefined };
//         c.operands_make_load_immediate_long(@ptrCast(&bytecode), c.cubsValueTagInt, 0, @bitCast(@as(i64, -1234567890)));

//         c.cubs_interpreter_push_frame(1, null, null, null);
//         defer c.cubs_interpreter_pop_frame();

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
//         try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == -1234567890);
//     }
//     { // float
//         var bytecode = [2]c.Bytecode{ undefined, undefined };
//         c.operands_make_load_immediate_long(@ptrCast(&bytecode), c.cubsValueTagFloat, 0, @bitCast(@as(f64, -0.123456789)));

//         c.cubs_interpreter_push_frame(1, null, null, null);
//         defer c.cubs_interpreter_pop_frame();

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_FLOAT_CONTEXT);
//         try expect(@as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == -0.123456789);
//     }
// }

// test "load default" {
//     c.cubs_interpreter_push_frame(10, null, null, null);
//     defer c.cubs_interpreter_pop_frame();
//     { // bool
//         var bytecode: c.Bytecode = undefined;
//         c.operands_make_load_default(&bytecode, c.cubsValueTagBool, 0, null, null);

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_BOOL_CONTEXT);
//         try expect(@as(*bool, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == false);
//     }
//     { // int
//         var bytecode: c.Bytecode = undefined;
//         c.operands_make_load_default(&bytecode, c.cubsValueTagInt, 0, null, null);

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_INT_CONTEXT);
//         try expect(@as(*i64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 0);
//     }
//     { // float
//         var bytecode: c.Bytecode = undefined;
//         c.operands_make_load_default(&bytecode, c.cubsValueTagFloat, 0, null, null);

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_FLOAT_CONTEXT);
//         try expect(@as(*f64, @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)))).* == 0.0);
//     }
//     { // string
//         var bytecode: c.Bytecode = undefined;
//         c.operands_make_load_default(&bytecode, c.cubsValueTagString, 0, null, null);

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_STRING_CONTEXT);
//         const string: *c.CubsString = @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)));
//         try expect(string.len == 0);
//         try expect(c.cubs_string_eql_slice(string, c.CubsStringSlice{ .str = "".ptr, .len = "".len }));
//     }
// }

// test "load clone" {
//     c.cubs_interpreter_push_frame(10, null, null, null);
//     defer c.cubs_interpreter_pop_frame();
//     {
//         var bytecode = [3]c.Bytecode{ undefined, undefined, undefined };

//         var immediateString = c.cubs_string_init_unchecked(.{ .str = "hello world!".ptr, .len = "hello world!".len });
//         defer c.cubs_string_deinit(&immediateString);

//         c.operands_make_load_clone_from_ptr(&bytecode, 0, @ptrCast(&immediateString), &c.CUBS_STRING_CONTEXT);

//         c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
//         try expect(c.cubs_interpreter_execute_operation(null) == 0);

//         try expect(c.cubs_interpreter_stack_context_at(0) == &c.CUBS_STRING_CONTEXT);
//         const stackString: *c.CubsString = @ptrCast(@alignCast(c.cubs_interpreter_stack_value_at(0)));
//         try expect(stackString.len == "hello world!".len);
//         try expect(c.cubs_string_eql(stackString, &immediateString));

//         c.cubs_string_deinit(stackString);
//     }
// }

test "add dst int" {
    c.cubs_interpreter_push_frame(3, null, null, null);
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
