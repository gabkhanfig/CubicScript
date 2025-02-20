const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("program/program.h");
    @cInclude("program/program_internal.h");
    @cInclude("compiler/parse/tokenizer.h");
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

fn findStructContext(program: *const c.CubsProgram, name: []const u8) ?*const c.CubsTypeContext {
    const slice = c.CubsStringSlice{ .str = name.ptr, .len = name.len };
    const found = c.cubs_program_find_type_context(program, slice);
    return @ptrCast(found);
}

fn contextNameIs(context: *const c.CubsTypeContext, name: []const u8) bool {
    return std.mem.eql(u8, context.name[0..context.nameLength], name);
}

fn memberContextNameIs(member: *const c.CubsTypeMemberContext, name: []const u8) bool {
    return std.mem.eql(u8, member.name.str[0..member.name.len], name);
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

test "function no args no return 1 return statement" {
    const source = "fn testFunc() { return; }";
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);
}

test "function no args no return 1 return statement compile" {
    const source = "fn testFunc() { return; }";
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

test "function no args no return 1 return statement run" {
    const source = "fn testFunc() { return; }";
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

test "function no args int return 1 return statement" {
    const source = "fn testFunc() int { return 5; }";
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);
}

test "function no args int return 1 return statement compile" {
    const source = "fn testFunc() int { return 5; }";
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

test "function no args int return 1 return statement run" {
    const source = "fn testFunc() int { return 5; }";
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 5);
    } else {
        try expect(false);
    }
}

test "function 1 arg no return no statement ast" {
    const source = "fn testFunc(arg: int) {}";
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);
        var arg: i64 = 10;
        c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);
        try expect(c.cubs_function_call(call, .{}) == 0);
    } else {
        try expect(false);
    }
}

test "function 1 arg 1 return ast" {
    const source = "fn testFunc(arg: int) int { return arg; }";
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);

        const desiredValue: i64 = 10;

        var arg: i64 = desiredValue;
        c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);

        try expect(retValue == desiredValue);
    } else {
        try expect(false);
    }
}

test "function no arg no return 1 mut variable declaration" {
    const source = "fn testFunc() { mut testVar: int; }";
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

test "function no arg no return 1 const variable declaration" {
    const source = "fn testFunc() { const testVar: int; }";
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

test "function no arg no return 1 mut variable declaration with initial value" {
    const source = "fn testFunc() { mut testVar: int = 6; }";
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

test "function no arg no return 1 const variable declaration with initial value" {
    const source = "fn testFunc() { const testVar: int = 6; }";
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

test "function no arg no return 2 statements variable declaration" {
    const source =
        \\fn testFunc() { 
        \\  const testVar1: int;
        \\  mut testVar2: int;
        \\}
    ;
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

test "function no args int 2 statement return stack variable" {
    const source =
        \\fn testFunc() int { 
        \\  const testVar: int = 5;
        \\  return testVar;
        \\}
    ;
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 5);
    } else {
        try expect(false);
    }
}

test "function no args one add binary expression" {
    const source =
        \\fn testFunc() int { 
        \\  const testVar: int = 1 + 5;
        \\  return testVar;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 6);
    } else {
        try expect(false);
    }
}

test "function return binary expression" {
    const source =
        \\fn testFunc() int { 
        \\  return 4 + 5;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 9);
    } else {
        try expect(false);
    }
}

test "simple struct" {
    const source =
        \\ struct testStruct {
        \\  someVar: int;
        \\};
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findStructContext(&program, "testStruct")) |found| {
        try expect(found.sizeOfType == 8);
        try expect(found.nameLength == 10);
        try expect(contextNameIs(found, "testStruct"));
        try expect(found.membersLen == 1);

        const member = found.members[0];
        try expect(member.byteOffset == 0);
        try expect(member.context == &c.CUBS_INT_CONTEXT);
        try expect(member.name.len == 7);
        try expect(memberContextNameIs(&member, "someVar"));
    } else {
        try expect(false);
    }
}

test "struct two member both int" {
    const source =
        \\ struct testStruct {
        \\  num1: int;
        \\  num2: int;
        \\};
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findStructContext(&program, "testStruct")) |found| {
        try expect(found.sizeOfType == 16);
        try expect(found.nameLength == 10);
        try expect(contextNameIs(found, "testStruct"));
        try expect(found.membersLen == 2);

        const member1 = found.members[0];
        try expect(member1.byteOffset == 0);
        try expect(member1.context == &c.CUBS_INT_CONTEXT);
        try expect(member1.name.len == 4);
        try expect(memberContextNameIs(&member1, "num1"));

        const member2 = found.members[1];
        try expect(member2.byteOffset == 8);
        try expect(member2.context == &c.CUBS_INT_CONTEXT);
        try expect(member2.name.len == 4);
        try expect(memberContextNameIs(&member2, "num2"));
    } else {
        try expect(false);
    }
}

test "bool false" {
    const source =
        \\fn testFunc() bool { 
        \\  const testVar: bool = false;
        \\  return testVar;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: bool = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retContext == &c.CUBS_BOOL_CONTEXT);
        try expect(retValue == false);
    } else {
        try expect(false);
    }
}

test "bool true" {
    const source =
        \\fn testFunc() bool { 
        \\  const testVar: bool = true;
        \\  return testVar;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: bool = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retContext == &c.CUBS_BOOL_CONTEXT);
        try expect(retValue == true);
    } else {
        try expect(false);
    }
}

test "if true no else with return" {
    const source =
        \\fn testFunc() int { 
        \\  if(true) {
        \\      return 10;
        \\  }
        \\  return 50;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 10);
    } else {
        try expect(false);
    }
}

test "if false no else with return" {
    const source =
        \\fn testFunc() int { 
        \\  if(false) {
        \\      return 10;
        \\  }
        \\  return 50;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 50);
    } else {
        try expect(false);
    }
}

test "if no else with user argument" {
    const source =
        \\fn testFunc(arg: bool) int { 
        \\  if(arg) {
        \\      return 10;
        \\  }
        \\  return 50;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        {
            var call = c.cubs_function_start_call(&func);
            var arg: bool = true;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_BOOL_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: bool = false;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_BOOL_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 50);
        }
    } else {
        try expect(false);
    }
}

test "equality operator true simple" {
    const source =
        \\fn testFunc() bool { 
        \\  return 1 == 1;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: bool = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retContext == &c.CUBS_BOOL_CONTEXT);
        try expect(retValue == true);
    } else {
        try expect(false);
    }
}

test "equality operator false simple" {
    const source =
        \\fn testFunc() bool { 
        \\  return 1 == 2;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: bool = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retContext == &c.CUBS_BOOL_CONTEXT);
        try expect(retValue == false);
    } else {
        try expect(false);
    }
}

test "equality operator in if statement" {
    {
        const source =
            \\fn testFunc() int {
            \\  if(1 == 1) {
            \\      return 10;
            \\  }
            \\  return 50;
            \\}
        ;

        const tokenIter = tokenIterInit(source, null);
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var ast = c.cubs_ast_init(tokenIter, &program);
        defer c.cubs_ast_deinit(&ast);

        c.cubs_ast_codegen(&ast);
        if (findFunction(&program, "testFunc")) |func| {
            const call = c.cubs_function_start_call(&func);
            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        } else {
            try expect(false);
        }
    }
    {
        const source =
            \\fn testFunc() int {
            \\  if(1 == 2) {
            \\      return 10;
            \\  }
            \\  return 50;
            \\}
        ;

        const tokenIter = tokenIterInit(source, null);
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var ast = c.cubs_ast_init(tokenIter, &program);
        defer c.cubs_ast_deinit(&ast);

        c.cubs_ast_codegen(&ast);
        if (findFunction(&program, "testFunc")) |func| {
            const call = c.cubs_function_start_call(&func);
            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 50);
        } else {
            try expect(false);
        }
    }
}

test "equality operator int in if statement" {
    const source =
        \\fn testFunc(arg: int) int { 
        \\  if(arg == 5) {
        \\      return 10;
        \\  }
        \\  return 50;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 5;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 6;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 50);
        }
    } else {
        try expect(false);
    }
}

test "if with else if" {
    const source =
        \\  fn testFunc(arg: int) int { 
        \\  if(arg == 5) {
        \\      return 10;
        \\  } else if(arg == 6) {
        \\      return 20;
        \\  }
        \\  return 50;
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 5;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 6;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 20);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 7;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 50);
        }
    } else {
        try expect(false);
    }
}

test "if with else" {
    const source =
        \\  fn testFunc(arg: int) int { 
        \\  if(arg == 5) {
        \\      return 10;
        \\  } else {
        \\      return 20;
        \\  }
        \\}
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 5;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 6;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 20);
        }
    } else {
        try expect(false);
    }
}

test "if/else if/else" {
    const source =
        \\  fn testFunc(arg: int) int { 
        \\      if(arg == 5) {
        \\          return 10;
        \\      } else if(arg == 6) {
        \\          return 20;
        \\      } else {
        \\          return 50;
        \\      }
        \\  }
    ;

    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 5;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 6;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 20);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 7;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 50);
        }
    } else {
        try expect(false);
    }
}

test "assign variable simple" {
    const source =
        \\fn testFunc() int { 
        \\  mut testVar: int = 1;
        \\  testVar = 2;
        \\  return testVar;
        \\}
    ;
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);
    if (findFunction(&program, "testFunc")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 2);
    } else {
        try expect(false);
    }
}

test "two functions" {
    const source =
        \\fn testFunc1() {}
        \\fn testFunc2() {}
    ;
    const tokenIter = tokenIterInit(source, null);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    std.debug.print("hmjj\n", .{});

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc1")) |func| {
        const call = c.cubs_function_start_call(&func);
        try expect(c.cubs_function_call(call, .{}) == 0);
    } else {
        try expect(false);
    }

    if (findFunction(&program, "testFunc2")) |func| {
        const call = c.cubs_function_start_call(&func);
        try expect(c.cubs_function_call(call, .{}) == 0);
    } else {
        try expect(false);
    }
}
