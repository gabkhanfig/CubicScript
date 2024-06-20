#pragma once

#include "script_value.h"
#include "../primitives/string/string.h"

static const CubsStructRtti BOOL_RTTI = {
    .sizeOfType = sizeof(bool),
    .tag = cubsValueTagBool,
    .onDeinit = NULL,
    .name = "bool",
    .nameLength = 4,
    .fullyQualifiedName = "bool",
    .fullyQualifiedNameLength = 4,
};

static const CubsStructRtti INT_RTTI = {
    .sizeOfType = sizeof(int64_t),
    .tag = cubsValueTagInt,
    .onDeinit = NULL, 
    .name = "int",
    .nameLength = 3,
    .fullyQualifiedName = "int",
    .fullyQualifiedNameLength = 3,
};

static const CubsStructRtti FLOAT_RTTI = {
    .sizeOfType = sizeof(double),
    .tag = cubsValueTagFloat,
    .onDeinit = NULL, 
    .name = "float",
    .nameLength = 5,
    .fullyQualifiedName = "float",
    .fullyQualifiedNameLength = 5,
};

static const CubsStructRtti STRING_RTTI = {
    .sizeOfType = sizeof(CubsString),
    .tag = cubsValueTagString,
    .onDeinit = (CubsStructOnDeinit)cubs_string_deinit,
    .name = "string",
    .nameLength = 6,
    .fullyQualifiedName = "string",
    .fullyQualifiedNameLength = 6,
};