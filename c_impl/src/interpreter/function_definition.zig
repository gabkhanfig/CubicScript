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
