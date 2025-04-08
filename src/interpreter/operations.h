#include "bytecode.h"
#include "../primitives/function/function.h"

#define XSTRINGIFY(s) str(s)
#define STRINGIFY(s) #s
#define VALIDATE_SIZE_ALIGN_OPERANDS(OperandsT) \
_Static_assert(sizeof(OperandsT) <= sizeof(Bytecode), "Size of " STRINGIFY(OperandsT) " must be less than or equal to Bytecode"); \
_Static_assert(_Alignof(OperandsT) <= _Alignof(Bytecode), "Align of " STRINGIFY(OperandsT) " must be less than or equal to Bytecode");

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
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsJump);

/// If `jumpType == JUMP_TYPE_DEFAULT`, `jumpSrc` is ignored.
/// Jump amount is any 32 bit signed integer, but must be in range of function bytecode.
Bytecode cubs_operands_make_jump(enum JumpType jumpType, int32_t jumpAmount, uint16_t jumpSrc);

#pragma endregion

#pragma region Sync

enum SyncType {
    SYNC_TYPE_SYNC = 0,
    SYNC_TYPE_UNSYNC = 1,

    RESERVE_BITS_SYNC_TYPE = 1,
};

enum SyncLockType {
    SYNC_LOCK_TYPE_READ = 0,
    SYNC_LOCK_TYPE_WRITE = 1,

    RESERVE_BITS_SYNC_LOCK_TYPE = 1,
};

typedef struct {
    uint16_t src;
    enum SyncLockType lock;
} SyncLockSource;

typedef struct {
    uint16_t src: BITS_PER_STACK_OPERAND;
    uint16_t lock: RESERVE_BITS_SYNC_LOCK_TYPE;
} OperandsSyncLockSource;
_Static_assert(sizeof(OperandsSyncLockSource) == sizeof(uint16_t), "SyncLockSource must only occupy 2 bytes");

/// Holds the first and second sources inline the operands. Any further sync sources will need
typedef struct {
    uint16_t reserveOpcode: OPCODE_USED_BITS;
    uint16_t opType: RESERVE_BITS_SYNC_TYPE;
    /// If `opType == SYNC_TYPE_SYNC`, is the amount of things to lock and is always non-zero, otherwise unused. 
    uint16_t num: BITS_PER_STACK_OPERAND;
    /// If `opType != SYNC_TYPE_SYNC`, unused. Inline the first sync source in the operands. Is an instance of SyncLockSource.
    /// Guaranteed to be used.
    OperandsSyncLockSource src1;
    /// If `opType != SYNC_TYPE_SYNC`, unused. Inline the second sync source in the operands. Is an instance of SyncLockSource.
    OperandsSyncLockSource src2;
} OperandsSync;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsSync);

size_t cubs_operands_sync_bytecode_required(uint16_t numSources);

/// Reads up to `sources[num - 1]`
/// @return The number of bytecode actually used. See `cubs_operands_sync_bytecode_required(...)`.
size_t cubs_operands_make_sync(Bytecode* bytecodeArr, size_t availableBytecode, enum SyncType syncType, uint16_t num, const SyncLockSource* sources);

#pragma endregion

#pragma region Deinit

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t src: BITS_PER_STACK_OPERAND;
} OperandsDeinit;

Bytecode cubs_operands_make_deinit(uint16_t src);

#pragma endregion

#pragma region Move

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t src: BITS_PER_STACK_OPERAND;
} OperandsMove;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsMove);
/// Debug asserts `dst != src`.
Bytecode cubs_operands_make_move(uint16_t dst, uint16_t src);

#pragma endregion

#pragma region Clone

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t src: BITS_PER_STACK_OPERAND;
} OperandsClone;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsClone);
/// Debug asserts `dst != src`.
Bytecode cubs_operands_make_clone(uint16_t dst, uint16_t src);

#pragma endregion

#pragma region Compare

enum CompareOperationType {
    COMPARE_OP_EQUAL = 0,
    COMPARE_OP_NOT_EQUAL = 1,
    COMPARE_OP_LESS = 2,
    COMPARE_OP_GREATER = 3,
    COMPARE_OP_LESS_OR_EQUAL = 4,
    COMPARE_OP_GREATER_OR_EQUAL = 5,
};

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t src1: BITS_PER_STACK_OPERAND;
    uint64_t src2: BITS_PER_STACK_OPERAND;
} OperandsUnknownCompare;

typedef OperandsUnknownCompare OperandsEqual;
typedef OperandsUnknownCompare OperandsNotEqual;

Bytecode cubs_operands_make_compare(enum CompareOperationType compareType, uint16_t dst, uint16_t src1, uint16_t src2);

#pragma endregion

#pragma region Reference

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t src: BITS_PER_STACK_OPERAND;
} OperandsDereference;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsDereference);

Bytecode cubs_operands_make_dereference(uint16_t dst, uint16_t src);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t src: BITS_PER_STACK_OPERAND;   
} OperandsSetReference;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsSetReference);

Bytecode cubs_operands_make_set_reference(uint16_t dst, uint16_t src);

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t src: BITS_PER_STACK_OPERAND;
    uint64_t mutable: 1;
} OperandsMakeReference;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsMakeReference);

Bytecode cubs_operands_make_reference(uint16_t dst, uint16_t src, bool mutable);

#pragma endregion

#pragma region Members

/// Allows 2^16 (65536) total members in a struct
#define BITS_PER_MEMBER_INDEX 16

typedef struct {
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t src: BITS_PER_STACK_OPERAND;
    uint64_t memberIndex: BITS_PER_MEMBER_INDEX;
} OperandsGetMember;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsGetMember);

/// `index` is a literal value
Bytecode cubs_operands_make_get_member(uint16_t dst, uint16_t src, uint16_t memberIndex);

typedef struct {   
    uint64_t reserveOpcode: OPCODE_USED_BITS;
    uint64_t dst: BITS_PER_STACK_OPERAND;
    uint64_t src: BITS_PER_STACK_OPERAND;
    uint64_t memberIndex: BITS_PER_MEMBER_INDEX;
} OperandsSetMember;
VALIDATE_SIZE_ALIGN_OPERANDS(OperandsSetMember);

/// `index` is a literal value
Bytecode cubs_operands_make_set_member(uint16_t dst, uint16_t src, uint16_t memberIndex);

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