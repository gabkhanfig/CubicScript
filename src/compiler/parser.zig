const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("compiler/parser.h");
});

const ParserIter = c.ParserIter;
const Token = c.Token;

fn parserIterInit(s: []const u8) ParserIter {
    const slice = c.CubsStringSlice{ .str = s.ptr, .len = s.len };
    return c.cubs_parser_iter_init(slice);
}

fn parserIterNext(self: *ParserIter) Token {
    return c.cubs_parser_iter_next(self);
}

fn parserIterPeek(self: ParserIter) Token {
    return c.cubs_parser_iter_peek(&self);
}

test "parse nothing" {
    var parser = parserIterInit("");

    try expect(parserIterPeek(parser) == c.TOKEN_NONE);
    try expect(parserIterNext(&parser) == c.TOKEN_NONE);
}

test "parse keyword const" {
    var parser = parserIterInit("const");

    try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
    try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

    try expect(parserIterPeek(parser) == c.TOKEN_NONE);
    try expect(parserIterNext(&parser) == c.TOKEN_NONE);
}
