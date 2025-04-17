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
    @cInclude("primitives/reference/reference.h");
    @cInclude("primitives/sync_ptr/sync_ptr.h");
});

const TokenIter = c.TokenIter;
const Token = c.Token;

fn tokenIterInit(s: []const u8) TokenIter {
    const slice = c.CubsStringSlice{ .str = s.ptr, .len = s.len };
    return c.cubs_token_iter_init(std.mem.zeroes(c.CubsStringSlice), slice);
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
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);
}

test "function no args no return no statement compile" {
    const source = "fn testFunc() {}";
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);
}

test "function no args no return 1 return statement compile" {
    const source = "fn testFunc() { return; }";
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);
}

test "function no args int return 1 return statement compile" {
    const source = "fn testFunc() int { return 5; }";
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

        const tokenIter = tokenIterInit(source);
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

        const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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

    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
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
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

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

test "two functions one calls the other" {
    const source =
        \\fn testFunc1() {
        \\  testFunc2();
        \\}
        \\fn testFunc2() {}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

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

test "two functions returning a returned value" {
    const source =
        \\fn testFunc1() int {
        \\  return testFunc2();
        \\}
        \\fn testFunc2() int { return 5; }
    ;
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc1")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 5);
    } else {
        try expect(false);
    }

    if (findFunction(&program, "testFunc2")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 5);
    } else {
        try expect(false);
    }
}

test "function calling another with one arg" {
    const source =
        \\fn testFunc1() int {
        \\  return testFunc2(6);
        \\}
        \\fn testFunc2(arg: int) int { return arg + 5; }
    ;
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc1")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 11);
    } else {
        try expect(false);
    }

    if (findFunction(&program, "testFunc2")) |func| {
        var call = c.cubs_function_start_call(&func);
        var arg: i64 = 2;
        c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_INT_CONTEXT);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 7);
    } else {
        try expect(false);
    }
}

test "function calling another with two args" {
    const source =
        \\fn testFunc1() int {
        \\  const testVar: int = 10;
        \\  return testFunc2(testVar, 6);
        \\}
        \\fn testFunc2(arg1: int, arg2: int) int { 
        \\  const testVar: int = arg1 + 5;
        \\  return testVar + arg2; 
        \\}
    ;
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc1")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 21);
    } else {
        try expect(false);
    }

    if (findFunction(&program, "testFunc2")) |func| {
        var call = c.cubs_function_start_call(&func);
        var arg1: i64 = 2;
        var arg2: i64 = 4;
        c.cubs_function_push_arg(&call, @ptrCast(&arg1), &c.CUBS_INT_CONTEXT);
        c.cubs_function_push_arg(&call, @ptrCast(&arg2), &c.CUBS_INT_CONTEXT);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 11);
    } else {
        try expect(false);
    }
}

test "function take immutable reference" {
    const source =
        \\fn testFunc(arg: &int) int {
        \\  return arg + 5;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);
        const argValue: i64 = 2;
        var arg: c.CubsConstRef = .{ .ref = @ptrCast(&argValue), .context = &c.CUBS_INT_CONTEXT };
        c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_CONST_REF_CONTEXT);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 7);
    } else {
        try expect(false);
    }
}

test "function modify mutable reference" {
    const source =
        \\fn testFunc(arg: &mut int) {
        \\  arg = 5;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);
        var argValue: i64 = 2;
        var arg: c.CubsMutRef = .{ .ref = @ptrCast(&argValue), .context = &c.CUBS_INT_CONTEXT };
        c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_MUT_REF_CONTEXT);

        try expect(c.cubs_function_call(call, .{}) == 0);
        try expect(argValue == 5);
    } else {
        try expect(false);
    }
}

test "function create immutable reference within script" {
    const source =
        \\fn testFunc1() int {
        \\  const testVar: int = 10;
        \\  return testFunc2(&testVar);
        \\}
        \\fn testFunc2(arg: &int) int { 
        \\  return arg + 5; 
        \\}
    ;
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc1")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 15);
    } else {
        try expect(false);
    }
}

test "function create mutable reference within script" {
    const source =
        \\fn testFunc1() int {
        \\  mut testVar: int = 10;
        \\  testFunc2(&mut testVar);
        \\  return testVar;
        \\}
        \\fn testFunc2(arg: &mut int) { 
        \\  arg = 20; 
        \\}
    ;
    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc1")) |func| {
        const call = c.cubs_function_start_call(&func);
        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 20);
    } else {
        try expect(false);
    }
}

test "function take struct" {
    const source =
        \\struct TestStruct {
        \\  num: int;
        \\};
        \\
        \\fn testFunc(arg: TestStruct) {
        \\  return;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    const TestStruct = extern struct { num: i64 };
    const testStructContext = &c.CubsTypeContext{
        .name = "TestStruct".ptr,
        .nameLength = "TestStruct".len,
        .members = &[1]c.CubsTypeMemberContext{c.CubsTypeMemberContext{
            .name = c.CubsStringSlice{ .str = "num".ptr, .len = 3 },
            .byteOffset = 0,
            .context = &c.CUBS_INT_CONTEXT,
        }},
        .membersLen = 1,
        .sizeOfType = @sizeOf(TestStruct),
    };

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);

        var arg = TestStruct{ .num = 85 };
        c.cubs_function_push_arg(&call, @ptrCast(&arg), testStructContext);
        try expect(c.cubs_function_call(call, .{}) == 0);
    } else {
        try expect(false);
    }
}

test "function access struct member" {
    const source =
        \\struct TestStruct {
        \\  num: int;
        \\};
        \\
        \\fn testFunc(arg: TestStruct) int {
        \\  return arg.num;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    const TestStruct = extern struct { num: i64 };
    const testStructContext: *const c.CubsTypeContext = c.cubs_program_find_type_context(&program, .{ .str = "TestStruct".ptr, .len = "TestStruct".len }).?;

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);

        var arg = TestStruct{ .num = 85 };
        c.cubs_function_push_arg(&call, @ptrCast(&arg), testStructContext);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retContext == &c.CUBS_INT_CONTEXT);
        try expect(retValue == 85);
    } else {
        try expect(false);
    }
}

test "function access nested struct member" {
    const source =
        \\struct TestStruct1 {
        \\  num: int;
        \\};
        \\
        \\struct TestStruct2 {
        \\  a: TestStruct1;
        \\};
        \\
        \\fn testFunc(arg: TestStruct2) int {
        \\  return arg.a.num;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    const TestStruct = extern struct { num: i64 };
    const testStructContext: *const c.CubsTypeContext = c.cubs_program_find_type_context(&program, .{ .str = "TestStruct2".ptr, .len = "TestStruct2".len }).?;

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);

        var arg = TestStruct{ .num = 85 };
        c.cubs_function_push_arg(&call, @ptrCast(&arg), testStructContext);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retContext == &c.CUBS_INT_CONTEXT);
        try expect(retValue == 85);
    } else {
        try expect(false);
    }
}

test "function assign to struct member" {
    const source =
        \\struct TestStruct {
        \\  num: int;
        \\};
        \\
        \\fn testFunc(arg: TestStruct) int {
        \\  arg.num = 98;
        \\  return arg.num;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    const TestStruct = extern struct { num: i64 };
    const testStructContext: *const c.CubsTypeContext = c.cubs_program_find_type_context(&program, .{ .str = "TestStruct".ptr, .len = "TestStruct".len }).?;

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);

        var arg = TestStruct{ .num = 85 };
        c.cubs_function_push_arg(&call, @ptrCast(&arg), testStructContext);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retContext == &c.CUBS_INT_CONTEXT);
        try expect(retValue == 98);
    } else {
        try expect(false);
    }
}

test "function assign to nested struct member" {
    const source =
        \\struct TestStruct1 {
        \\  num: int;
        \\};
        \\
        \\struct TestStruct2 {
        \\  a: TestStruct1;
        \\};
        \\
        \\fn testFunc(arg: TestStruct2) int {
        \\  arg.a.num = 98;
        \\  return arg.a.num;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    const TestStruct2 = extern struct { a: extern struct { num: i64 } };
    const testStructContext: *const c.CubsTypeContext = c.cubs_program_find_type_context(&program, .{ .str = "TestStruct2".ptr, .len = "TestStruct2".len }).?;

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);

        var arg = TestStruct2{ .a = .{ .num = 85 } };
        c.cubs_function_push_arg(&call, @ptrCast(&arg), testStructContext);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retContext == &c.CUBS_INT_CONTEXT);
        try expect(retValue == 98);
    } else {
        try expect(false);
    }
}

test "function sync ptr type declaration" {
    { // unique
        const source =
            \\fn testFunc(testVar: unique int) {}
        ;

        const tokenIter = tokenIterInit(source);
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var ast = c.cubs_ast_init(tokenIter, &program);
        defer c.cubs_ast_deinit(&ast);

        c.cubs_ast_codegen(&ast);

        if (findFunction(&program, "testFunc")) |func| {
            var call = c.cubs_function_start_call(&func);

            var num: i64 = 10;
            var arg = c.cubs_unique_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);
            c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_UNIQUE_CONTEXT);

            try expect(c.cubs_function_call(call, .{}) == 0);
        } else {
            try expect(false);
        }
    }
    { // shared
        const source =
            \\fn testFunc(testVar: shared int) {}
        ;

        const tokenIter = tokenIterInit(source);
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var ast = c.cubs_ast_init(tokenIter, &program);
        defer c.cubs_ast_deinit(&ast);

        c.cubs_ast_codegen(&ast);

        if (findFunction(&program, "testFunc")) |func| {
            var call = c.cubs_function_start_call(&func);

            var num: i64 = 10;
            var arg = c.cubs_shared_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);
            c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_SHARED_CONTEXT);

            try expect(c.cubs_function_call(call, .{}) == 0);
        } else {
            try expect(false);
        }
    }
    { // weak
        const source =
            \\fn testFunc(testVar: shared int) {}
        ;

        const tokenIter = tokenIterInit(source);
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var ast = c.cubs_ast_init(tokenIter, &program);
        defer c.cubs_ast_deinit(&ast);

        c.cubs_ast_codegen(&ast);

        if (findFunction(&program, "testFunc")) |func| {
            var call = c.cubs_function_start_call(&func);

            var num: i64 = 10;
            var u = c.cubs_unique_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);
            defer c.cubs_unique_deinit(&u);
            var arg = c.cubs_unique_make_weak(&u);
            c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_WEAK_CONTEXT);

            try expect(c.cubs_function_call(call, .{}) == 0);
        } else {
            try expect(false);
        }
    }
}

test "function sync" {
    { // read-only
        const source =
            \\fn testFunc(testVar: unique int) {
            \\  sync testVar {}
            \\}
        ;

        const tokenIter = tokenIterInit(source);
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var ast = c.cubs_ast_init(tokenIter, &program);
        defer c.cubs_ast_deinit(&ast);

        c.cubs_ast_codegen(&ast);

        if (findFunction(&program, "testFunc")) |func| {
            var call = c.cubs_function_start_call(&func);

            var num: i64 = 10;
            var arg = c.cubs_unique_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);
            c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_UNIQUE_CONTEXT);

            try expect(c.cubs_function_call(call, .{}) == 0);
        } else {
            try expect(false);
        }
    }
    { // read-write
        const source =
            \\fn testFunc(testVar: unique int) {
            \\  sync mut testVar {}
            \\}
        ;

        const tokenIter = tokenIterInit(source);
        var program = c.cubs_program_init(.{});
        defer c.cubs_program_deinit(&program);

        var ast = c.cubs_ast_init(tokenIter, &program);
        defer c.cubs_ast_deinit(&ast);

        c.cubs_ast_codegen(&ast);

        if (findFunction(&program, "testFunc")) |func| {
            var call = c.cubs_function_start_call(&func);

            var num: i64 = 10;
            var arg = c.cubs_unique_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);
            c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_UNIQUE_CONTEXT);

            try expect(c.cubs_function_call(call, .{}) == 0);
        } else {
            try expect(false);
        }
    }
}

test "function write sync" {
    const source =
        \\fn testFunc(testVar: shared int) {
        \\  sync mut testVar {
        \\      testVar = 800;
        \\  }
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);

        var num: i64 = 10;
        var arg = c.cubs_shared_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);
        var clone = c.cubs_shared_clone(&arg);
        defer c.cubs_shared_deinit(&clone);

        c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_SHARED_CONTEXT);

        try expect(c.cubs_function_call(call, .{}) == 0);
        try expect(@as(*const i64, @ptrCast(@alignCast(c.cubs_shared_get(&clone)))).* == 800);
    } else {
        try expect(false);
    }
}

test "function read sync" {
    const source =
        \\fn testFunc(testVar: unique int) int {
        \\  mut val: int = 0;
        \\  sync testVar {
        \\      val = testVar;
        \\  }
        \\  return val;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
    var program = c.cubs_program_init(.{});
    defer c.cubs_program_deinit(&program);

    var ast = c.cubs_ast_init(tokenIter, &program);
    defer c.cubs_ast_deinit(&ast);

    c.cubs_ast_codegen(&ast);

    if (findFunction(&program, "testFunc")) |func| {
        var call = c.cubs_function_start_call(&func);

        var num: i64 = 10;
        var arg = c.cubs_unique_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);

        c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_UNIQUE_CONTEXT);

        var retValue: i64 = undefined;
        var retContext: *const c.CubsTypeContext = undefined;
        try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
        try expect(retValue == 10);
    } else {
        try expect(false);
    }
}

test "sync multithread" {
    const ScriptExec = struct {
        fn run(shared: *c.CubsShared) void {
            const source =
                \\fn testFunc(testVar: shared int) {
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\      testVar = testVar + 1;
                \\  }
                \\}
            ;

            const tokenIter = tokenIterInit(source);
            var program = c.cubs_program_init(.{});
            defer c.cubs_program_deinit(&program);

            var ast = c.cubs_ast_init(tokenIter, &program);
            defer c.cubs_ast_deinit(&ast);

            c.cubs_ast_codegen(&ast);

            if (findFunction(&program, "testFunc")) |func| {
                var call = c.cubs_function_start_call(&func);
                var arg = c.cubs_shared_clone(shared);
                c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_SHARED_CONTEXT);

                expect(c.cubs_function_call(call, .{}) == 0) catch unreachable;
            } else {
                expect(false) catch unreachable;
            }
        }
    };

    var num: i64 = 10;
    var sharedPtr = c.cubs_shared_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);
    defer c.cubs_shared_deinit(&sharedPtr);

    const t1 = std.Thread.spawn(.{}, ScriptExec.run, .{&sharedPtr}) catch unreachable;
    const t2 = std.Thread.spawn(.{}, ScriptExec.run, .{&sharedPtr}) catch unreachable;

    ScriptExec.run(&sharedPtr);

    t1.join();
    t2.join();

    // Runs 3 times.
    try expect(@as(*const i64, @ptrCast(@alignCast(c.cubs_shared_get(&sharedPtr)))).* == 40);
}

test "multiple sync/unsync multithread" {
    const ScriptExec = struct {
        fn run(shared: *c.CubsShared) void {
            const source =
                \\fn testFunc(testVar: shared int) {
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\  sync mut testVar {
                \\      testVar = testVar + 1;
                \\  }
                \\}
            ;

            const tokenIter = tokenIterInit(source);
            var program = c.cubs_program_init(.{});
            defer c.cubs_program_deinit(&program);

            var ast = c.cubs_ast_init(tokenIter, &program);
            defer c.cubs_ast_deinit(&ast);

            c.cubs_ast_codegen(&ast);

            if (findFunction(&program, "testFunc")) |func| {
                var call = c.cubs_function_start_call(&func);
                var arg = c.cubs_shared_clone(shared);
                c.cubs_function_push_arg(&call, @ptrCast(&arg), &c.CUBS_SHARED_CONTEXT);

                expect(c.cubs_function_call(call, .{}) == 0) catch unreachable;
            } else {
                expect(false) catch unreachable;
            }
        }
    };

    var num: i64 = 10;
    var sharedPtr = c.cubs_shared_init(@ptrCast(&num), &c.CUBS_INT_CONTEXT);
    defer c.cubs_shared_deinit(&sharedPtr);

    const t1 = std.Thread.spawn(.{}, ScriptExec.run, .{&sharedPtr}) catch unreachable;
    const t2 = std.Thread.spawn(.{}, ScriptExec.run, .{&sharedPtr}) catch unreachable;

    ScriptExec.run(&sharedPtr);

    t1.join();
    t2.join();

    // Runs 3 times.
    try expect(@as(*const i64, @ptrCast(@alignCast(c.cubs_shared_get(&sharedPtr)))).* == 40);
}

test "binary expression not equal" {
    const source =
        \\  fn testFunc(arg: int) int { 
        \\  if(arg != 5) {
        \\      return 10;
        \\  }
        \\  return 20;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
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
            try expect(retValue == 20);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 6;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
    } else {
        try expect(false);
    }
}

test "binary expression less" {
    const source =
        \\  fn testFunc(arg: int) int { 
        \\  if(arg < 5) {
        \\      return 10;
        \\  }
        \\  return 20;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
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
            try expect(retValue == 20);
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
            var arg: i64 = 4;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
    } else {
        try expect(false);
    }
}

test "binary expression less or equal" {
    const source =
        \\  fn testFunc(arg: int) int { 
        \\  if(arg <= 5) {
        \\      return 10;
        \\  }
        \\  return 20;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
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
            var arg: i64 = 4;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
    } else {
        try expect(false);
    }
}

test "binary expression greater" {
    const source =
        \\  fn testFunc(arg: int) int { 
        \\  if(arg > 5) {
        \\      return 10;
        \\  }
        \\  return 20;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
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
            try expect(retValue == 20);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 6;
            c.cubs_function_push_arg(&call, &arg, &c.CUBS_INT_CONTEXT);

            var retValue: i64 = undefined;
            var retContext: *const c.CubsTypeContext = undefined;
            try expect(c.cubs_function_call(call, .{ .value = &retValue, .context = @ptrCast(&retContext) }) == 0);
            try expect(retValue == 10);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 4;
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

test "binary expression greater or equal" {
    const source =
        \\  fn testFunc(arg: int) int { 
        \\  if(arg >= 5) {
        \\      return 10;
        \\  }
        \\  return 20;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
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
            try expect(retValue == 10);
        }
        {
            var call = c.cubs_function_start_call(&func);
            var arg: i64 = 4;
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

test "while loop" {
    const source =
        \\  fn testFunc() int {
        \\  mut i: int = 0;
        \\  while(i < 8) {
        \\      i = i + 1;
        \\  }
        \\  return i;
        \\}
    ;

    const tokenIter = tokenIterInit(source);
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
        try expect(retValue == 8);
    } else {
        try expect(false);
    }
}
