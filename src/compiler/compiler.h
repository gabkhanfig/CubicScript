#pragma once

#include "../c_basic_types.h"
#include "../primitives/string/string_slice.h"

struct CubsProgram;
struct CubsBuildOptions;

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

typedef struct CubsCompileErrorLocation {
    CubsStringSlice fileName;
    CubsSourceFileCharPosition position;
} CubsCompileErrorLocation;

void cubs_compile(struct CubsProgram* program, const struct CubsBuildOptions* build);
