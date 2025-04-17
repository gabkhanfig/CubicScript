const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("compiler/parse/tokenizer.h");
});

const TokenIter = c.TokenIter;
const TokenType = c.TokenType;

fn tokenIterInit(s: []const u8) TokenIter {
    const slice = c.CubsStringSlice{ .str = s.ptr, .len = s.len };
    return c.cubs_token_iter_init(std.mem.zeroes(c.CubsStringSlice), slice);
}

fn tokenIterInitName(name: []const u8, s: []const u8) TokenIter {
    const slice = c.CubsStringSlice{ .str = s.ptr, .len = s.len };
    const n = c.CubsStringSlice{ .str = name.ptr, .len = name.len };
    return c.cubs_token_iter_init(n, slice);
}

fn tokenIterNext(self: *TokenIter) TokenType {
    return c.cubs_token_iter_next(self);
}

test "parse nothing" {
    var parser = tokenIterInit("");

    try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
}

test "parse keyword const" {
    var parser = tokenIterInit("const");

    try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

    try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
}

test "parse keyword const with whitespace characters" {
    { // space
        var parser = tokenIterInit(" const");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // tab
        var parser = tokenIterInit("   const");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // tab sanity
        var parser = tokenIterInit("\tconst");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // new line
        var parser = tokenIterInit("\nconst");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // CRLF
        var parser = tokenIterInit("\r\nconst");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple spaces
        var parser = tokenIterInit("  const");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple tabs
        const s = "       const";
        var parser = tokenIterInit(s);

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple tabs sanity
        var parser = tokenIterInit("\t\tconst");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple new line
        var parser = tokenIterInit("\n\nconst");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // multiple CRLF
        var parser = tokenIterInit("\r\n\r\nconst");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
    { // combination
        var parser = tokenIterInit(" \t\n \r\n\r\n \n \t const");

        try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

        try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
    }
}

test "parse const with characters after" {
    { // valid token
        { // space
            var parser = tokenIterInit("const ");

            try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

            try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
        }
        { // new line
            var parser = tokenIterInit("const\n");

            try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

            try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
        }
        { // tab
            var parser = tokenIterInit("const\t");

            try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);

            try expect(tokenIterNext(&parser) == c.TOKEN_NONE);
        }
        { // carriage return
            var parser = tokenIterInit("const\r");

            try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // comma
            var parser = tokenIterInit("const,");

            try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // period
            var parser = tokenIterInit("const.");

            try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);
        }
        { // semicolon
            var parser = tokenIterInit("const;");

            try expect(tokenIterNext(&parser) == c.CONST_KEYWORD);
        }
    }
    { // invalid token
        var parser = tokenIterInit("constt");

        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
    }
}

fn validateParseKeyword(comptime s: []const u8, comptime token: c_int) void {
    { // normal
        var parser = tokenIterInit(s);

        expect(tokenIterNext(&parser) == token) catch unreachable;

        expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
    }
    { // whitespace before
        { // space
            var parser = tokenIterInit(" " ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab
            var parser = tokenIterInit("   " ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab sanity
            var parser = tokenIterInit("\t" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // new line
            var parser = tokenIterInit("\n" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // CRLF
            var parser = tokenIterInit("\r\n" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple spaces
            var parser = tokenIterInit("  " ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs
            const str = "       " ++ s;
            var parser = tokenIterInit(str);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs sanity
            var parser = tokenIterInit("\t\t" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple new line
            var parser = tokenIterInit("\n\n" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple CRLF
            var parser = tokenIterInit("\r\n\r\n" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // combination
            var parser = tokenIterInit(" \t\n \r\n\r\n \n \t " ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
    }
    { // characters after
        { // valid token
            { // space
                var parser = tokenIterInit(s ++ " ");

                expect(tokenIterNext(&parser) == token) catch unreachable;

                expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // new line
                var parser = tokenIterInit(s ++ "\n");

                expect(tokenIterNext(&parser) == token) catch unreachable;

                expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // tab
                var parser = tokenIterInit(s ++ "\t");

                expect(tokenIterNext(&parser) == token) catch unreachable;

                expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // carriage return
                var parser = tokenIterInit(s ++ "\r");

                expect(tokenIterNext(&parser) == token) catch unreachable;
            }
            { // comma
                var parser = tokenIterInit(s ++ ",");

                expect(tokenIterNext(&parser) == token) catch unreachable;
            }
            { // period
                var parser = tokenIterInit(s ++ ".");

                expect(tokenIterNext(&parser) == token) catch unreachable;
            }
            { // semicolon
                var parser = tokenIterInit(s ++ ";");

                expect(tokenIterNext(&parser) == token) catch unreachable;
            }
        }
        { // invalid token
            var parser = tokenIterInit(s ++ "t");

            expect(tokenIterNext(&parser) == c.IDENTIFIER) catch unreachable;
        }
    }
}

fn validateParseOperatorOrSymbol(comptime s: []const u8, comptime token: c_int) void {
    { // normal
        var parser = tokenIterInit(s);

        expect(tokenIterNext(&parser) == token) catch unreachable;

        expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
    }
    { // whitespace before
        { // space
            var parser = tokenIterInit(" " ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab
            var parser = tokenIterInit("   " ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // tab sanity
            var parser = tokenIterInit("\t" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // new line
            var parser = tokenIterInit("\n" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // CRLF
            var parser = tokenIterInit("\r\n" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple spaces
            var parser = tokenIterInit("  " ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs
            const str = "       " ++ s;
            var parser = tokenIterInit(str);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple tabs sanity
            var parser = tokenIterInit("\t\t" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple new line
            var parser = tokenIterInit("\n\n" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // multiple CRLF
            var parser = tokenIterInit("\r\n\r\n" ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
        { // combination
            var parser = tokenIterInit(" \t\n \r\n\r\n \n \t " ++ s);

            expect(tokenIterNext(&parser) == token) catch unreachable;

            expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
        }
    }
    { // characters after
        { // valid token
            { // space
                var parser = tokenIterInit(s ++ " ");

                expect(tokenIterNext(&parser) == token) catch unreachable;

                expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // new line
                var parser = tokenIterInit(s ++ "\n");

                expect(tokenIterNext(&parser) == token) catch unreachable;

                expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // tab
                var parser = tokenIterInit(s ++ "\t");

                expect(tokenIterNext(&parser) == token) catch unreachable;

                expect(tokenIterNext(&parser) == c.TOKEN_NONE) catch unreachable;
            }
            { // carriage return
                var parser = tokenIterInit(s ++ "\r");

                expect(tokenIterNext(&parser) == token) catch unreachable;
            }
            { // comma
                var parser = tokenIterInit(s ++ ",");

                expect(tokenIterNext(&parser) == token) catch unreachable;
            }
            { // period
                var parser = tokenIterInit(s ++ ".");

                expect(tokenIterNext(&parser) == token) catch unreachable;
            }
            { // semicolon
                var parser = tokenIterInit(s ++ ";");

                expect(tokenIterNext(&parser) == token) catch unreachable;
            }
            { // invalid token
                // For keywords and symbols, a character after could be part of an identifier or keyword, making this fine
                var parser = tokenIterInit(s ++ "t");

                expect(tokenIterNext(&parser) == token) catch unreachable;
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

test "string" {
    validateParseKeyword("string", c.STRING_KEYWORD);
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

test "null" {
    validateParseKeyword("null", c.NULL_KEYWORD);
}

test "unique" {
    validateParseKeyword("unique", c.UNIQUE_KEYWORD);
}

test "shared" {
    validateParseKeyword("shared", c.SHARED_KEYWORD);
}

test "weak" {
    validateParseKeyword("weak", c.WEAK_KEYWORD);
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

test "colon" {
    validateParseOperatorOrSymbol(":", c.COLON_SYMBOL);
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
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{} ", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{}\n", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{}\t", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, " {}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "\n{}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "\t{}", .{num}) catch unreachable,
            );
        }

        fn validateParse(num: i64, buf: []const u8) void {
            var parser = tokenIterInit(buf);
            expect(tokenIterNext(&parser) == c.INT_LITERAL) catch unreachable;
            expect(parser.current.value.intLiteral == num) catch unreachable;
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

test "float literal" {
    const Validate = struct {
        fn wholeWithPointZero(num: f64) void {
            std.debug.assert(num == @floor(num));

            var buf: [256]u8 = undefined;

            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{d:.1}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{d:.1} ", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{d:.1}\n", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{d:.1}\t", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, " {d:.1}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "\n{d:.1}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "\t{d:.1}", .{num}) catch unreachable,
            );
        }

        fn decimal(num: f64) void {
            var buf: [1080]u8 = undefined;

            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{d}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{d} ", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{d}\n", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "{d}\t", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, " {d}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "\n{d}", .{num}) catch unreachable,
            );
            validateParse(
                num,
                std.fmt.bufPrintZ(&buf, "\t{d}", .{num}) catch unreachable,
            );
        }

        fn validateParse(num: f64, buf: []const u8) void {
            var parser = tokenIterInit(buf);
            const nextToken = tokenIterNext(&parser);
            if (nextToken == c.INT_LITERAL) {
                std.debug.assert(num == @floor(num));
                expect(num == @as(f64, @floatFromInt(parser.current.value.intLiteral))) catch unreachable;
            } else {
                expect(nextToken == c.FLOAT_LITERAL) catch unreachable;
                expect(std.math.approxEqRel(f64, num, parser.current.value.floatLiteral, std.math.floatEps(f64))) catch {
                    std.debug.panic("invalid decimal equal: found num {d} and parsed {d}\n", .{ num, parser.current.value.floatLiteral });
                };
            }
        }
    };
    { // whole numbers
        { // single digit
            for (0..10) |i| {
                Validate.wholeWithPointZero(@floatFromInt(i));
            }
        }
        { // double digits
            for (10..100) |i| {
                Validate.wholeWithPointZero(@floatFromInt(i));
            }
        }
        { // many digits
            var i: i64 = 128;
            for (0..40) |_| {
                Validate.wholeWithPointZero(@floatFromInt(i));
                i <<= 1;
            }
        }
        { // negative single digit
            var i: i64 = -9;
            for (0..10) |_| {
                Validate.wholeWithPointZero(@floatFromInt(i));
                i += 1;
            }
        }
        { // negative double digits
            var i: i64 = -99;
            for (0..90) |_| {
                Validate.wholeWithPointZero(@floatFromInt(i));
                i += 1;
            }
        }
        { // negative many digits
            var i: i64 = -128;
            for (0..40) |_| {
                Validate.wholeWithPointZero(@floatFromInt(i));
                i *= 2;
            }
        }
        { // max int 64
            Validate.wholeWithPointZero(@floatFromInt(std.math.maxInt(i64)));
        }
        { // min int 64
            Validate.wholeWithPointZero(@floatFromInt(std.math.minInt(i64)));
        }
        { // random extreme whole numbers
            Validate.wholeWithPointZero(12345678901234567890123.0);
            Validate.wholeWithPointZero(-12345678901234567890123.0);
            Validate.wholeWithPointZero(40387460187246018726450187365017624971826587.0);
            Validate.wholeWithPointZero(-40387460187246018726450187365017624971826587.0);
        }
    }
    { // decimal numbers
        { // 1 digit decimals
            var i: f64 = 0.5;
            for (0..100) |_| {
                Validate.decimal(i);
                i += 1.0;
            }
        }
        { // many decimals, and outside of 64 bit int range
            var i: f64 = 0.1234567;
            for (0..65) |_| {
                Validate.decimal(i);
                i *= 2.3;
            }
        }
        { // negatives
            var i: f64 = -0.1325741;
            for (0..65) |_| {
                Validate.decimal(i);
                i *= 2.3;
            }
        }
        { // random extreme decimal numbers
            Validate.decimal(12345678901234567890123.269487162031287332986);
            Validate.decimal(-12345678901234567890123.269487162031287332986);
            Validate.decimal(40387460187246018726450187365017624971826587.1273670238975601874263);
            Validate.decimal(-40387460187246018726450187365017624971826587.1273670238975601874263);
        }
    }
}

test "fail parse int literal invalid character" {
    var parser = tokenIterInit("1r");
    try expect(tokenIterNext(&parser) == c.TOKEN_ERROR);
    try expect(parser.err == c.cubsSyntaxErrNumLiteralInvalidChar);
}

test "fail parse float literal many period" {
    var parser = tokenIterInit("1.0.1");
    try expect(tokenIterNext(&parser) == c.TOKEN_ERROR);
    try expect(parser.err == c.cubsSyntaxErrNumLiteralTooManyDecimal);
}

test "fail parse float literal invalid char after decimal" {
    var parser = tokenIterInit("1.0r");
    try expect(tokenIterNext(&parser) == c.TOKEN_ERROR);
    try expect(parser.err == c.cubsSyntaxErrNumLiteralInvalidChar);
}

test "parse string literal empty" {
    const s = "\"\"";
    var parser = tokenIterInit(s);
    try expect(tokenIterNext(&parser) == c.STR_LITERAL);

    {
        const foundSlice = parser.current.value.strLiteral.slice;
        try expect(foundSlice.len == 0);
    }
}

test "parse string literal alphanumeric" {
    const f = "abcdefg123416246";
    const s = "\"" ++ f ++ "\"";
    var parser = tokenIterInit(s);
    try expect(tokenIterNext(&parser) == c.STR_LITERAL);

    {
        const foundSlice = parser.current.value.strLiteral.slice;
        try expect(foundSlice.len == f.len);
        try expect(std.mem.eql(u8, foundSlice.str[0..foundSlice.len], f));
    }
}

test "parse string literal escape sequence" {
    const f = "\\n\\t\\r\\v";
    const s = "\"" ++ f ++ "\"";
    var parser = tokenIterInit(s);
    try expect(tokenIterNext(&parser) == c.STR_LITERAL);

    {
        const foundSlice = parser.current.value.strLiteral.slice;
        try expect(foundSlice.len == f.len);
        try expect(std.mem.eql(u8, foundSlice.str[0..foundSlice.len], f));
    }
}

test "fail parse string" {
    {
        const s = "\"";
        var parser = tokenIterInit(s);
        try expect(tokenIterNext(&parser) == c.TOKEN_ERROR);
        try expect(parser.err == c.cubsSyntaxErrTerminatedStringLiteral);
    }
    {
        const s = "\"a";
        var parser = tokenIterInit(s);
        try expect(tokenIterNext(&parser) == c.TOKEN_ERROR);
        try expect(parser.err == c.cubsSyntaxErrTerminatedStringLiteral);
    }
    {
        const s = "\"\\n";
        var parser = tokenIterInit(s);
        try expect(tokenIterNext(&parser) == c.TOKEN_ERROR);
        try expect(parser.err == c.cubsSyntaxErrTerminatedStringLiteral);
    }
}

test "parse identifier" {
    {
        const identifier = "a";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
        try expect(std.mem.eql(u8, identifier, parser.current.value.identifier.str[0..parser.current.value.identifier.len]));
    }
    {
        const identifier = "hello";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
        try expect(std.mem.eql(u8, identifier, parser.current.value.identifier.str[0..parser.current.value.identifier.len]));
    }
    {
        const identifier = "b6";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
        try expect(std.mem.eql(u8, identifier, parser.current.value.identifier.str[0..parser.current.value.identifier.len]));
    }
    {
        const identifier = "h3llo";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
        try expect(std.mem.eql(u8, identifier, parser.current.value.identifier.str[0..parser.current.value.identifier.len]));
    }
    {
        const identifier = "HELLO";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
        try expect(std.mem.eql(u8, identifier, parser.current.value.identifier.str[0..parser.current.value.identifier.len]));
    }
    {
        const identifier = "_whoa";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
        try expect(std.mem.eql(u8, identifier, parser.current.value.identifier.str[0..parser.current.value.identifier.len]));
    }
    {
        const identifier = "_1sur3";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
        try expect(std.mem.eql(u8, identifier, parser.current.value.identifier.str[0..parser.current.value.identifier.len]));
    }
    {
        const identifier = "GOOD_MORNING";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) == c.IDENTIFIER);
        try expect(std.mem.eql(u8, identifier, parser.current.value.identifier.str[0..parser.current.value.identifier.len]));
    }
    {
        const identifier = "3llo";
        var parser = tokenIterInit(identifier);
        try expect(tokenIterNext(&parser) != c.IDENTIFIER);
    }
}
