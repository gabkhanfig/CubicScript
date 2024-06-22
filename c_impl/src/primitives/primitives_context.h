#pragma once

#include "script_value.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"

static const CubsStructContext BOOL_CONTEXT = {
    .sizeOfType = sizeof(bool),
    .tag = cubsValueTagBool,
    .onDeinit = NULL,
    .name = "bool",
    .nameLength = 4,
    .fullyQualifiedName = "bool",
    .fullyQualifiedNameLength = 4,
};

static const CubsStructContext INT_CONTEXT = {
    .sizeOfType = sizeof(int64_t),
    .tag = cubsValueTagInt,
    .onDeinit = NULL, 
    .name = "int",
    .nameLength = 3,
    .fullyQualifiedName = "int",
    .fullyQualifiedNameLength = 3,
};

static const CubsStructContext FLOAT_CONTEXT = {
    .sizeOfType = sizeof(double),
    .tag = cubsValueTagFloat,
    .onDeinit = NULL, 
    .name = "float",
    .nameLength = 5,
    .fullyQualifiedName = "float",
    .fullyQualifiedNameLength = 5,
};

static const CubsStructContext STRING_CONTEXT = {
    .sizeOfType = sizeof(CubsString),
    .tag = cubsValueTagString,
    .onDeinit = (CubsStructOnDeinit)cubs_string_deinit,
    .name = "string",
    .nameLength = 6,
    .fullyQualifiedName = "string",
    .fullyQualifiedNameLength = 6,
};

static const CubsStructContext ARRAY_CONTEXT = {
    .sizeOfType = sizeof(CubsArray),
    .tag = cubsValueTagArray,
    .onDeinit = (CubsStructOnDeinit)cubs_array_deinit,
    .name = "array",
    .nameLength = 5,
    .fullyQualifiedName = "array",
    .fullyQualifiedNameLength = 5,
};