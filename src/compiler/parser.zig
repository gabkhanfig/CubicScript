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

test "parse nothing" {
    var parser = parserIterInit("");

    try expect(parserIterNext(&parser) == c.TOKEN_NONE);
}

test "parse keyword const" {
    var parser = parserIterInit("const");

    try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

    try expect(parserIterNext(&parser) == c.TOKEN_NONE);
}

test "parse keyword const with whitespace characters" {
    { // space
        var parser = parserIterInit(" const");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // tab
        var parser = parserIterInit("   const");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // tab sanity
        var parser = parserIterInit("\tconst");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // new line
        var parser = parserIterInit("\nconst");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // CRLF
        var parser = parserIterInit("\r\nconst");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple spaces
        var parser = parserIterInit("  const");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple tabs
        const s = "       const";
        var parser = parserIterInit(s);

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple tabs sanity
        var parser = parserIterInit("\t\tconst");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple new line
        var parser = parserIterInit("\n\nconst");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple CRLF
        var parser = parserIterInit("\r\n\r\nconst");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
    { // combination
        var parser = parserIterInit(" \t\n \r\n\r\n \n \t const");

        try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
}

test "parse const with characters after" {
    { // valid token
        { // space
            var parser = parserIterInit("const ");

            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

            try expect(parserIterNext(&parser) == c.TOKEN_NONE);
        }
        { // new line
            var parser = parserIterInit("const\n");

            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

            try expect(parserIterNext(&parser) == c.TOKEN_NONE);
        }
        { // tab
            var parser = parserIterInit("const\t");

            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);

            try expect(parserIterNext(&parser) == c.TOKEN_NONE);
        }
        { // carriage return
            var parser = parserIterInit("const\r");

            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // comma
            var parser = parserIterInit("const,");

            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // period
            var parser = parserIterInit("const.");

            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // semicolon
            var parser = parserIterInit("const;");

            try expect(parserIterNext(&parser) == c.CONST_KEYWORD);
        }
    }
    { // invalid token
        var parser = parserIterInit("constt");

        try expect(parserIterNext(&parser) == c.TOKEN_NONE);
    }
}

fn validateParseKeyword(comptime s: []const u8, comptime token: c_int) void {
    { // normal
        var parser = parserIterInit(s);

        expect(parserIterNext(&parser) == token) catch unreachable;

        expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
    }
    { // whitespace before
        { // space
            var parser = parserIterInit(" " ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab
            var parser = parserIterInit("   " ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab sanity
            var parser = parserIterInit("\t" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // new line
            var parser = parserIterInit("\n" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // CRLF
            var parser = parserIterInit("\r\n" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple spaces
            var parser = parserIterInit("  " ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs
            const str = "       " ++ s;
            var parser = parserIterInit(str);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs sanity
            var parser = parserIterInit("\t\t" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple new line
            var parser = parserIterInit("\n\n" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple CRLF
            var parser = parserIterInit("\r\n\r\n" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // combination
            var parser = parserIterInit(" \t\n \r\n\r\n \n \t " ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
    }
    { // characters after
        { // valid token
            { // space
                var parser = parserIterInit(s ++ " ");

                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // new line
                var parser = parserIterInit(s ++ "\n");

                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // tab
                var parser = parserIterInit(s ++ "\t");

                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // carriage return
                var parser = parserIterInit(s ++ "\r");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // comma
                var parser = parserIterInit(s ++ ",");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // period
                var parser = parserIterInit(s ++ ".");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // semicolon
                var parser = parserIterInit(s ++ ";");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
        }
        { // invalid token
            var parser = parserIterInit(s ++ "t");

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
    }
}

fn validateParseOperatorOrSymbol(comptime s: []const u8, comptime token: c_int) void {
    { // normal
        var parser = parserIterInit(s);

        expect(parserIterNext(&parser) == token) catch unreachable;

        expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
    }
    { // whitespace before
        { // space
            var parser = parserIterInit(" " ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab
            var parser = parserIterInit("   " ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab sanity
            var parser = parserIterInit("\t" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // new line
            var parser = parserIterInit("\n" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // CRLF
            var parser = parserIterInit("\r\n" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple spaces
            var parser = parserIterInit("  " ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs
            const str = "       " ++ s;
            var parser = parserIterInit(str);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs sanity
            var parser = parserIterInit("\t\t" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple new line
            var parser = parserIterInit("\n\n" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple CRLF
            var parser = parserIterInit("\r\n\r\n" ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // combination
            var parser = parserIterInit(" \t\n \r\n\r\n \n \t " ++ s);

            expect(parserIterNext(&parser) == token) catch unreachable;

            expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
    }
    { // characters after
        { // valid token
            { // space
                var parser = parserIterInit(s ++ " ");

                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // new line
                var parser = parserIterInit(s ++ "\n");

                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // tab
                var parser = parserIterInit(s ++ "\t");

                expect(parserIterNext(&parser) == token) catch unreachable;

                expect(parserIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // carriage return
                var parser = parserIterInit(s ++ "\r");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // comma
                var parser = parserIterInit(s ++ ",");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // period
                var parser = parserIterInit(s ++ ".");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // semicolon
                var parser = parserIterInit(s ++ ";");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
            { // invalid token
                // For keywords and symbols, a character after could be part of an identifier or keyword, making this fine
                var parser = parserIterInit(s ++ "t");

                expect(parserIterNext(&parser) == token) catch unreachable;
            }
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

test "extern" {
    validateParseKeyword("extern", c.EXTERN_KEYWORD);
}

test "and" {
    validateParseKeyword("and", c.AND_KEYWORD);
}

test "or" {
    validateParseKeyword("or", c.OR_KEYWORD);
}

test "equal" {
    validateParseOperatorOrSymbol("==", c.EQUAL_OPERATOR);
}

test "assign" {
    validateParseOperatorOrSymbol("=", c.ASSIGN_OPERATOR);
}

test "not equal" {
    validateParseOperatorOrSymbol("!=", c.NOT_EQUAL_OPERATOR);
}

test "not" {
    validateParseOperatorOrSymbol("!", c.NOT_OPERATOR);
}

test "less equal" {
    validateParseOperatorOrSymbol("<=", c.LESS_EQUAL_OPERATOR);
}

test "less" {
    validateParseOperatorOrSymbol("<", c.LESS_OPERATOR);
}

test "greater equal" {
    validateParseOperatorOrSymbol(">=", c.GREATER_EQUAL_OPERATOR);
}

test "greater" {
    validateParseOperatorOrSymbol(">", c.GREATER_OPERATOR);
}

test "add assign" {
    validateParseOperatorOrSymbol("+=", c.ADD_ASSIGN_OPERATOR);
}

test "add" {
    validateParseOperatorOrSymbol("+", c.ADD_OPERATOR);
}

test "subtract assign" {
    validateParseOperatorOrSymbol("-=", c.SUBTRACT_ASSIGN_OPERATOR);
}

// Special case with number literals
// test "subtract" {
//     validateParseOperatorOrSymbol("-", c.SUBTRACT_OPERATOR);
// }

test "multiply assign" {
    validateParseOperatorOrSymbol("*=", c.MULTIPLY_ASSIGN_OPERATOR);
}

test "divide assign" {
    validateParseOperatorOrSymbol("/=", c.DIVIDE_ASSIGN_OPERATOR);
}

test "divide" {
    validateParseOperatorOrSymbol("/", c.DIVIDE_OPERATOR);
}

test "bitshift left assign" {
    validateParseOperatorOrSymbol("<<=", c.BITSHIFT_LEFT_ASSIGN_OPERATOR);
}

test "bitshift left" {
    validateParseOperatorOrSymbol("<<", c.BITSHIFT_LEFT_OPERATOR);
}

test "bitshift right assign" {
    validateParseOperatorOrSymbol(">>=", c.BITSHIFT_RIGHT_ASSIGN_OPERATOR);
}

test "bitshift right" {
    validateParseOperatorOrSymbol(">>", c.BITSHIFT_RIGHT_OPERATOR);
}

test "bit not" {
    validateParseOperatorOrSymbol("~", c.BIT_COMPLEMENT_OPERATOR);
}

test "bit or assign" {
    validateParseOperatorOrSymbol("|=", c.BIT_OR_ASSIGN_OPERATOR);
}

test "bit or" {
    validateParseOperatorOrSymbol("|", c.BIT_OR_OPERATOR);
}

test "bit and assign" {
    validateParseOperatorOrSymbol("&=", c.BIT_AND_ASSIGN_OPERATOR);
}

test "bit xor assign" {
    validateParseOperatorOrSymbol("^=", c.BIT_XOR_ASSIGN_OPERATOR);
}

test "bit xor" {
    validateParseOperatorOrSymbol("^", c.BIT_XOR_OPERATOR);
}

test "left parentheses" {
    validateParseOperatorOrSymbol("(", c.LEFT_PARENTHESES_SYMBOL);
}

test "right parentheses" {
    validateParseOperatorOrSymbol(")", c.RIGHT_PARENTHESES_SYMBOL);
}

test "left bracket" {
    validateParseOperatorOrSymbol("[", c.LEFT_BRACKET_SYMBOL);
}

test "right bracket" {
    validateParseOperatorOrSymbol("]", c.RIGHT_BRACKET_SYMBOL);
}

test "left brace" {
    validateParseOperatorOrSymbol("{", c.LEFT_BRACE_SYMBOL);
}

test "right brace" {
    validateParseOperatorOrSymbol("}", c.RIGHT_BRACE_SYMBOL);
}

test "semicolon" {
    validateParseOperatorOrSymbol(";", c.SEMICOLON_SYMBOL);
}

test "period" {
    validateParseOperatorOrSymbol(".", c.PERIOD_SYMBOL);
}

test "comma" {
    validateParseOperatorOrSymbol(",", c.COMMA_SYMBOL);
}

// This test is a weird one because the symbol "&" is ambiguous.
// Whether it means a reference or bit-and is contextual.
// Bit-and requires specific tokens prior to it, so reference should work fine.
test "reference" {
    validateParseOperatorOrSymbol("&", c.REFERENCE_SYMBOL);
}

// This test is a weird one because the symbol "*" is ambiguous.
// Whether it means a pointer or multiply is contextual.
// Bit-and requires specific tokens prior to it, so reference should work fine.
test "pointer" {
    validateParseOperatorOrSymbol("*", c.POINTER_SYMBOL);
}

test "int literal" {
    const Validate = struct {
        fn int(num: i64) void {
            var buf: [24]u8 = undefined;
            _ = std.fmt.bufPrintZ(&buf, "{}", .{num}) catch unreachable;

            var parser = parserIterInit(&buf);
            expect(parserIterNext(&parser) == c.INT_LITERAL) catch unreachable;
            expect(parser.currentMetadata.intLiteral == num) catch unreachable;
        }
    };
    { // single digit
        for (0..10) |i| {
            Validate.int(@intCast(i));
        }
    }
    { // double digits
        for (10..100) |i| {
            Validate.int(@intCast(i));
        }
    }
    { // many digits
        var i: i64 = 128;
        for (0..40) |_| {
            Validate.int(@intCast(i));
            i <<= 1;
        }
    }
    { // negative single digit
        var i: i64 = -9;
        for (0..10) |_| {
            Validate.int(@intCast(i));
            i += 1;
        }
    }
    { // negative double digits
        var i: i64 = -99;
        for (0..90) |_| {
            Validate.int(@intCast(i));
            i += 1;
        }
    }
    { // negative many digits
        var i: i64 = -128;
        for (0..40) |_| {
            Validate.int(@intCast(i));
            i *= 2;
        }
    }
    { // max int 64
        Validate.int(std.math.maxInt(i64));
    }
    { // min int 64
        Validate.int(std.math.minInt(i64));
    }
}
