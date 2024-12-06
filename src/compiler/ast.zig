const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("program/program.h");
    @cInclude("program/program_internal.h");
    @cInclude("compiler/tokenizer.h");
    @cInclude("compiler/ast.h");
    @cInclude("compiler/ast_nodes/file_node.h");
    @cInclude("compiler/ast_nodes/function_node.h");
    @cInclude("compiler/ast_nodes/return_node.h");
});

const TokenIter = c.TokenIter;
const Token = c.Token;

fn tokenIterInit(s: []const u8, errCallback: c.CubsSyntaxErrorCallback) TokenIter {
    const slice = c.CubsStringSlice{ .str = s.ptr, .len = s.len };
    return c.cubs_token_iter_init(std.mem.zeroes(c.CubsStringSlice), slice, errCallback);
}

fn findFunction(program: *const c.CubsProgram, name: []const u8) ?c.CubsFunction {
    const slice = c.CubsStringSlice{ .str = name.ptr, .len = name.len };
    var func: c.CubsFunction = undefined;
    if (c.cubs_program_find_function(program, &func, slice)) {
        return func;
    }
    return null;
}

test "function no args no return no statement ast init" {
    const source = "fn testFunc() {}";
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);
}

test "function no args no return no statement compile" {
    const source = "fn testFunc() {}";
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        _ = func;
    } else {
        try expect(false);
    }
}

test "function no args no return no statement run" {
    const source = "fn testFunc() {}";
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        try expect(c.cubs_function_call(call, .{}) == 0);
    } else {
        try expect(false);
    }
}
