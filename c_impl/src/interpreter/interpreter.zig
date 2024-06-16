const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/interpreter.h");
    @cInclude("interpreter/stack.h");
    @cInclude("interpreter/bytecode.h");
});

test "nop" {
    c.cubs_interpreter_push_frame(1, null, null, null);

    const bytecode = [_]c.Bytecode{
        c.cubs_bytecode_encode(c.OpCodeNop, null),
    };
    c.cubs_interpreter_set_instruction_pointer(@ptrCast(&bytecode));
    const result = c.cubs_interpreter_execute_operation(null);
    try expect(result == 0);
}
