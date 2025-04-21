#pragma once
#ifndef UNEXPECTED_TOKEN_H
#define UNEXPECTED_TOKEN_H

#include "compile_error.h"
#include "../parse/tokenizer.h"
#include "../../primitives/string/string.h"

struct TokenIter;

typedef struct UnexpectedToken {
    TokenType found;
    /// Not dynamically allocated
    const TokenType* expected;
    size_t expectedLen;
} UnexpectedToken;

CompileError unexpected_token_init(const TokenIter* iter, const TokenType* expected, size_t expectedLen);

#endif