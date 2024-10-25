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

test "parse const with characters after" {
    { // valid token
        { // space
            var parser = parserIterInit("const ");

            try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

            try expect(parserIterPeek(parser) == c.TOKEN_NONE);
            try expect(parserIterNext(&parser) == c.TOKEN_NONE);
        }
        { // new line
            var parser = parserIterInit("const\n");

            try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

            try expect(parserIterPeek(parser) == c.TOKEN_NONE);
            try expect(parserIterNext(&parser) == c.TOKEN_NONE);
        }
        { // tab
            var parser = parserIterInit("const\t");

            try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

            try expect(parserIterPeek(parser) == c.TOKEN_NONE);
            try expect(parserIterNext(&parser) == c.TOKEN_NONE);
        }
        { // carriage return
            var parser = parserIterInit("const\r");

            try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // comma
            var parser = parserIterInit("const,");

            try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // period
            var parser = parserIterInit("const.");

            try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // semicolon
            var parser = parserIterInit("const;");

            try expect(parserIterPeek(parser) == c.CONST_KEYWORD);
            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);
        }
    }
    { // invalid token
        var parser = parserIterInit("constt");

        try expect(parserIterPeek(parser) == c.TOKEN_NONE);
        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
}

fn validateParseKeyword(comptime s: []const u8, comptime token: c_int) void {
    { // normal
        var parser = parserIterInit(s);

        expect(parserIterPeek(parser) == token) catch unreachable;
        expect(parserIterNext(&parser) == token) catch unreachable;

        expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
        expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
    }
    { // whitespace before
        { // space
            var parser = parserIterInit(" " ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab
            var parser = parserIterInit("   " ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab sanity
            var parser = parserIterInit("\t" ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // new line
            var parser = parserIterInit("\n" ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // CRLF
            var parser = parserIterInit("\r\n" ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple spaces
            var parser = parserIterInit("  " ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs
            const str = "       " ++ s;
            var parser = parserIterInit(str);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs sanity
            var parser = parserIterInit("\t\t" ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple new line
            var parser = parserIterInit("\n\n" ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple CRLF
            var parser = parserIterInit("\r\n\r\n" ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // combination
            var parser = parserIterInit(" \t\n \r\n\r\n \n \t " ++ s);

            expect(parserIterPeek(parser) == token) catch unreachable;
            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
    }
    { // characters after
        { // valid token
            { // space
                var parser = parserIterInit(s ++ " ");

                expect(parserIterPeek(parser) == token) catch unreachable;
                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // new line
                var parser = parserIterInit(s ++ "\n");

                expect(parserIterPeek(parser) == token) catch unreachable;
                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // tab
                var parser = parserIterInit(s ++ "\t");

                expect(parserIterPeek(parser) == token) catch unreachable;
                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // carriage return
                var parser = parserIterInit(s ++ "\r");

                expect(parserIterPeek(parser) == token) catch unreachable;
                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // comma
                var parser = parserIterInit(s ++ ",");

                expect(parserIterPeek(parser) == token) catch unreachable;
                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // period
                var parser = parserIterInit(s ++ ".");

                expect(parserIterPeek(parser) == token) catch unreachable;
                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // semicolon
                var parser = parserIterInit(s ++ ";");

                expect(parserIterPeek(parser) == token) catch unreachable;
                expect(parserIterNext(&parser) == token) catch unreachable;
            }
        }
        { // invalid token
            var parser = parserIterInit(s ++ "t");

            expect(parserIterPeek(parser) == c.TOKEN_NONE) catch unreachable;
            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
    }
}

test "mut" {
    validateParseKeyword("mut", c.MUT_KEYWORD);
}

test "return" {
    validateParseKeyword("return", c.RETURN_KEYWORD);
}

test "fn" {
    validateParseKeyword("fn", c.FN_KEYWORD);
}

test "pub" {
    validateParseKeyword("pub", c.PUB_KEYWORD);
}

test "if" {
    validateParseKeyword("if", c.IF_KEYWORD);
}

test "else" {
    validateParseKeyword("else", c.ELSE_KEYWORD);
}

test "switch" {
    validateParseKeyword("switch", c.SWITCH_KEYWORD);
}

test "while" {
    validateParseKeyword("while", c.WHILE_KEYWORD);
}

test "for" {
    validateParseKeyword("for", c.FOR_KEYWORD);
}

test "break" {
    validateParseKeyword("break", c.BREAK_KEYWORD);
}

test "continue" {
    validateParseKeyword("continue", c.CONTINUE_KEYWORD);
}

test "struct" {
    validateParseKeyword("struct", c.STRUCT_KEYWORD);
}

test "interface" {
    validateParseKeyword("interface", c.INTERFACE_KEYWORD);
}

test "enum" {
    validateParseKeyword("enum", c.ENUM_KEYWORD);
}

test "union" {
    validateParseKeyword("union", c.UNION_KEYWORD);
}

test "sync" {
    validateParseKeyword("sync", c.SYNC_KEYWORD);
}

test "unsafe" {
    validateParseKeyword("unsafe", c.UNSAFE_KEYWORD);
}

test "true" {
    validateParseKeyword("true", c.TRUE_KEYWORD);
}

test "false" {
    validateParseKeyword("false", c.FALSE_KEYWORD);
}

test "bool" {
    validateParseKeyword("bool", c.BOOL_KEYWORD);
}

test "int" {
    validateParseKeyword("int", c.INT_KEYWORD);
}

test "float" {
    validateParseKeyword("float", c.FLOAT_KEYWORD);
}

test "str" {
    validateParseKeyword("str", c.STR_KEYWORD);
}

test "char" {
    validateParseKeyword("char", c.CHAR_KEYWORD);
}

test "import" {
    validateParseKeyword("import", c.IMPORT_KEYWORD);
}

test "mod" {
    validateParseKeyword("mod", c.MOD_KEYWORD);
}

test "and" {
    validateParseKeyword("and", c.AND_KEYWORD);
}

test "or" {
    validateParseKeyword("or", c.OR_KEYWORD);
}
