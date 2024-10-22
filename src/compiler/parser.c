#include "parser.h"

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

/// Checks if `source` starts with `find`, and that the character after the substring isn't an invalid characters.
/// The valid characters that can be after are `' '`, `'\n'`, `'\t'`, `','`, `'.'`, `';'`. 
static bool has_substring_and_valid_token(CubsStringSlice source, CubsStringSlice find) {
    size_t i = 0;
    for(; i < find.len; i++) {
        if(source.str[i] != find.str[i]) {
            return false;
        }
    }

    const char charAfterToken = source.str[i];
    if(charAfterToken == ' ' || charAfterToken == '\n' || charAfterToken == '\t' 
        || charAfterToken == ','|| charAfterToken == '.'|| charAfterToken == ';')
    {
        return true;
    } else {
        return false;
    }
}

static NextToken get_next_token(const ParserIter* self) {
    const NextToken next = {0};
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


    return self;
}

Token cubs_parser_iter_next(ParserIter *self)
{
    return TOKEN_NONE;
}

Token cubs_parser_iter_peek(const ParserIter *self)
{
    return TOKEN_NONE;
}
