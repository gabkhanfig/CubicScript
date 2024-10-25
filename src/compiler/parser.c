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
TOKEN_CONSTANT(AND_KEYWORD_SLICE, "and");
TOKEN_CONSTANT(OR_KEYWORD_SLICE, "or");

static NextToken get_next_token(const ParserIter* self) {
    const NextToken noneNext = {0};

    Token found = TOKEN_NONE;
    CubsStringSlice foundSlice = {0};
    NextToken next = {0};
    next.newLine = self->currentLine;
    next.newColumn = self->currentColumn;
    size_t whitespaceOffset = 0;

    if(self->currentPosition >= self->source.len) {
        return next;
    } else {
        const CubsStringSlice tokenStart = get_next_token_start_slice(self, &whitespaceOffset);

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
        } else if(starts_with_substring(tokenStart, AND_KEYWORD_SLICE)) {
            found = AND_KEYWORD;
            foundSlice = AND_KEYWORD_SLICE;
        } else if(starts_with_substring(tokenStart, OR_KEYWORD_SLICE)) {
            found = OR_KEYWORD;
            foundSlice = OR_KEYWORD_SLICE;
        } else {
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
