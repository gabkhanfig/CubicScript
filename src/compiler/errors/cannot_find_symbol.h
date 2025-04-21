#pragma once
#ifndef CANNOT_FIND_SYMBOL_H
#define CANNOT_FIND_SYMBOL_H

#include "compile_error.h"
#include "../parse/tokenizer.h"
#include "../../primitives/string/string_slice.h"

struct TokenIter;

typedef struct CannotFindSymbol {
    CubsStringSlice missingSymbol;
} CannotFindSymbol;

CompileError cannot_find_symbol_init(const TokenIter* iter, CubsStringSlice missingSymbol);

#endif