const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/stack.h");
});

test "push frame no return" {
    c.cubs_interpreter_push_frame_non_stack_return(1, null, null, null);
    defer c.cubs_interpreter_pop_frame();

    const frame = c.cubs_interpreter_current_stack_frame();
    try expect(frame.frameLength == 1);
    try expect(frame.basePointerOffset == 0);
}

test "nested push frame" {
    c.cubs_interpreter_push_frame_non_stack_return(100, null, null, null);
    defer c.cubs_interpreter_pop_frame();

    {
        const frame = c.cubs_interpreter_current_stack_frame();
        try expect(frame.frameLength == 100);
        try expect(frame.basePointerOffset == 0);
    }

    c.cubs_interpreter_push_frame_non_stack_return(100, null, null, null);
    defer c.cubs_interpreter_pop_frame();

    {
        const frame = c.cubs_interpreter_current_stack_frame();
        try expect(frame.frameLength == 100);
        try expect(frame.basePointerOffset == (100 + 5));
    }
}
