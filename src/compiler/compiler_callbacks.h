#pragma once
// Part of API

#include "../primitives/string/string_slice.h"
#include "../c_basic_types.h"

/// Is the information about where within a source file a specific character is.
/// These are the specific byte index, line, and column.
typedef struct CubsSourceFileCharPosition {
    /// Is in bytes, not utf8 characters
    size_t index;
    /// Starts at 1
    size_t line;
    /// Starts at 1
    size_t column;
} CubsSourceFileCharPosition;

enum CubsSyntaxErrorType {
    cubsSyntaxErrNumLiteralInvalidChar,
    cubsSyntaxErrNumLiteralTooManyDecimal,
    // Enforce enum size is at least 32 bits, which is `int` on most platforms
    _CUBS_SYNTAX_ERROR_TYPE_MAX_VALUE = 0x7FFFFFFF,
};

/// Callback for if any syntax errors are encountered.
/// This results in a compiler error, and compilation stopping.
/// @param message Error message. Is nevermind empty and is null terminated.
/// @param sourceName Name of the source file. Can be empty, and may not be null terminated.
/// @param sourceContents Full file contents. May not be null terminated.
/// @param errLocation Index of character (byte) where the error began at.
/// @param line Line where error occurs in `sourceContents`. Starts at 1.
/// @param column Column where error occurs in `sourceContents`. Starts at 1.
typedef void (*CubsSyntaxErrorCallback)
    (enum CubsSyntaxErrorType err,
    CubsStringSlice sourceName,
    CubsStringSlice sourceContents,
    CubsSourceFileCharPosition errLocation
);