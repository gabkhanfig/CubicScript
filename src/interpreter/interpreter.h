#pragma once

#include "../program/program_runtime_error.h"

struct CubsProgram;
struct CubsScriptFunctionPtr;
struct CubsTypeContext;

/// Executes the operation at this thread's instruction pointer
CubsProgramRuntimeError cubs_interpreter_execute_operation(const struct CubsProgram* program);

/// Will push and pop a frame for execution
CubsProgramRuntimeError cubs_interpreter_execute_function(const struct CubsScriptFunctionPtr* function, void* outReturnValue, const struct CubsTypeContext** outContext);