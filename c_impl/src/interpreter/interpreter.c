#include "interpreter.h"
#include "bytecode.h"
#include <stdio.h>
#include "../util/unreachable.h"
#include <assert.h>
#include "../program/program.h"
#include "../primitives/value_tag.h"
#include <string.h>
#include "../primitives/script_value.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"
#include "../primitives/set/set.h"
#include "../primitives/map/map.h"

extern void* _cubs_os_aligned_malloc(size_t len, size_t align);
extern void* _cubs_os_aligned_free(void *buf, size_t len, size_t align);

static const size_t OLD_INSTRUCTION_POINTER = 0;
static const size_t OLD_FRAME_LENGTH = 1;
static const size_t OLD_RETURN_VALUE_DST = 2;
static const size_t OLD_RETURN_TAG_DST = 3;
static const size_t RESERVED_SLOTS = 4;

typedef struct InterpreterStackState {
    const Bytecode* instructionPointer;
    /// Offset from `stack` and `tags` indicated where the next frame should start
    size_t nextBaseOffset;
    InterpreterStackFrame frame;
    size_t stack[CUBS_STACK_SLOTS];
    uint8_t tags[CUBS_STACK_SLOTS];
} InterpreterStackState;

static _Thread_local InterpreterStackState threadLocalStack = {0};

void cubs_interpreter_push_frame(size_t frameLength, const struct Bytecode* oldInstructionPointer, void* returnValueDst, uint8_t* returnTagDst) {
    assert(frameLength <= MAX_FRAME_LENGTH);
    { // store previous instruction pointer, frame length, return dst, and return tag dst
        size_t* basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.nextBaseOffset];
        if(threadLocalStack.nextBaseOffset == 0) {
            basePointer[OLD_INSTRUCTION_POINTER]    = 0;
            basePointer[OLD_FRAME_LENGTH]           = 0;
            basePointer[OLD_RETURN_VALUE_DST]       = 0;
            basePointer[OLD_RETURN_TAG_DST]         = 0;
        } else {
            basePointer[OLD_INSTRUCTION_POINTER]    = (size_t)((const void*)oldInstructionPointer); // cast ptr to size_t
            basePointer[OLD_FRAME_LENGTH]           = threadLocalStack.frame.frameLength;
            basePointer[OLD_RETURN_VALUE_DST]       = (size_t)threadLocalStack.frame.returnValueDst;
            basePointer[OLD_RETURN_TAG_DST]         = (size_t)threadLocalStack.frame.returnTagDst;
        }
    }

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = frameLength,
        .returnValueDst = returnValueDst,
        .returnTagDst = returnTagDst
    };
    threadLocalStack.frame = newFrame;
    threadLocalStack.nextBaseOffset += frameLength + RESERVED_SLOTS;  
}

void cubs_interpreter_pop_frame()
{
    assert(threadLocalStack.nextBaseOffset != 0 && "No more frames to pop!");

    const size_t offset = threadLocalStack.frame.frameLength + RESERVED_SLOTS;

    threadLocalStack.nextBaseOffset -= offset;
    if(threadLocalStack.nextBaseOffset == 0) {
        return;
    }

    size_t* basePointer = &((size_t*)threadLocalStack.stack)[threadLocalStack.frame.basePointerOffset];
    const size_t oldInstructionPointer = basePointer[OLD_INSTRUCTION_POINTER];
    const size_t oldFrameLength = basePointer[OLD_FRAME_LENGTH];
    void* const oldReturnValueDst = (void*)basePointer[OLD_RETURN_VALUE_DST];
    uint8_t* const oldReturnTagDst = (uint8_t*)basePointer[OLD_RETURN_TAG_DST];

    const InterpreterStackFrame newFrame = {
        .basePointerOffset = threadLocalStack.nextBaseOffset,
        .frameLength = oldFrameLength,
        .returnValueDst = oldReturnValueDst,
        .returnTagDst = oldReturnTagDst
    };   
    threadLocalStack.frame = newFrame;
}

InterpreterStackFrame cubs_interpreter_current_stack_frame()
{
    return threadLocalStack.frame;
}

void *cubs_interpreter_stack_value_at(size_t offset)
{
    assert(offset < threadLocalStack.frame.frameLength);
    return (void*)(&threadLocalStack.stack[threadLocalStack.frame.basePointerOffset + offset]);
}

CubsValueTag cubs_interpreter_stack_tag_at(size_t offset)
{
    assert(offset < threadLocalStack.frame.frameLength);
    const uint8_t tag = threadLocalStack.tags[threadLocalStack.frame.basePointerOffset + offset];
    return (CubsValueTag)tag;
}

void cubs_interpreter_stack_set_tag_at(size_t offset, CubsValueTag tag)
{
    assert(offset < threadLocalStack.frame.frameLength);
    const uint8_t tagAs8 = (uint8_t)tag;
    threadLocalStack.tags[threadLocalStack.frame.basePointerOffset + offset] = tagAs8;
}

void cubs_interpreter_set_instruction_pointer(const Bytecode *newIp)
{
    assert(newIp != NULL);
    threadLocalStack.instructionPointer = newIp;
}

static void execute_load(size_t* ipIncrement, const Bytecode* bytecode) {
    const OperandsLoadUnknown unknownOperands = *(const OperandsLoadUnknown*)bytecode;

    switch(unknownOperands.loadType) {
        case LOAD_TYPE_IMMEDIATE: {
            const OperandsLoadImmediate operands = *(const OperandsLoadImmediate*)bytecode;

            switch(operands.immediateType) {
                case LOAD_IMMEDIATE_BOOL: {
                    *((bool*)cubs_interpreter_stack_value_at(operands.dst)) = operands.immediate != 0;
                    cubs_interpreter_stack_set_tag_at(operands.dst, cubsValueTagBool);
                } break;
                case LOAD_IMMEDIATE_INT: {
                    *((int64_t*)cubs_interpreter_stack_value_at(operands.dst)) = (int64_t)operands.immediate;
                    cubs_interpreter_stack_set_tag_at(operands.dst, cubsValueTagInt);
                } break;
                default: {
                    unreachable();
                } break;
            }
        } break;
        case LOAD_TYPE_IMMEDIATE_LONG: {
            const OperandsLoadImmediateLong operands = *(const OperandsLoadImmediateLong*)bytecode;
            assert(operands.immediateValueTag != _CUBS_VALUE_TAG_NONE);
            assert(operands.immediateValueTag != cubsValueTagBool && "Don't use 64 bit immediate load for booleans");

            const uint64_t immediate = threadLocalStack.instructionPointer[1].value;
            *((uint64_t*)cubs_interpreter_stack_value_at(operands.dst)) = immediate; // will reinterpret cast
            cubs_interpreter_stack_set_tag_at(operands.dst, operands.immediateValueTag);      
            (*ipIncrement) += 1; // move instruction pointer further into the bytecode
        } break;
        case LOAD_TYPE_DEFAULT: {
            const OperandsLoadDefault operands = *(const OperandsLoadDefault*)bytecode;
            assert(operands.tag != _CUBS_VALUE_TAG_NONE);
            
            void* dst = cubs_interpreter_stack_value_at(operands.dst);

            switch(operands.tag) {
                case cubsValueTagBool: {
                    *(bool*)dst = false;
                } break;
                case cubsValueTagInt: {
                    *(int64_t*)dst = 0;
                } break;
                case cubsValueTagFloat: {
                    *(double*)dst = 0;
                } break;
                case cubsValueTagChar: {
                    *(size_t*)dst = 0;
                } break;
                case cubsValueTagString: {
                    const CubsString defaultString = {0};
                    *(CubsString*)dst = defaultString;
                    _Static_assert(sizeof(CubsString) == (4 * sizeof(size_t)), "");
                    // Must make sure the slots that the string uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagArray: {
                    assert(operands.keyTag != _CUBS_VALUE_TAG_NONE);
                    assert(operands.keyTag != cubsValueTagUserStruct);
                    *(CubsArray*)dst = cubs_array_init_primitive(operands.keyTag);
                    _Static_assert(sizeof(CubsArray) == (4 * sizeof(size_t)), "");
                    // Must make sure the slots that the array uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagSet: {
                    assert(operands.keyTag != _CUBS_VALUE_TAG_NONE);
                    assert(operands.keyTag != cubsValueTagUserStruct);
                    *(CubsSet*)dst = cubs_set_init(operands.keyTag);
                    _Static_assert(sizeof(CubsSet) == (4 * sizeof(size_t)), "");
                    // Must make sure the slots that the set uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagMap: {
                    assert(operands.keyTag != _CUBS_VALUE_TAG_NONE);
                    assert(operands.valueTag != _CUBS_VALUE_TAG_NONE);
                    if(operands.keyTag != cubsValueTagUserStruct && operands.valueTag != cubsValueTagUserStruct) {
                        *(CubsMap*)dst = cubs_map_init_primitives(operands.keyTag, operands.valueTag);
                    } else {
                        cubs_panic("Map initialization not done for user structs");
                    }
                    
                    _Static_assert(sizeof(CubsMap) == (8 * sizeof(size_t)), "");
                    // Must make sure the slots that the map uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 4, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 5, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 6, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 7, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagOption: {
                    const CubsOption nullOption = {0};
                    *(CubsOption*)dst = nullOption;
                    _Static_assert(sizeof(CubsOption) == (5 * sizeof(size_t)), "");
                    // Must make sure the slots that the string uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 4, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagError: {
                    const CubsError defaultError = {0};
                    *(CubsError*)dst = defaultError;
                    _Static_assert(sizeof(CubsError) == (5 * sizeof(size_t)), "");
                    // Must make sure the slots that the string uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 4, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec2i: {
                    const CubsVec2i zeroVec = {0};
                    *(CubsVec2i*)dst = zeroVec;
                    _Static_assert(sizeof(CubsVec2i) == (2 * sizeof(size_t)), "");
                    // Must make sure the slots that the array uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec3i: {
                    const CubsVec3i zeroVec = {0};
                    *(CubsVec3i*)dst = zeroVec;
                    _Static_assert(sizeof(CubsVec3i) == (3 * sizeof(size_t)), "");
                    // Must make sure the slots that the array uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec4i: {
                    const CubsVec4i zeroVec = {0};
                    *(CubsVec4i*)dst = zeroVec;
                    _Static_assert(sizeof(CubsVec4i) == (4 * sizeof(size_t)), "");
                    // Must make sure the slots that the array uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 4, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec2f: {
                    const CubsVec2f zeroVec = {0};
                    *(CubsVec2f*)dst = zeroVec;
                    _Static_assert(sizeof(CubsVec2f) == (2 * sizeof(size_t)), "");
                    // Must make sure the slots that the array uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec3f: {
                    const CubsVec3f zeroVec = {0};
                    *(CubsVec3f*)dst = zeroVec;
                    _Static_assert(sizeof(CubsVec3f) == (3 * sizeof(size_t)), "");
                    // Must make sure the slots that the array uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                } break;
                case cubsValueTagVec4f: {
                    const CubsVec4f zeroVec = {0};
                    *(CubsVec4f*)dst = zeroVec;
                    _Static_assert(sizeof(CubsVec4f) == (4 * sizeof(size_t)), "");
                    // Must make sure the slots that the array uses are unused
                    cubs_interpreter_stack_set_tag_at(operands.dst + 1, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 2, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 3, _CUBS_VALUE_TAG_NONE);
                    cubs_interpreter_stack_set_tag_at(operands.dst + 4, _CUBS_VALUE_TAG_NONE);
                } break;
                default: {
                    cubs_panic("unimplemented default initialization for type");
                } break;
            }
            cubs_interpreter_stack_set_tag_at(operands.dst, operands.tag);
        } break;
        case LOAD_TYPE_CLONE_FROM_PTR: {
            const OperandsLoadImmediateLong operands = *(const OperandsLoadImmediateLong*)bytecode;
            assert(operands.immediateValueTag != _CUBS_VALUE_TAG_NONE);

            const void* immediate = (const void*)(uintptr_t)threadLocalStack.instructionPointer[1].value;     
            void* dst = cubs_interpreter_stack_value_at(operands.dst);

            switch(operands.immediateValueTag) {
                case cubsValueTagBool: {
                    memcpy(dst, immediate, sizeof(bool));
                } break;
                case cubsValueTagInt: {
                    memcpy(dst, immediate, sizeof(int64_t));
                } break;
                case cubsValueTagFloat: {
                    memcpy(dst, immediate, sizeof(double));
                } break;
                case cubsValueTagChar: {
                    memcpy(dst, immediate, sizeof(size_t));
                } break;
                case cubsValueTagString: {
                    const CubsString temp = cubs_string_clone((const CubsString*)immediate);
                    *(CubsString*)dst = temp;
                } break;
                case cubsValueTagVec2i: {
                    memcpy(dst, immediate, sizeof(CubsVec2i));
                } break;
                case cubsValueTagVec3i: {
                    memcpy(dst, immediate, sizeof(CubsVec3i));
                } break;
                case cubsValueTagVec4i: {
                    memcpy(dst, immediate, sizeof(CubsVec4i));
                } break;
                case cubsValueTagVec2f: {
                    memcpy(dst, immediate, sizeof(CubsVec2f));
                } break;
                case cubsValueTagVec3f: {
                    memcpy(dst, immediate, sizeof(CubsVec3f));
                } break;
                case cubsValueTagVec4f: {
                    memcpy(dst, immediate, sizeof(CubsVec4f));
                } break;
                default: {
                    cubs_panic("unimplemented default initialization for type");
                } break;
            }
            cubs_interpreter_stack_set_tag_at(operands.dst, operands.immediateValueTag);      
            (*ipIncrement) += 1; // move instruction pointer further into the bytecode
        } break;
        default: {
            unreachable();
        } break;
    }
}

CubsFatalScriptError cubs_interpreter_execute_operation(const CubsProgram *program)
{
    size_t ipIncrement = 1;
    const Bytecode bytecode = *threadLocalStack.instructionPointer;
    const OpCode opcode = cubs_bytecode_get_opcode(bytecode);
    switch(opcode) {
        case OpCodeNop: {
            fprintf(stderr, "nop :)\n");
        } break;
        case OpCodeLoad: {
            execute_load(&ipIncrement, &bytecode);
        } break;
        default: {
            unreachable();
        } break;
    }
    threadLocalStack.instructionPointer = &threadLocalStack.instructionPointer[ipIncrement];
    return cubsFatalScriptErrorNone;
}