#include "bytecode.h"
#include "../primitives/function/function.h"

#define XSTRINGIFY(s) str(s)
#define STRINGIFY(s) #s
#define VALIDATE_SIZE_ALIGN_OPERANDS(OperandsT) \
_Static_assert(sizeof(OperandsT) == sizeof(Bytecode), "Size of " STRINGIFY(OperandsT) " must match that of InterpreterBytecode"); \
_Static_assert(_Alignof(OperandsT) == _Alignof(Bytecode), "Align of " STRINGIFY(OperandsT) " must match that of InterpreterBytecode");

enum LoadOperationType {
    LOAD_TYPE_IMMEDIATE = 0,
    LOAD_TYPE_IMMEDIATE_LONG = 1,
    LOAD_TYPE_DEFAULT = 2,
    LOAD_TYPE_CLONE_FROM_PTR = 3,

    RESERVE_LOAD_TYPE = 2,
};

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t loadType: RESERVE_LOAD_TYPE;
} OperandsLoadUnknown;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadUnknown);

#define LOAD_IMMEDIATE_BOOL 0
#define LOAD_IMMEDIATE_INT 1
typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: RESERVE_LOAD_TYPE;
    uint64_t immediateType: 1;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    int64_t immediate: 40;
} OperandsLoadImmediate;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadImmediate);
/// For a floating point immediate, must be a whole number
Bytecode operands_make_load_immediate(int immediateType, uint16_t dst, int64_t immediate);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: RESERVE_LOAD_TYPE;
    uint64_t immediateValueTag: 6; // CubsValueTag
    uint64_t dst: BITS_PER_STACK_OPERAND;
} OperandsLoadImmediateLong;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadImmediateLong);
/// @param doubleBytecode must be a pointer to at least 2 bytecodes
void operands_make_load_immediate_long(Bytecode* doubleBytecode, CubsValueTag tag, uint16_t dst, size_t immediate);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: RESERVE_LOAD_TYPE;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t tag: 6;
} OperandsLoadDefault;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsLoadDefault);
/// If `tag` is a generic type that IS NOT `cubsValueTagMap`, `multiBytecode` must be a pointer to at least 2 bytecodes. 
/// If `tag == cubsValueTagMap`, `multiBytecode` must be a pointer to at least 3 bytecodes. 
/// Otherwise, `multiBytecode` is treated as a single pointer.
void operands_make_load_default(Bytecode* multiBytecode, CubsValueTag tag, uint16_t dst, const CubsTypeContext* optKeyContext, const CubsTypeContext* optValueContext);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t reserveLoadType: RESERVE_LOAD_TYPE;
    uint64_t dst: BITS_PER_STACK_OPERAND;
} OperandsLoadCloneFromPtr;
void operands_make_load_clone_from_ptr(Bytecode* tripleBytecode, uint16_t dst, const void* immediatePtr, const CubsTypeContext* context);

#pragma region Return

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t hasReturn: 1;
    uint64_t returnSrc: BITS_PER_STACK_OPERAND;
} OperandsReturn;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsReturn);
/// If `hasReturn == false`, `returnSrc` is ignored.
Bytecode operands_make_return(bool hasReturn, uint16_t returnSrc);

#pragma endregion Return

#pragma region Call

enum CallType {
    CALL_TYPE_IMMEDIATE = 0,
    CALL_TYPE_SRC = 1,

    RESERVE_BITS_CALL_TYPE = 1,
};

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_BITS_CALL_TYPE;
    uint64_t argCount: BITS_PER_STACK_OPERAND;
    /// Boolean flag
    uint64_t hasReturn: 1;
    uint64_t returnDst: BITS_PER_STACK_OPERAND;
} OperandsCallUnknown;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsCallUnknown);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_BITS_CALL_TYPE;
    uint64_t argCount: BITS_PER_STACK_OPERAND;
    /// Boolean flag
    uint64_t hasReturn: 1;
    uint64_t returnDst: BITS_PER_STACK_OPERAND;
    uint64_t funcType: _CUBS_FUNCTION_PTR_TYPE_USED_BITS;
} OperandsCallImmediate;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsCallImmediate);

/// If hasReturn == false, returnSrc is ignored.
void cubs_operands_make_call_immediate(Bytecode* bytecodeArr, size_t availableBytecode, uint16_t argCount, const uint16_t* args, bool hasReturn, uint16_t returnSrc, CubsFunction func);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_BITS_CALL_TYPE;
    uint64_t argCount: BITS_PER_STACK_OPERAND;
    /// Boolean flag
    uint64_t hasReturn: 1;
    uint64_t returnDst: BITS_PER_STACK_OPERAND;
    uint64_t funcSrc: BITS_PER_STACK_OPERAND;
} OperandsCallSrc;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsCallSrc);

/// If hasReturn == false, returnSrc is ignored.
void cubs_operands_make_call_src(Bytecode* bytecodeArr, size_t availableBytecode, uint16_t argCount, const uint16_t* args, bool hasReturn, uint16_t returnSrc, uint16_t funcSrc);

#pragma endregion

#pragma region Jump

enum JumpType {
    JUMP_TYPE_DEFAULT = 0,
    JUMP_TYPE_IF_TRUE = 1,
    JUMP_TYPE_IF_FALSE = 2,

    RESERVE_BITS_JUMP_TYPE = 2,
};

/// Jump operation can jump up to UINT32_MAX instructions at once. 
typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_BITS_JUMP_TYPE;
    /// Only used for conditional jumps
    uint64_t optSrc: BITS_PER_STACK_OPERAND;
    int64_t jumpAmount: 32;
} OperandsJump;

/// If `jumpType == JUMP_TYPE_DEFAULT`, `jumpSrc` is ignored.
/// Jump amount is any 32 bit signed integer, but must be in range of function bytecode.
Bytecode cubs_operands_make_jump(enum JumpType jumpType, int32_t jumpAmount, uint16_t jumpSrc);

#pragma endregion

#pragma region Deinit

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t src: BITS_PER_STACK_OPERAND;
} OperandsDeinit;

Bytecode cubs_operands_make_deinit(uint16_t src);

#pragma endregion

enum MathOperationType {
    MATH_TYPE_DST,
    MATH_TYPE_SRC_ASSIGN,
    
    RESERVE_MATH_OP_TYPE = 1,
};

#pragma region Increment

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    uint64_t canOverflow: 1;
    uint64_t src: BITS_PER_STACK_OPERAND;
} OperandsIncrementUnknown;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsIncrementUnknown);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    /// Only used for integer types (int, vec)
    uint64_t canOverflow: 1;
    uint64_t src: BITS_PER_STACK_OPERAND;
    uint64_t dst: BITS_PER_STACK_OPERAND;
} OperandsIncrementDst;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsIncrementDst);
Bytecode operands_make_increment_dst(bool canOverflow, uint16_t dst, uint16_t src);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    /// Only used for integer types (int, vec)
    uint64_t canOverflow: 1;
    uint64_t src: BITS_PER_STACK_OPERAND;
} OperandsIncrementAssign;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsIncrementAssign);
Bytecode operands_make_increment_assign(bool canOverflow, uint16_t src);

#pragma endregion Increment

#pragma region Add

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    /// Only used for integer types (int, vec)
    uint64_t canOverflow: 1;
    uint64_t src1: BITS_PER_STACK_OPERAND;
    uint64_t src2: BITS_PER_STACK_OPERAND;
} OperandsAddUnknown;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsAddUnknown);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    /// Only used for integer types (int, vec)
    uint64_t canOverflow: 1;
    uint64_t src1: BITS_PER_STACK_OPERAND;
    uint64_t src2: BITS_PER_STACK_OPERAND;
    uint64_t dst: BITS_PER_STACK_OPERAND;
} OperandsAddDst;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsAddDst);
Bytecode operands_make_add_dst(bool canOverflow, uint16_t dst, uint16_t src1, uint16_t src2);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t opType: RESERVE_MATH_OP_TYPE;
    /// Only used for integer types (int, vec)
    uint64_t canOverflow: 1;
    uint64_t src1: BITS_PER_STACK_OPERAND;
    uint64_t src2: BITS_PER_STACK_OPERAND;
} OperandsAddAssign;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsAddAssign);
Bytecode operands_make_add_assign(bool canOverflow, uint16_t src1, uint16_t src2);