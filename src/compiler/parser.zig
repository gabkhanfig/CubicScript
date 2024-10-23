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

test "parse keyword const with whitespace characters" {
    { // space
        var parser = parserIterInit(" const");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // tab
        var parser = parserIterInit("   const");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // tab sanity
        var parser = parserIterInit("\tconst");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // new line
        var parser = parserIterInit("\nconst");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // CRLF
        var parser = parserIterInit("\r\nconst");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple spaces
        var parser = parserIterInit("  const");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple tabs
        const s = "       const";
        var parser = parserIterInit(s);

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        std.debug.print("found peek token {}\n", .{parserIterPeek(parser)});

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple tabs sanity
        var parser = parserIterInit("\t\tconst");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple new line
        var parser = parserIterInit("\n\nconst");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple CRLF
        var parser = parserIterInit("\r\n\r\nconst");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // combination
        var parser = parserIterInit(" \t\n \r\n\r\n \n \t const");

        try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
}
