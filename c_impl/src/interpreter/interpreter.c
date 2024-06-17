#include "interpreter.h"
#include "bytecode.h"
#include "stack.h"
#include <stdio.h>
#include "../util/unreachable.h"
#include <assert.h>
#include "../program/program.h"
#include "../primitives/value_tag.h"
#include <string.h>

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
        case OpCodeLoad: {
            const OperandsLoadUnknown unknownOperands = *(const OperandsLoadUnknown*)&bytecode;

            switch(unknownOperands.loadType) {
                case LOAD_TYPE_IMMEDIATE: {
                    const OperandsLoadImmediate operands = *(const OperandsLoadImmediate*)&bytecode;

                    switch(operands.immediateType) {
                        case LOAD_IMMEDIATE_BOOL: {
                            threadLocalRegisters.registers[operands.dst].boolean = operands.immediate != 0;
                            threadLocalRegisters.registerValueTags[operands.dst] = cubsValueTagBool;
                        } break;
                        case LOAD_IMMEDIATE_INT: {
                            threadLocalRegisters.registers[operands.dst].intNum = (int64_t)operands.immediate;
                            threadLocalRegisters.registerValueTags[operands.dst] = cubsValueTagInt;
                        } break;
                        case LOAD_IMMEDIATE_FLOAT: {
                            threadLocalRegisters.registers[operands.dst].floatNum = (double)operands.immediate;
                            threadLocalRegisters.registerValueTags[operands.dst] = cubsValueTagFloat;
                        } break;
                        default: {
                            unreachable();
                        } break;
                    }
                } break;
                case LOAD_TYPE_IMMEDIATE_LONG: {
                    const OperandsLoadImmediateLong operands = *(const OperandsLoadImmediateLong*)&bytecode;
                    assert(operands.immediateValueTag != cubsValueTagNone);
                    assert(operands.immediateValueTag != cubsValueTagBool && "Don't use 64 bit immediate load for booleans");

                    const size_t immediate = 
                        ((size_t)threadLocalRegisters.instructionPointer[1].value) |
                        (((size_t)threadLocalRegisters.instructionPointer[2].value) << 32);
                    threadLocalRegisters.registers[operands.dst].actualValue = immediate;     
                    threadLocalRegisters.registerValueTags[operands.dst] = operands.immediateValueTag;              
                    ipIncrement += 2; // move instruction pointer further into the bytecode
                } break;
                case LOAD_TYPE_FROM_STACK: {
                    const OperandsLoadFromStack operands = *(const OperandsLoadFromStack*)&bytecode;
                    const CubsValueTag stackValueTag = cubs_interpreter_stack_tag_at(operands.offsetFromFrameStart);
                    assert(stackValueTag != cubsValueTagNone);

                    if(
                        stackValueTag == cubsValueTagBool 
                        || stackValueTag == cubsValueTagInt 
                        || stackValueTag == cubsValueTagFloat
                    ) {
                        memcpy((void*)&threadLocalRegisters.registers[operands.dst].actualValue, cubs_interpreter_stack_value_at(operands.offsetFromFrameStart), sizeof(size_t));
                    } else {
                        threadLocalRegisters.registers[operands.dst].ptr = cubs_interpreter_stack_value_at(operands.offsetFromFrameStart);
                    }
                    threadLocalRegisters.registerValueTags[operands.dst] = stackValueTag;
                }
            }
        } break;
        default: {
            unreachable();
        } break;
    }
    threadLocalRegisters.instructionPointer = &threadLocalRegisters.instructionPointer[ipIncrement];
    return cubsFatalScriptErrorNone;
}

InterpreterRegister cubs_interpreter_register_value_at(size_t registerIndex){
    return threadLocalRegisters.registers[registerIndex];
}

CubsValueTag cubs_interpreter_register_value_tag_at(size_t registerIndex)
{
    return (CubsValueTag)(threadLocalRegisters.registerValueTags[registerIndex]);
}
