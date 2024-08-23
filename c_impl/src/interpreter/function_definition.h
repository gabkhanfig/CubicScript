#pragma once

#include <stddef.h>
#include "../primitives/string/string.h"
#include "bytecode.h"

typedef struct CubsTypeContext CubsTypeContext;
typedef struct CubsString CubsString;
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
typedef struct FunctionBuilder {
    CubsString fullyQualifiedName;
    CubsString name;
    /// Can be NULL, meaning function has a `void` or `none` return type
    const CubsTypeContext* optReturnType;
    ScriptFunctionArgTypesSlice args;
    size_t stackSpaceRequired;
    Bytecode* bytecode;
    size_t bytecodeLen;
    size_t bytecodeCapacity;
} FunctionBuilder;

void cubs_function_builder_deinit(FunctionBuilder* self);

void cubs_function_builder_push_bytecode(FunctionBuilder* self, Bytecode bytecode);

/// `count` is the number of bytecodes to copy
void cubs_function_builder_push_bytecode_many(FunctionBuilder* self, const Bytecode* bytecode, size_t count);

// TODO when the program allocates the header and bytecode, mprotect / VirutalProtect it to prevent malicious actors from overwriting bytecode

typedef struct ScriptFunctionDefinitionHeader {
    CubsString fullyQualifiedName;
    CubsString name;  
    size_t stackSpaceRequired;
    const CubsTypeContext* optReturnType;
    ScriptFunctionArgTypesSlice args;
    size_t bytecodeCount;
} ScriptFunctionDefinitionHeader;

/// Returns a reference to the header that is owned by the `program`.
/// Return value can be ignored.
/// Defined in `src/program/program.c`
extern ScriptFunctionDefinitionHeader* cubs_function_builder_build(FunctionBuilder* self, CubsProgram* program);

const Bytecode* cubs_function_bytecode_start(const ScriptFunctionDefinitionHeader* header);