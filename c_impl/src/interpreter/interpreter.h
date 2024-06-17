#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include "../primitives/value_tag.h"

typedef struct Bytecode Bytecode;
typedef struct CubsProgram CubsProgram;

typedef union InterpreterRegister {
    size_t actualValue;
    bool boolean;
    int64_t intNum;
    double floatNum;
    void* ptr;
} InterpreterRegister;

static const size_t REGISTER_IS_PTR_FLAG = (1ULL << 63);
static const size_t REGISTER_PTR_OR_OFFSET_MASK = 0x0000FFFFFFFFFFFFULL;
#define REGISTER_COUNT 32
#define REGISTER_BITS_REQUIRED 5

typedef struct {
    const Bytecode* instructionPointer;
    InterpreterRegister registers[REGISTER_COUNT];
    /// Since registers are limited to 8 bytes, the tag will store EITHER if bool, int, or float, 
    /// OR what value type is the ptr pointing to.
    uint8_t registerValueTags[REGISTER_COUNT];
} InterpreterRegisters;

typedef enum CubsFatalScriptError {
    cubsFatalScriptErrorNone = 0,

    _CUBS_FATAL_SCRIPT_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsFatalScriptError;

void cubs_interpreter_set_instruction_pointer(const struct Bytecode* newIp);

/// Executes the operation at this thread's instruction pointer
CubsFatalScriptError cubs_interpreter_execute_operation(const struct CubsProgram* program);

InterpreterRegister cubs_interpreter_register_value_at(size_t registerIndex);

CubsValueTag cubs_interpreter_register_value_tag_at(size_t registerIndex);