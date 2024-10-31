#include "parser.h"
#include <assert.h>
#include <stdio.h>

// TODO figure out fast way to get the token.
// Could look at SIMD, or hashing, or even 8 byte compare if all tokens (not identifiers)
// are smaller than 8 bytes in length

// TODO handle comments when parsing

typedef struct NextToken {
    bool hasNextToken;
    Token next;
    size_t newPosition;
    size_t newLine;
    size_t newColumn;
} NextToken;

// /// The valid characters that can be after are `' '`, `'\n'`, `'\t'`, `','`, `'.'`, `';'`. 

/// Checks if `source` starts with `find`.
static bool starts_with_substring(const CubsStringSlice source, const CubsStringSlice find) {
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
        if(charAfterToken == ' ' || charAfterToken == '\n' || charAfterToken == '\t'  || charAfterToken == '\r'
            || charAfterToken == ','|| charAfterToken == '.'|| charAfterToken == ';')
        {
            return true;
        } else {
            return false;
        }
    }
}

/// Skips over any whitespace or newlines. Returns an empty slice if there is no token start from the iters
/// current position within the source string slice.
static CubsStringSlice get_next_token_start_slice(const ParserIter* self, size_t* outOffset) {
    const CubsStringSlice tempStart = {
        .str = &self->source.str[self->currentPosition], 
        .len = self->source.len - self->currentPosition
    };
    size_t i = 0;
    for(; i < tempStart.len; i++) {
        const char c = tempStart.str[i];
        if(c == ' ' || c == '\t' || c == '\n') {
            continue;
        }
        if(c == '\r') { // CRLF
            if((i + 1) < tempStart.len) {
                if(tempStart.str[i + 1] == '\n') { 
                    i += 1; // step further
                    continue;
                } 
            }
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
TOKEN_CONSTANT(STR_KEYWORD_SLICE, "str");
TOKEN_CONSTANT(CHAR_KEYWORD_SLICE, "char");
TOKEN_CONSTANT(IMPORT_KEYWORD_SLICE, "import");
TOKEN_CONSTANT(MOD_KEYWORD_SLICE, "mod");
TOKEN_CONSTANT(EXTERN_KEYWORD_SLICE, "extern");
TOKEN_CONSTANT(AND_KEYWORD_SLICE, "and");
TOKEN_CONSTANT(OR_KEYWORD_SLICE, "or");

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

static NextToken get_next_token(const ParserIter* self) {
    const NextToken noneNext = {0};

    Token found = TOKEN_NONE;
    CubsStringSlice foundSlice = {0};
    NextToken next = {0};
    next.newLine = self->currentLine;
    next.newColumn = self->currentColumn;
    size_t whitespaceOffset = 0;

    const Token previousToken = self->current;

    if(self->currentPosition >= self->source.len) {
        return next;
    } else {
        const CubsStringSlice tokenStart = get_next_token_start_slice(self, &whitespaceOffset);
        const CubsStringSlice AMPERSAND_SLICE = {.str = "&", .len = 1};
        const CubsStringSlice ASTERISK_SLICE = {.str = "*", .len = 1};

        // Keywords
        if(starts_with_substring(tokenStart, CONST_KEYWORD_SLICE)) {
            found = CONST_KEYWORD;
            foundSlice = CONST_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, MUT_KEYWORD_SLICE)) {
            found = MUT_KEYWORD;
            foundSlice = MUT_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, RETURN_KEYWORD_SLICE)) {
            found = RETURN_KEYWORD;
            foundSlice = RETURN_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, FN_KEYWORD_SLICE)) {
            found = FN_KEYWORD;
            foundSlice = FN_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, PUB_KEYWORD_SLICE)) {
            found = PUB_KEYWORD;
            foundSlice = PUB_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, IF_KEYWORD_SLICE)) {
            found = IF_KEYWORD;
            foundSlice = IF_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, ELSE_KEYWORD_SLICE)) {
            found = ELSE_KEYWORD;
            foundSlice = ELSE_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, SWITCH_KEYWORD_SLICE)) {
            found = SWITCH_KEYWORD;
            foundSlice = SWITCH_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, WHILE_KEYWORD_SLICE)) {
            found = WHILE_KEYWORD;
            foundSlice = WHILE_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, FOR_KEYWORD_SLICE)) {
            found = FOR_KEYWORD;
            foundSlice = FOR_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, BREAK_KEYWORD_SLICE)) {
            found = BREAK_KEYWORD;
            foundSlice = BREAK_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, CONTINUE_KEYWORD_SLICE)) {
            found = CONTINUE_KEYWORD;
            foundSlice = CONTINUE_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, STRUCT_KEYWORD_SLICE)) {
            found = STRUCT_KEYWORD;
            foundSlice = STRUCT_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, INTERFACE_KEYWORD_SLICE)) {
            found = INTERFACE_KEYWORD;
            foundSlice = INTERFACE_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, ENUM_KEYWORD_SLICE)) {
            found = ENUM_KEYWORD;
            foundSlice = ENUM_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, UNION_KEYWORD_SLICE)) {
            found = UNION_KEYWORD;
            foundSlice = UNION_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, SYNC_KEYWORD_SLICE)) {
            found = SYNC_KEYWORD;
            foundSlice = SYNC_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, UNSAFE_KEYWORD_SLICE)) {
            found = UNSAFE_KEYWORD;
            foundSlice = UNSAFE_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, TRUE_KEYWORD_SLICE)) {
            found = TRUE_KEYWORD;
            foundSlice = TRUE_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, FALSE_KEYWORD_SLICE)) {
            found = FALSE_KEYWORD;
            foundSlice = FALSE_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, BOOL_KEYWORD_SLICE)) {
            found = BOOL_KEYWORD;
            foundSlice = BOOL_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, INT_KEYWORD_SLICE)) {
            found = INT_KEYWORD;
            foundSlice = INT_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, FLOAT_KEYWORD_SLICE)) {
            found = FLOAT_KEYWORD;
            foundSlice = FLOAT_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, STR_KEYWORD_SLICE)) {
            found = STR_KEYWORD;
            foundSlice = STR_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, CHAR_KEYWORD_SLICE)) {
            found = CHAR_KEYWORD;
            foundSlice = CHAR_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, IMPORT_KEYWORD_SLICE)) {
            found = IMPORT_KEYWORD;
            foundSlice = IMPORT_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, MOD_KEYWORD_SLICE)) {
            found = MOD_KEYWORD;
            foundSlice = MOD_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, EXTERN_KEYWORD_SLICE)) {
            found = EXTERN_KEYWORD;
            foundSlice = EXTERN_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, AND_KEYWORD_SLICE)) {
            found = AND_KEYWORD;
            foundSlice = AND_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, OR_KEYWORD_SLICE)) {
            found = OR_KEYWORD;
            foundSlice = OR_KEYWORD_SLICE;
        } 
        // Operators
        else if(starts_with_substring(tokenStart, EQUAL_OPERATOR_SLICE)) { // Must take place prior to assignment check
            found = EQUAL_OPERATOR;
            foundSlice = EQUAL_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, ASSIGN_OPERATOR_SLICE)) {
            found = ASSIGN_OPERATOR;
            foundSlice = ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, NOT_EQUAL_OPERATOR_SLICE)) { // Must take place prior to not check
            found = NOT_EQUAL_OPERATOR;
            foundSlice = NOT_EQUAL_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, NOT_OPERATOR_SLICE)) {
            found = NOT_OPERATOR;
            foundSlice = NOT_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, LESS_EQUAL_OPERATOR_SLICE)) { // Must take place prior to less check
            found = LESS_EQUAL_OPERATOR;
            foundSlice = LESS_EQUAL_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, LESS_OPERATOR_SLICE)) {
            found = LESS_OPERATOR;
            foundSlice = LESS_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, GREATER_EQUAL_OPERATOR_SLICE)) { // Must take place prior to greater check
            found = GREATER_EQUAL_OPERATOR;
            foundSlice = GREATER_EQUAL_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, GREATER_OPERATOR_SLICE)) {
            found = GREATER_OPERATOR;
            foundSlice = GREATER_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, ADD_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to add check
            found = ADD_ASSIGN_OPERATOR;
            foundSlice = ADD_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, ADD_OPERATOR_SLICE)) {
            found = ADD_OPERATOR;
            foundSlice = ADD_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, SUBTRACT_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to subtract check
            found = SUBTRACT_ASSIGN_OPERATOR;
            foundSlice = SUBTRACT_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, SUBTRACT_OPERATOR_SLICE)) {
            found = SUBTRACT_OPERATOR;
            foundSlice = SUBTRACT_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, MULTIPLY_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to multiply check
            found = MULTIPLY_ASSIGN_OPERATOR;
            foundSlice = MULTIPLY_ASSIGN_OPERATOR_SLICE;
        } 
        // NOTE cannot do MULTIPLY_OPERATOR here because its ambiguous with pointer symbol
        else if(starts_with_substring(tokenStart, DIVIDE_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to divide check
            found = DIVIDE_ASSIGN_OPERATOR;
            foundSlice = DIVIDE_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, DIVIDE_OPERATOR_SLICE)) {
            found = DIVIDE_OPERATOR;
            foundSlice = DIVIDE_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BITSHIFT_LEFT_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bitshift left check
            found = BITSHIFT_LEFT_ASSIGN_OPERATOR;
            foundSlice = BITSHIFT_LEFT_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BITSHIFT_LEFT_OPERATOR_SLICE)) {
            found = BITSHIFT_LEFT_OPERATOR;
            foundSlice = BITSHIFT_LEFT_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BITSHIFT_RIGHT_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bitshift right check
            found = BITSHIFT_RIGHT_ASSIGN_OPERATOR;
            foundSlice = BITSHIFT_RIGHT_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BITSHIFT_RIGHT_OPERATOR_SLICE)) {
            found = BITSHIFT_RIGHT_OPERATOR;
            foundSlice = BITSHIFT_RIGHT_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BIT_COMPLEMENT_OPERATOR_SLICE)) {
            found = BIT_COMPLEMENT_OPERATOR;
            foundSlice = BIT_COMPLEMENT_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BIT_OR_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bit or check
            found = BIT_OR_ASSIGN_OPERATOR;
            foundSlice = BIT_OR_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BIT_OR_OPERATOR_SLICE)) {
            found = BIT_OR_OPERATOR;
            foundSlice = BIT_OR_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BIT_AND_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bit and check, which also is a special case
            found = BIT_AND_ASSIGN_OPERATOR;
            foundSlice = BIT_AND_ASSIGN_OPERATOR_SLICE;
        } 
        // NOTE cannot do BIT_AND_OPERATOR here because its ambiguous with reference operator
        else if(starts_with_substring(tokenStart, BIT_XOR_ASSIGN_OPERATOR_SLICE)) { // Must take place prior to bit xor check
            found = BIT_XOR_ASSIGN_OPERATOR;
            foundSlice = BIT_XOR_ASSIGN_OPERATOR_SLICE;
        } else if(starts_with_substring(tokenStart, BIT_XOR_OPERATOR_SLICE)) {
            found = BIT_XOR_OPERATOR;
            foundSlice = BIT_XOR_OPERATOR_SLICE;
        }
        // Symbols
        else if(starts_with_substring(tokenStart, LEFT_PARENTHESES_SYMBOL_SLICE)) {
            found = LEFT_PARENTHESES_SYMBOL;
            foundSlice = LEFT_PARENTHESES_SYMBOL_SLICE;
        } else if(starts_with_substring(tokenStart, RIGHT_PARENTHESES_SYMBOL_SLICE)) {
            found = RIGHT_PARENTHESES_SYMBOL;
            foundSlice = RIGHT_PARENTHESES_SYMBOL_SLICE;
        } else if(starts_with_substring(tokenStart, LEFT_BRACKET_SYMBOL_SLICE)) {
            found = LEFT_BRACKET_SYMBOL;
            foundSlice = LEFT_BRACKET_SYMBOL_SLICE;
        } else if(starts_with_substring(tokenStart, RIGHT_BRACKET_SYMBOL_SLICE)) {
            found = RIGHT_BRACKET_SYMBOL;
            foundSlice = RIGHT_BRACKET_SYMBOL_SLICE;
        } else if(starts_with_substring(tokenStart, LEFT_BRACE_SYMBOL_SLICE)) {
            found = LEFT_BRACE_SYMBOL;
            foundSlice = LEFT_BRACE_SYMBOL_SLICE;
        } else if(starts_with_substring(tokenStart, RIGHT_BRACE_SYMBOL_SLICE)) {
            found = RIGHT_BRACE_SYMBOL;
            foundSlice = RIGHT_BRACE_SYMBOL_SLICE;
        } else if(starts_with_substring(tokenStart, SEMICOLON_SYMBOL_SLICE)) {
            found = SEMICOLON_SYMBOL;
            foundSlice = SEMICOLON_SYMBOL_SLICE;
        } else if(starts_with_substring(tokenStart, PERIOD_SYMBOL_SLICE)) {
            found = PERIOD_SYMBOL;
            foundSlice = PERIOD_SYMBOL_SLICE;
        } else if(starts_with_substring(tokenStart, COMMA_SYMBOL_SLICE)) {
            found = COMMA_SYMBOL;
            foundSlice = COMMA_SYMBOL_SLICE;
        } // } else if(starts_with_substring(tokenStart, POINTER_SYMBOL_SLICE)) {
        //     found = POINTER_SYMBOL;
        //     foundSlice = POINTER_SYMBOL_SLICE;
        // }
        
        // Special case for ampersand -> "&"
        else if(starts_with_substring(tokenStart, AMPERSAND_SLICE)) {
            if(previousToken == INT_LITERAL || previousToken == IDENTIFIER) {
                found = BIT_AND_OPERATOR;
                foundSlice = BIT_AND_OPERATOR_SLICE;
            } else {
                found = REFERENCE_SYMBOL;
                foundSlice = REFERENCE_SYMBOL_SLICE;
            }
        }
        // Special case for asterisk -> "*"
        else if(starts_with_substring(tokenStart, ASTERISK_SLICE)) {
            if(previousToken == INT_LITERAL || previousToken == FLOAT_LITERAL ||  previousToken == IDENTIFIER) {
                found = MULTIPLY_OPERATOR;
                foundSlice = MULTIPLY_OPERATOR_SLICE;
            } else {
                found = POINTER_SYMBOL;
                foundSlice = POINTER_SYMBOL_SLICE;
            }
        }   
        else {
            return next;
        }
    }

    next.hasNextToken = true;
    next.next = found;
    next.newPosition = self->currentPosition + foundSlice.len + whitespaceOffset;
    return next;
}

ParserIter cubs_parser_iter_init(CubsStringSlice source)
{
    ParserIter self = {
        .source = source, 
        .currentPosition = 0,
        .currentLine = 1,
        .currentColumn = 1,
        .current = TOKEN_NONE,
        .next = TOKEN_NONE,
    };

    const NextToken next = get_next_token(&self);
    if(next.hasNextToken) {
        self.currentPosition = next.newPosition;
        self.currentLine = next.newLine;
        self.currentColumn = next.newColumn;
        self.next = next.next;
    }

    return self;
}

Token cubs_parser_iter_next(ParserIter *self)
{
    const NextToken next = get_next_token(self);
    const Token oldNext = self->next;
    if(next.hasNextToken) {
        self->currentPosition = next.newPosition;
        self->currentLine = next.newLine;
        self->currentColumn = next.newColumn;
        self->current = self->next;
        self->next = next.next;
    } else {
        self->current = self->next;
        self->next = TOKEN_NONE;
    }
    return oldNext;
}

Token cubs_parser_iter_peek(const ParserIter *self)
{
    return self->next;
}
