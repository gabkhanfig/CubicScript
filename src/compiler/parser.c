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
    return true;
    // const char charAfterToken = source.str[i];
    // if(charAfterToken == ' ' || charAfterToken == '\n' || charAfterToken == '\t' 
    //     || charAfterToken == ','|| charAfterToken == '.'|| charAfterToken == ';')
    // {
    //     return true;
    // } else {
    //     return false;
    // }
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

static const CubsStringSlice CONST_KEYWORD_SLICE = {.str = "const", .len = 5};

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
