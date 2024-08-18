#pragma once

//! Doesn't need "erasing" functionality, just insert and find

#include <stddef.h>
#include "../primitives/string/string.h"
#include "../interpreter/function_definition.h"

typedef struct FunctionMapGroup FunctionMapGroup;

/// Maps all of the script functions.
typedef struct {
    size_t count;
    ScriptFunctionDefinitionHeader a;
} FunctionMap;