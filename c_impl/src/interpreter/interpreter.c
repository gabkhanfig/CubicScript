#include "interpreter.h"
#include "bytecode.h"
#include "stack.h"
#include <stdio.h>
#include "../util/unreachable.h"
#include <assert.h>
#include "../program/program.h"

static _Thread_local InterpreterRegisters threadLocalRegisters = {0};

void cubs_interpreter_set_instruction_pointer(const Bytecode *newIp)
{
    assert(newIp != NULL);
    threadLocalRegisters.instructionPointer = newIp;
}

CubsFatalScriptError cubs_interpreter_execute_operation(const CubsProgram *program)
{
    size_t ipIncrement = 1;
    const Bytecode bytecode = *threadLocalRegisters.instructionPointer;
    const OpCode opcode = cubs_bytecode_get_opcode(bytecode);
    switch(opcode) {
        case OpCodeNop: {
            fprintf(stderr, "nop :)\n");
        } break;
        default: {
            unreachable();
        } break;
    }
    threadLocalRegisters.instructionPointer = &threadLocalRegisters.instructionPointer[ipIncrement];
    return cubsFatalScriptErrorNone;
}
