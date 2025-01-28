#include "tokenizer.h"
#include <assert.h>
#include <stdio.h>
#include "../util/math.h"
#include "../platform/mem.h"
#include "../util/unreachable.h"

// TODO figure out fast way to get the token.
// Could look at SIMD, or hashing, or even 8 byte compare if all tokens (not identifiers)
// are smaller than 8 bytes in length

// TODO handle comments when parsing

typedef struct NextToken {
    bool hasNextToken;
    Token next;
    CubsSourceFileCharPosition newPosition;
} NextToken;

static bool is_space(char c) {
    // https://www.geeksforgeeks.org/isspace-in-c/
    // no need to include whole header
    return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r';
}

static bool is_alphabetic_or_underscore(char c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c == '_');
}

/// @param currentPos 
/// @param start Beginning of string
/// @param end Inclusive
static CubsSourceFileCharPosition get_updated_position(CubsSourceFileCharPosition currentPos, const char* start, size_t end) { 
    CubsSourceFileCharPosition newPos = currentPos;
    newPos.index += end;
    for(size_t i = 0; i <= end; i++) {
        const char c = start[i];
        assert(c != '\0');

        if(c == '\n') {
            newPos.line += 1;
            newPos.column = 1;
        }
        // TODO figure out to handle tab widths?
        else if(c == '\t') {
            newPos.column += 4;
        } else {
            newPos.column += 1;
        }
    }
    return newPos;
}

/// Checks if `source` starts with `find`.
static bool starts_with_keyword_substring(const CubsStringSlice source, const CubsStringSlice find) {
    size_t i = 0;
    for(; i < find.len; i++) {
        if(source.len <= i) {
            return false;
        }
        if(source.str[i] != find.str[i]) {
            return false;
        }
    }
    if(source.len <= i) {
        return true; // end of source, thus no tokens are after
    } else {
        const char charAfterToken = source.str[i];
        if(is_space(charAfterToken) || charAfterToken == ','|| charAfterToken == '.'|| charAfterToken == ';'
            || charAfterToken == '(' || charAfterToken == ')') // TODO other bracket ones as well?
        {
            return true;
        } else {
            return false;
        }
    }
}

/// Checks if `source` starts with `find`.
static bool starts_with_operator_or_symbol_substring(const CubsStringSlice source, const CubsStringSlice find) {
    size_t i = 0;
    for(; i < find.len; i++) {
        if(source.len <= i) {
            return false;
        }
        if(source.str[i] != find.str[i]) {
            return false;
        }
    }
    // Unlike in `starts_with_keyword_substring`, operators and symbols can have whatever characters afterwards
    return true;
}

/// Skips over any whitespace or newlines. Returns an empty slice if there is no token start from the iters
/// current position within the source string slice.
static CubsStringSlice get_next_token_start_slice(const TokenIter* self, size_t* outOffset) {
    const CubsStringSlice tempStart = {
        .str = &self->source.str[self->position.index], 
        .len = self->source.len - self->position.index
    };
    size_t i = 0;
    for(; i < tempStart.len; i++) {
        const char c = tempStart.str[i];
        if(is_space(c)) {
            continue;
        }

        const CubsStringSlice tokenStart = {
            .str = &tempStart.str[i], 
            .len = tempStart.len - i,
        };
        *outOffset = i;
        return tokenStart;
    }

    const CubsStringSlice empty = {
        .str = NULL, 
        .len = 0
    };
    return empty;
}

typedef struct TokenLiteralOrIdentifier {
    TokenType token;
    CubsStringSlice slice;
    TokenMetadata metadata;
} TokenLiteralOrIdentifier;

static TokenLiteralOrIdentifier try_parse_num_literal(const TokenIter* self, const CubsSourceFileCharPosition pos, const CubsStringSlice tokenStart) {
    const TokenLiteralOrIdentifier emptyTokenLiteralOrIdentifier = {0};
    
    const bool isNegative = tokenStart.str[0] == '-';
    bool isFloat = false;
    /// If not a decimal number, this will simply be the integer part.
    int64_t wholePartInt = 0;
    double wholePartFloat = 0;

    size_t i = (size_t)isNegative;

    bool isDecimal = false;

    // Max and Min
    // 9223372036854775807
    // -9223372036854775808

    while(true) {
        const char c = tokenStart.str[i];
        if(c >= '0' && c <= '9') {
            int64_t num = (int64_t)(c - '0');
            if(isFloat) {
                wholePartFloat *= 10;
                wholePartFloat += (double)num;
            } else {
                if(wholePartInt == 922337203685477580LL && c == '8' ) { // skip one digit for min int
                    wholePartInt = INT64_MIN;
                } else {
                    if(cubs_math_would_mul_overflow(wholePartInt, 10)) {
                        isFloat = true;
                        wholePartFloat = (double)wholePartInt;
                        wholePartFloat += num;
                        continue;
                    }
                    wholePartInt *= 10; 
                    if(cubs_math_would_add_overflow(wholePartInt, num)) {
                        isFloat = true;
                        wholePartFloat = (double)wholePartInt;
                        wholePartFloat += num;
                    } else {
                        wholePartInt += num;
                    }         
                }
            }       
        } else if(c == '.') {
            isDecimal = true;
            break;
        } else if(is_space(c) || c == '\0' || c == ';' || c == ',') {
            break;
        } else {
            const CubsSourceFileCharPosition errPos = get_updated_position(pos, tokenStart.str, i);
            self->errCallback(cubsSyntaxErrNumLiteralInvalidChar, self->name, self->source, errPos);
            return emptyTokenLiteralOrIdentifier;
        }
        i++;
    }

    if(isNegative && !isFloat && wholePartInt != INT64_MIN) {
        wholePartInt *= -1;    
    }

    if(!isDecimal) {
        const CubsStringSlice literalSlice = {.str = tokenStart.str, .len = i};
        if(isFloat) {
            double actualFloatNum = wholePartFloat;
            if(isNegative) {
                actualFloatNum *= -1.0;
            }
            const TokenMetadata metadata = {.floatLiteral = actualFloatNum};
            const TokenLiteralOrIdentifier outToken = {.token = FLOAT_LITERAL, .slice = literalSlice, .metadata = metadata};
            return outToken;
        } else {  
            const TokenMetadata metadata = {.intLiteral = wholePartInt};
            const TokenLiteralOrIdentifier outToken = {.token = INT_LITERAL, .slice = literalSlice, .metadata = metadata};
            return outToken;
        }
    } else {
        // found '.' character
        if(!isFloat) { // set to float
            isFloat = true;
            wholePartFloat = (double)wholePartInt;
        }
        i += 1; // skip past '.' character

        double decimalPart = 0; 
        double denominator = 1;

        while(true) {
            const char c = tokenStart.str[i];
            if(c >= '0' && c <= '9') {
                double num = (double)(c - '0');
                decimalPart *= 10.0;
                decimalPart += num;
                denominator *= 10;
            }  else if(is_space(c) || c == '\0' || c == ';' || c == ',') {
                break;
            } else if(c == '.') {
                const CubsSourceFileCharPosition errPos = get_updated_position(pos, tokenStart.str, i);
                self->errCallback(cubsSyntaxErrNumLiteralTooManyDecimal, self->name, self->source, errPos);
                return emptyTokenLiteralOrIdentifier;
            } else {
                const CubsSourceFileCharPosition errPos = get_updated_position(pos, tokenStart.str, i);
                self->errCallback(cubsSyntaxErrNumLiteralInvalidChar, self->name, self->source, errPos);
                return emptyTokenLiteralOrIdentifier;
            }
            i++;
        }
        const CubsStringSlice literalSlice = {.str = tokenStart.str, .len = i};

        const double fraction = (decimalPart / denominator);
        double actualFloatNum = wholePartFloat;
        if(actualFloatNum >= 0.0) {
            actualFloatNum += fraction;
        } else {      
            actualFloatNum -= fraction;
        }
        if(isNegative && actualFloatNum > 0.0) {
            actualFloatNum *= -1.0;
        }
        
        const TokenMetadata metadata = {.floatLiteral = actualFloatNum};
        const TokenLiteralOrIdentifier outToken = {.token = FLOAT_LITERAL, .slice = literalSlice, .metadata = metadata};
        return outToken;
    }
}

static TokenLiteralOrIdentifier try_parse_string_literal(const TokenIter* self, const CubsSourceFileCharPosition pos, const CubsStringSlice tokenStart) {
    assert(tokenStart.len > 0);
    assert(tokenStart.str[0] == '\"');
    
    const TokenLiteralOrIdentifier emptyTokenLiteralOrIdentifier = {0};
    if(tokenStart.len == 1) { // must have start and end quotation marks, which is 2 characters
        const CubsSourceFileCharPosition errPos = get_updated_position(pos, tokenStart.str, 0);
        self->errCallback(cubsSyntaxErrTerminatedStringLiteral, self->name, self->source, errPos);
        return emptyTokenLiteralOrIdentifier;
    }

    const char* start = &tokenStart.str[1];
    size_t i = 0;
    while(true) {
        if(i >= (tokenStart.len - 1)) {
            const CubsSourceFileCharPosition errPos = get_updated_position(pos, tokenStart.str, i);
            self->errCallback(cubsSyntaxErrTerminatedStringLiteral, self->name, self->source, errPos);
            return emptyTokenLiteralOrIdentifier;
        }
        const char c = start[i];
        assert(c != '\0');
        if(c == '\\') {
            i += 2; // skip past next character
        } else if(c == '\"') {
            break;
        } else {
            i += 1;
        }
    }

    const CubsStringSlice stringLiteralSlice = {.str = start, .len = i};
    const CubsStringSlice stringLiteralSliceWithQuotes = {.str = tokenStart.str, .len = i + 2};
    const TokenMetadata metadata = {.strLiteral = { stringLiteralSlice }};
    const TokenLiteralOrIdentifier outToken = {.token = STR_LITERAL, .slice = stringLiteralSliceWithQuotes, .metadata = metadata};
    return outToken;
}

static TokenLiteralOrIdentifier try_parse_identifier(const TokenIter* self, const CubsSourceFileCharPosition pos, const CubsStringSlice tokenStart) {
    assert(is_alphabetic_or_underscore(tokenStart.str[0]));
    
    size_t i = 1;
    while(true) {
        const char c = tokenStart.str[i];
        // can also have numeric characters as long as it doesn't start with it
        if(is_alphabetic_or_underscore(c) || (c >= '0' && c <= '9')) { 
            i += 1;
        } else {
            break;
        }
    }

    const CubsStringSlice identifierSlice = {.str = tokenStart.str, .len = i};
    const TokenMetadata metadata = {.identifier = identifierSlice};
    const TokenLiteralOrIdentifier outToken = {.token = IDENTIFIER, .slice = identifierSlice, .metadata = metadata};
    return outToken;
}

/// Returns `TOKEN_NONE` if cannot find anything, otherwise returns one of:
/// - `INT_LITERAL`
/// - `FLOAT_LITERAL`
/// - `CHAR_LITERAL`
/// - `STR_LITERAL`
/// - `IDENTIFIER`
/// Also stores the string slice for the token in `outSlice, and metadata in the out-param `outMetadata`.
static TokenLiteralOrIdentifier try_parse_literal_or_identifier(const TokenIter* self, const CubsSourceFileCharPosition pos, const CubsStringSlice tokenStart) {
    const TokenLiteralOrIdentifier emptyTokenLiteralOrIdentifier = {0};

    if(tokenStart.len == 0) {
        return emptyTokenLiteralOrIdentifier;
    }

    TokenType hint = TOKEN_NONE;
    { // get hint
        const char firstChar = tokenStart.str[0];
        if(firstChar == '\'') { // 
            hint = CHAR_LITERAL;
        } else if(firstChar == '\"') {
            hint = STR_LITERAL;
        } else if((firstChar >= '0' && firstChar <= '9') || firstChar == '-') { // TODO hexadecimal, binary, and maybe octal literals
            hint = INT_LITERAL; // also works for FLOAT_LITERAL
        } else if(is_alphabetic_or_underscore(firstChar)) { // TODO other language specific characters?
            hint = IDENTIFIER;
        }
    }
    if(hint == TOKEN_NONE) {
        return emptyTokenLiteralOrIdentifier;
    }

    switch(hint) {
        case CHAR_LITERAL: {
            assert(false && "char literals not yet implemented");
        } break;
        case INT_LITERAL: { // also handles float literal
            return try_parse_num_literal(self, pos, tokenStart);
        } break;
        case STR_LITERAL: {
            return try_parse_string_literal(self, pos, tokenStart);
        } break;
        case IDENTIFIER: {
            return try_parse_identifier(self, pos, tokenStart);
        }
        default: {
            return emptyTokenLiteralOrIdentifier;
        }
    }
}

#pragma region Token_Constants

// static const CubsStringSlice _KEYWORD_SLICE = {.str = "", .len = };

/// Define a static const variable named `name` as a string slice with the string content of `string`.
#define TOKEN_CONSTANT(name, string) static const CubsStringSlice name = {.str = string, .len = sizeof(string) - 1}

TOKEN_CONSTANT(CONST_KEYWORD_SLICE, "const");
TOKEN_CONSTANT(MUT_KEYWORD_SLICE, "mut");
TOKEN_CONSTANT(RETURN_KEYWORD_SLICE, "return");
TOKEN_CONSTANT(FN_KEYWORD_SLICE, "fn");
TOKEN_CONSTANT(PUB_KEYWORD_SLICE, "pub");
TOKEN_CONSTANT(IF_KEYWORD_SLICE, "if");
TOKEN_CONSTANT(ELSE_KEYWORD_SLICE, "else");
TOKEN_CONSTANT(SWITCH_KEYWORD_SLICE, "switch");
TOKEN_CONSTANT(WHILE_KEYWORD_SLICE, "while");
TOKEN_CONSTANT(FOR_KEYWORD_SLICE, "for");
TOKEN_CONSTANT(BREAK_KEYWORD_SLICE, "break");
TOKEN_CONSTANT(CONTINUE_KEYWORD_SLICE, "continue");
TOKEN_CONSTANT(STRUCT_KEYWORD_SLICE, "struct");
TOKEN_CONSTANT(INTERFACE_KEYWORD_SLICE, "interface");
TOKEN_CONSTANT(ENUM_KEYWORD_SLICE, "enum");
TOKEN_CONSTANT(UNION_KEYWORD_SLICE, "union");
TOKEN_CONSTANT(SYNC_KEYWORD_SLICE, "sync");
TOKEN_CONSTANT(UNSAFE_KEYWORD_SLICE, "unsafe");
TOKEN_CONSTANT(TRUE_KEYWORD_SLICE, "true");
TOKEN_CONSTANT(FALSE_KEYWORD_SLICE, "false");
TOKEN_CONSTANT(BOOL_KEYWORD_SLICE, "bool");
TOKEN_CONSTANT(INT_KEYWORD_SLICE, "int");
TOKEN_CONSTANT(FLOAT_KEYWORD_SLICE, "float");
TOKEN_CONSTANT(STRING_KEYWORD_SLICE, "string");
TOKEN_CONSTANT(CHAR_KEYWORD_SLICE, "char");
TOKEN_CONSTANT(IMPORT_KEYWORD_SLICE, "import");
TOKEN_CONSTANT(MOD_KEYWORD_SLICE, "mod");
TOKEN_CONSTANT(EXTERN_KEYWORD_SLICE, "extern");
TOKEN_CONSTANT(AND_KEYWORD_SLICE, "and");
TOKEN_CONSTANT(OR_KEYWORD_SLICE, "or");
TOKEN_CONSTANT(NULL_KEYWORD_SLICE, "null");

TOKEN_CONSTANT(EQUAL_OPERATOR_SLICE, "==");
TOKEN_CONSTANT(ASSIGN_OPERATOR_SLICE, "=");
TOKEN_CONSTANT(NOT_EQUAL_OPERATOR_SLICE, "!=");
TOKEN_CONSTANT(NOT_OPERATOR_SLICE, "!");
TOKEN_CONSTANT(LESS_EQUAL_OPERATOR_SLICE, "<=");
TOKEN_CONSTANT(LESS_OPERATOR_SLICE, "<");
TOKEN_CONSTANT(GREATER_EQUAL_OPERATOR_SLICE, ">=");
TOKEN_CONSTANT(GREATER_OPERATOR_SLICE, ">");
TOKEN_CONSTANT(ADD_ASSIGN_OPERATOR_SLICE, "+=");
TOKEN_CONSTANT(ADD_OPERATOR_SLICE, "+");
TOKEN_CONSTANT(SUBTRACT_ASSIGN_OPERATOR_SLICE, "-=");
TOKEN_CONSTANT(SUBTRACT_OPERATOR_SLICE, "-");
TOKEN_CONSTANT(MULTIPLY_ASSIGN_OPERATOR_SLICE, "*=");
TOKEN_CONSTANT(MULTIPLY_OPERATOR_SLICE, "*");
TOKEN_CONSTANT(DIVIDE_ASSIGN_OPERATOR_SLICE, "/=");
TOKEN_CONSTANT(DIVIDE_OPERATOR_SLICE, "/");
TOKEN_CONSTANT(BITSHIFT_LEFT_ASSIGN_OPERATOR_SLICE, "<<=");
TOKEN_CONSTANT(BITSHIFT_LEFT_OPERATOR_SLICE, "<<");
TOKEN_CONSTANT(BITSHIFT_RIGHT_ASSIGN_OPERATOR_SLICE, ">>=");
TOKEN_CONSTANT(BITSHIFT_RIGHT_OPERATOR_SLICE, ">>");
TOKEN_CONSTANT(BIT_COMPLEMENT_OPERATOR_SLICE, "~");
TOKEN_CONSTANT(BIT_OR_ASSIGN_OPERATOR_SLICE, "|=");
TOKEN_CONSTANT(BIT_OR_OPERATOR_SLICE, "|");
TOKEN_CONSTANT(BIT_AND_ASSIGN_OPERATOR_SLICE, "&=");
TOKEN_CONSTANT(BIT_AND_OPERATOR_SLICE, "&");
TOKEN_CONSTANT(BIT_XOR_ASSIGN_OPERATOR_SLICE, "^=");
TOKEN_CONSTANT(BIT_XOR_OPERATOR_SLICE, "^");

TOKEN_CONSTANT(LEFT_PARENTHESES_SYMBOL_SLICE, "(");
TOKEN_CONSTANT(RIGHT_PARENTHESES_SYMBOL_SLICE, ")");
TOKEN_CONSTANT(LEFT_BRACKET_SYMBOL_SLICE, "[");
TOKEN_CONSTANT(RIGHT_BRACKET_SYMBOL_SLICE, "]");
TOKEN_CONSTANT(LEFT_BRACE_SYMBOL_SLICE, "{");
TOKEN_CONSTANT(RIGHT_BRACE_SYMBOL_SLICE, "}");
TOKEN_CONSTANT(COLON_SYMBOL_SLICE, ":");
TOKEN_CONSTANT(SEMICOLON_SYMBOL_SLICE, ";");
TOKEN_CONSTANT(PERIOD_SYMBOL_SLICE, ".");
TOKEN_CONSTANT(COMMA_SYMBOL_SLICE, ",");
TOKEN_CONSTANT(REFERENCE_SYMBOL_SLICE, "&");
TOKEN_CONSTANT(POINTER_SYMBOL_SLICE, "*");

//! IMPORTANT NOTE
/// Both BIT_AND_OPERATOR_SLICE and REFERENCE_SYMBOL_SLICE use the same character.
/// The BIT_AND_OPERATOR can only exist after an identifier or integer literal, 
/// whereas the REFERENCE_SYMBOL_SLICE cannot exist after either.
/// Similar problem exists for MULTIPLY_OPERATOR_SLICE and POINTER_SYMBOL.
/// Multiply can only exist after an identifier, integer literal, or float literal.
/// Similarly, the opposite is true for pointer.

#pragma endregion

static NextToken get_next_token(const TokenIter* self) {
    const NextToken noneNext = {0};

    TokenType found = TOKEN_NONE;
    CubsStringSlice foundSlice = {0};
    NextToken next = {0};
    next.newPosition = self->position;
    size_t whitespaceOffset = 0;

    const TokenType previousToken = self->current.tag;

    if(self->position.index >= self->source.len) {
        return next;
    } else {
        const CubsStringSlice tokenStart = get_next_token_start_slice(self, &whitespaceOffset);
        const CubsStringSlice AMPERSAND_SLICE = {.str = "&", .len = 1};
        const CubsStringSlice ASTERISK_SLICE = {.str = "*", .len = 1};
        const CubsStringSlice MINUS_SLICE = {.str = "-", .len = 1};

        // update current char position to go past whitespace
        const CubsSourceFileCharPosition pastWhitespacePos = get_updated_position(
            self->position, 
            &self->source.str[self->position.index], 
            whitespaceOffset
        );

        // Keywords
        if(starts_with_keyword_substring(tokenStart, CONST_KEYWORD_SLICE)) {
            found = CONST_KEYWORD;
            foundSlice = CONST_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, MUT_KEYWORD_SLICE)) {
            found = MUT_KEYWORD;
            foundSlice = MUT_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, RETURN_KEYWORD_SLICE)) {
            found = RETURN_KEYWORD;
            foundSlice = RETURN_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, FN_KEYWORD_SLICE)) {
            found = FN_KEYWORD;
            foundSlice = FN_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, PUB_KEYWORD_SLICE)) {
            found = PUB_KEYWORD;
            foundSlice = PUB_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, IF_KEYWORD_SLICE)) {
            found = IF_KEYWORD;
            foundSlice = IF_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, ELSE_KEYWORD_SLICE)) {
            found = ELSE_KEYWORD;
            foundSlice = ELSE_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, SWITCH_KEYWORD_SLICE)) {
            found = SWITCH_KEYWORD;
            foundSlice = SWITCH_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, WHILE_KEYWORD_SLICE)) {
            found = WHILE_KEYWORD;
            foundSlice = WHILE_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, FOR_KEYWORD_SLICE)) {
            found = FOR_KEYWORD;
            foundSlice = FOR_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, BREAK_KEYWORD_SLICE)) {
            found = BREAK_KEYWORD;
            foundSlice = BREAK_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, CONTINUE_KEYWORD_SLICE)) {
            found = CONTINUE_KEYWORD;
            foundSlice = CONTINUE_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, STRUCT_KEYWORD_SLICE)) {
            found = STRUCT_KEYWORD;
            foundSlice = STRUCT_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, INTERFACE_KEYWORD_SLICE)) {
            found = INTERFACE_KEYWORD;
            foundSlice = INTERFACE_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, ENUM_KEYWORD_SLICE)) {
            found = ENUM_KEYWORD;
            foundSlice = ENUM_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, UNION_KEYWORD_SLICE)) {
            found = UNION_KEYWORD;
            foundSlice = UNION_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, SYNC_KEYWORD_SLICE)) {
            found = SYNC_KEYWORD;
            foundSlice = SYNC_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, UNSAFE_KEYWORD_SLICE)) {
            found = UNSAFE_KEYWORD;
            foundSlice = UNSAFE_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, TRUE_KEYWORD_SLICE)) {
            found = TRUE_KEYWORD;
            foundSlice = TRUE_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, FALSE_KEYWORD_SLICE)) {
            found = FALSE_KEYWORD;
            foundSlice = FALSE_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, BOOL_KEYWORD_SLICE)) {
            found = BOOL_KEYWORD;
            foundSlice = BOOL_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, INT_KEYWORD_SLICE)) {
            found = INT_KEYWORD;
            foundSlice = INT_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, FLOAT_KEYWORD_SLICE)) {
            found = FLOAT_KEYWORD;
            foundSlice = FLOAT_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, STRING_KEYWORD_SLICE)) {
            found = STRING_KEYWORD;
            foundSlice = STRING_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, CHAR_KEYWORD_SLICE)) {
            found = CHAR_KEYWORD;
            foundSlice = CHAR_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, IMPORT_KEYWORD_SLICE)) {
            found = IMPORT_KEYWORD;
            foundSlice = IMPORT_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, MOD_KEYWORD_SLICE)) {
            found = MOD_KEYWORD;
            foundSlice = MOD_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, EXTERN_KEYWORD_SLICE)) {
            found = EXTERN_KEYWORD;
            foundSlice = EXTERN_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, AND_KEYWORD_SLICE)) {
            found = AND_KEYWORD;
            foundSlice = AND_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, OR_KEYWORD_SLICE)) {
            found = OR_KEYWORD;
            foundSlice = OR_KEYWORD_SLICE;
        } else if(starts_with_keyword_substring(tokenStart, NULL_KEYWORD_SLICE)) {
            found = NULL_KEYWORD;
            foundSlice = NULL_KEYWORD_SLICE;
        } 
        // Operators
        // The bitshift ones must come first
        else if(starts_with_operator_or_symbol_substring(tokenStart, BITSHIFT_LEFT_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bitshift left check
            found = BITSHIFT_LEFT_ASSIGN_OPERATOR;
            foundSlice = BITSHIFT_LEFT_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, BITSHIFT_LEFT_OPERATOR_SLICE)) {
            found = BITSHIFT_LEFT_OPERATOR;
            foundSlice = BITSHIFT_LEFT_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, BITSHIFT_RIGHT_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bitshift right check
            found = BITSHIFT_RIGHT_ASSIGN_OPERATOR;
            foundSlice = BITSHIFT_RIGHT_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, BITSHIFT_RIGHT_OPERATOR_SLICE)) {
            found = BITSHIFT_RIGHT_OPERATOR;
            foundSlice = BITSHIFT_RIGHT_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, EQUAL_OPERATOR_SLICE)) { // Must take place prior to assignment check
            found = EQUAL_OPERATOR;
            foundSlice = EQUAL_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, ASSIGN_OPERATOR_SLICE)) {
            found = ASSIGN_OPERATOR;
            foundSlice = ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, NOT_EQUAL_OPERATOR_SLICE)) { // Must take place prior to not check
            found = NOT_EQUAL_OPERATOR;
            foundSlice = NOT_EQUAL_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, NOT_OPERATOR_SLICE)) {
            found = NOT_OPERATOR;
            foundSlice = NOT_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, LESS_EQUAL_OPERATOR_SLICE)) { // Must take place prior to less check
            found = LESS_EQUAL_OPERATOR;
            foundSlice = LESS_EQUAL_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, LESS_OPERATOR_SLICE)) {
            found = LESS_OPERATOR;
            foundSlice = LESS_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, GREATER_EQUAL_OPERATOR_SLICE)) { // Must take place prior to greater check
            found = GREATER_EQUAL_OPERATOR;
            foundSlice = GREATER_EQUAL_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, GREATER_OPERATOR_SLICE)) {
            found = GREATER_OPERATOR;
            foundSlice = GREATER_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, ADD_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to add check
            found = ADD_ASSIGN_OPERATOR;
            foundSlice = ADD_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, ADD_OPERATOR_SLICE)) {
            found = ADD_OPERATOR;
            foundSlice = ADD_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, SUBTRACT_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to subtract check
            found = SUBTRACT_ASSIGN_OPERATOR;
            foundSlice = SUBTRACT_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, MULTIPLY_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to multiply check
            found = MULTIPLY_ASSIGN_OPERATOR;
            foundSlice = MULTIPLY_ASSIGN_OPERATOR_SLICE;
        } 
        // NOTE cannot do MULTIPLY_OPERATOR here because its ambiguous with pointer symbol
        else if(starts_with_operator_or_symbol_substring(tokenStart, DIVIDE_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to divide check
            found = DIVIDE_ASSIGN_OPERATOR;
            foundSlice = DIVIDE_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, DIVIDE_OPERATOR_SLICE)) {
            found = DIVIDE_OPERATOR;
            foundSlice = DIVIDE_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, BIT_COMPLEMENT_OPERATOR_SLICE)) {
            found = BIT_COMPLEMENT_OPERATOR;
            foundSlice = BIT_COMPLEMENT_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, BIT_OR_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bit or check
            found = BIT_OR_ASSIGN_OPERATOR;
            foundSlice = BIT_OR_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, BIT_OR_OPERATOR_SLICE)) {
            found = BIT_OR_OPERATOR;
            foundSlice = BIT_OR_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, BIT_AND_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bit and check, which also is a special case
            found = BIT_AND_ASSIGN_OPERATOR;
            foundSlice = BIT_AND_ASSIGN_OPERATOR_SLICE;
        } 
        // NOTE cannot do BIT_AND_OPERATOR here because its ambiguous with reference operator
        else if(starts_with_operator_or_symbol_substring(tokenStart, BIT_XOR_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bit xor check
            found = BIT_XOR_ASSIGN_OPERATOR;
            foundSlice = BIT_XOR_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, BIT_XOR_OPERATOR_SLICE)) {
            found = BIT_XOR_OPERATOR;
            foundSlice = BIT_XOR_OPERATOR_SLICE;
        }
        // Symbols
        else if(starts_with_operator_or_symbol_substring(tokenStart, LEFT_PARENTHESES_SYMBOL_SLICE)) {
            found = LEFT_PARENTHESES_SYMBOL;
            foundSlice = LEFT_PARENTHESES_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, RIGHT_PARENTHESES_SYMBOL_SLICE)) {
            found = RIGHT_PARENTHESES_SYMBOL;
            foundSlice = RIGHT_PARENTHESES_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, LEFT_BRACKET_SYMBOL_SLICE)) {
            found = LEFT_BRACKET_SYMBOL;
            foundSlice = LEFT_BRACKET_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, RIGHT_BRACKET_SYMBOL_SLICE)) {
            found = RIGHT_BRACKET_SYMBOL;
            foundSlice = RIGHT_BRACKET_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, LEFT_BRACE_SYMBOL_SLICE)) {
            found = LEFT_BRACE_SYMBOL;
            foundSlice = LEFT_BRACE_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, RIGHT_BRACE_SYMBOL_SLICE)) {
            found = RIGHT_BRACE_SYMBOL;
            foundSlice = RIGHT_BRACE_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, COLON_SYMBOL_SLICE)) {
            found = COLON_SYMBOL;
            foundSlice = COLON_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, SEMICOLON_SYMBOL_SLICE)) {
            found = SEMICOLON_SYMBOL;
            foundSlice = SEMICOLON_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, PERIOD_SYMBOL_SLICE)) {
            found = PERIOD_SYMBOL;
            foundSlice = PERIOD_SYMBOL_SLICE;
        } else if(starts_with_operator_or_symbol_substring(tokenStart, COMMA_SYMBOL_SLICE)) {
            found = COMMA_SYMBOL;
            foundSlice = COMMA_SYMBOL_SLICE;
        }
        // Special case for ampersand -> "&"
        else if(starts_with_operator_or_symbol_substring(tokenStart, AMPERSAND_SLICE)) {
            if(previousToken == INT_LITERAL || previousToken == IDENTIFIER) {
                found = BIT_AND_OPERATOR;
                foundSlice = BIT_AND_OPERATOR_SLICE;
            } else {
                found = REFERENCE_SYMBOL;
                foundSlice = REFERENCE_SYMBOL_SLICE;
            }
        }
        // Special case for asterisk -> "*"
        else if(starts_with_operator_or_symbol_substring(tokenStart, ASTERISK_SLICE)) {
            if(previousToken == INT_LITERAL || previousToken == FLOAT_LITERAL ||  previousToken == IDENTIFIER) {
                found = MULTIPLY_OPERATOR;
                foundSlice = MULTIPLY_OPERATOR_SLICE;
            } else {
                found = POINTER_SYMBOL;
                foundSlice = POINTER_SYMBOL_SLICE;
            }
        } 
        // Special case for minus sign -> "-"
        else if(starts_with_operator_or_symbol_substring(tokenStart, MINUS_SLICE)) {
            if(previousToken == INT_LITERAL || previousToken == FLOAT_LITERAL ||  previousToken == IDENTIFIER) {
                found = SUBTRACT_OPERATOR;
                foundSlice = SUBTRACT_OPERATOR_SLICE;
            } else {
                const TokenLiteralOrIdentifier parsedLiteralOrIdentifier = try_parse_num_literal(self, pastWhitespacePos, tokenStart);
                if(parsedLiteralOrIdentifier.token == TOKEN_NONE) {
                    return next;
                } else {
                    found = parsedLiteralOrIdentifier.token;
                    foundSlice = parsedLiteralOrIdentifier.slice;
                    next.next.value = parsedLiteralOrIdentifier.metadata;
                }
            }
        }  
        else {
            const TokenLiteralOrIdentifier parsedLiteralOrIdentifier = try_parse_literal_or_identifier(self, pastWhitespacePos, tokenStart);
            if(parsedLiteralOrIdentifier.token == TOKEN_NONE) {
                return next;
            } else {
                found = parsedLiteralOrIdentifier.token;
                foundSlice = parsedLiteralOrIdentifier.slice;
                next.next.value = parsedLiteralOrIdentifier.metadata;
            }
        }
    }

    next.hasNextToken = true;
    next.next.tag = found;
    next.newPosition.index = self->position.index + foundSlice.len + whitespaceOffset;
    return next;
}

TokenIter cubs_token_iter_init(CubsStringSlice name, CubsStringSlice source, CubsSyntaxErrorCallback errCallback)
{
    const CubsSourceFileCharPosition pos = {.index = 0, .line = 1, .column = 1};
    const TokenIter self = {
        .name = name,
        .source = source,
        .errCallback = errCallback,
        .position = pos,
        .previous = {0},
        .current = {0},
    };

    return self;
}

TokenType cubs_token_iter_next(TokenIter *self)
{
    const NextToken next = get_next_token(self);
    self->previous = self->current;
    if(next.hasNextToken) {
        self->position = next.newPosition;
        self->current = next.next;
    } else {
        self->current = (Token){0};
    }
    return next.next.tag;
}

TokenType cubs_token_iter_peek(const TokenIter* self) {
    const NextToken next = get_next_token(self);
    return next.next.tag;
}
