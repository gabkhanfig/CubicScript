#pragma once

#include <stddef.h>
#include "../primitives/string/string.h"

typedef struct CubsTypeContext;
typedef struct CubsString CubsString;
typedef struct Bytecode Bytecode;
typedef struct CubsProgram CubsProgram;

typedef struct ScriptFunctionArgTypesSlice {
    /// If NULL, the function take no arguments
    const CubsTypeContext** optTypes;
    /// If zero, the function take no arguments
    size_t len;
    size_t capacity;
} ScriptFunctionArgTypesSlice;

/// Must be deinitialized with `cubs_function_builder_deinit(...)` OR `cubs_function_builder_build(...)`.
/// Both will appropriately free any used allocations.
typedef struct {
    CubsString fullyQualifiedName;
    CubsString name;
    /// Can be NULL, meaning function has a `void` or `none` return type
    const CubsTypeContext* optReturnType;
    ScriptFunctionArgTypesSlice args;
    size_t stackSpaceRequired;
    struct Bytecode* bytecode;
    size_t bytecodeLen;
    size_t bytecodeCapacity;
} FunctionBuilder;

void cubs_function_builder_deinit(FunctionBuilder* self);

// Defined in `src/program/program.c`
extern ScriptFunctionDefinitionHeader* cubs_function_builder_build(FunctionBuilder* self, CubsProgram* program);

// TODO when the program allocates the header and bytecode, mprotect / VirutalProtect it to prevent malicious actors from overwriting bytecode

typedef struct {
    CubsString fullyQualifiedName;
    CubsString name;
    const CubsTypeContext* optReturnType;
    ScriptFunctionArgTypesSlice args;
    size_t bytecodeCount;
} ScriptFunctionDefinitionHeader;

const Bytecode* cubs_function_bytecode_start(const ScriptFunctionDefinitionHeader* header);