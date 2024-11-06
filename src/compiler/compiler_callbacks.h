#pragma once
// Part of API

#include "../primitives/string/string_slice.h"
#include "../c_basic_types.h"

/// Callback for if any syntax errors are encountered.
/// This results in a compiler error, and compilation stopping.
/// @param message Error message. Is nevermind empty and is null terminated.
/// @param sourceName Name of the source file. Can be empty, and may not be null terminated.
/// @param sourceContents Full file contents. May not be null terminated.
/// @param errLocation Index of character (byte) where the error began at.
/// @param line Line where error occurs in `sourceContents`. Starts at 1.
/// @param column Column where error occurs in `sourceContents`. Starts at 1.
typedef void (*CubsSyntaxErrorCallback)
    (CubsStringSlice message,
    CubsStringSlice sourceName, 
    CubsStringSlice sourceContents,
    size_t errLocation, 
    size_t line, 
    size_t column
);