const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/stack.h");
});

test "push frame no return" {
    c.cubs_interpreter_push_frame_non_stack_return(1, null, null, null);
    defer c.cubs_interpreter_pop_frame();
}

test "nested push frame" {
    c.cubs_interpreter_push_frame_non_stack_return(100, null, null, null);
    defer c.cubs_interpreter_pop_frame();

    c.cubs_interpreter_push_frame_non_stack_return(100, null, null, null);
    defer c.cubs_interpreter_pop_frame();
}
