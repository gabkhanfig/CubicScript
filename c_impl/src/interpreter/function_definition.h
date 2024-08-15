#pragma once

#include <stddef.h>
#include "../primitives/string/string.h"

typedef struct CubsTypeContext;
typedef struct CubsString CubsString;
typedef struct Bytecode Bytecode;

typedef struct ScriptFunctionArgTypesSlice {
    /// If NULL, the function take no arguments
    const CubsTypeContext** optTypes;
    /// If zero, the function take no arguments
    size_t count;
} ScriptFunctionArgTypesSlice;

typedef struct {
    CubsString name;
    /// Can be NULL, meaning function has a `void` or `none` return type
    const CubsTypeContext* optReturnType;
    ScriptFunctionArgTypesSlice args;
} FunctionBuilder;

// TODO when the program allocates the header and bytecode, mprotect / VirutalProtect it to prevent malicious actors from overwriting bytecode

typedef struct {
    CubsString name;
    const CubsTypeContext* optReturnType;
    ScriptFunctionArgTypesSlice args;
    size_t bytecodeCount;
} ScriptFunctionDefinitionHeader;