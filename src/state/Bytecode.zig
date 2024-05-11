const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const CubicScriptState = @import("CubicScriptState.zig");

const Self = @This();

value: u32,

pub fn encode(opcode: OpCode, operands: anytype) Self {
    const OperandsT: type = @TypeOf(operands);
    validateOpCodeMatchesOperands(opcode, OperandsT);
    if (OperandsT == void) {
        return Self{ .value = @as(u32, @intFromEnum(opcode)) };
    } else {
        if (@bitSizeOf(OperandsT) > 24) {
            @compileError("Operands type must be a packed struct with a bit size <= 24");
        }

        const operandsAsNum: IntegerFromBitWidth(@bitSizeOf(OperandsT)) = @bitCast(operands);
        const operandsAsU32: u32 = @intCast(operandsAsNum);
        return Self{ .value = @as(u32, @intFromEnum(opcode)) | @shlExact(operandsAsU32, 8) };
    }
}

const LOW_MASK = 0xFFFFFFFF;
const HIGH_MASK = @shlExact(0xFFFFFFFF, 32);

pub fn encodeImmediateLower(comptime T: type, immediate: T) Self {
    if (T == bool) {
        const immediateBits: usize = @intFromBool(immediate);
        return Self{ .value = @intCast(immediateBits & LOW_MASK) };
    } else if (@sizeOf(T) != 8) {
        @compileError("Invalid immediate type. Must be 8 bytes in size or boolean");
    }
    const info = @typeInfo(T);
    if (info == .Pointer) {
        const immediateBits: usize = @intFromPtr(immediate);
        return Self{ .value = @intCast(immediateBits & LOW_MASK) };
    } else {
        const immediateBits: usize = @bitCast(immediate);
        return Self{ .value = @intCast(immediateBits & LOW_MASK) };
    }
}

pub fn encodeImmediateUpper(comptime T: type, immediate: T) Self {
    if (T == bool) {
        const immediateBits: usize = @intFromBool(immediate);
        return Self{ .value = @intCast(@shrExact(immediateBits & HIGH_MASK, 32)) };
    } else if (@sizeOf(T) != 8) {
        @compileError("Invalid immediate type. Must be 8 bytes in size or boolean");
    }
    const info = @typeInfo(T);
    if (info == .Pointer) {
        const immediateBits: usize = @intFromPtr(immediate);
        return Self{ .value = @intCast(@shrExact(immediateBits & HIGH_MASK, 32)) };
    } else {
        const immediateBits: usize = @bitCast(immediate);
        return Self{ .value = @intCast(@shrExact(immediateBits & HIGH_MASK, 32)) };
    }
}

/// For odd number of function arguments, just pass in `null` for arg2.
/// This encoding should occur AFTER a `Call` bytecode, as depending on the
/// `argCount` for the call, the bytecodes after will be interpreted as `FunctionArg`
pub fn encodeFunctionArgPair(arg1: FunctionArg, arg2: ?FunctionArg) Self {
    const arg1Bits: u16 = @bitCast(arg1);
    const arg2Bits: u16 = blk: {
        if (arg2 != null) {
            break :blk @bitCast(arg2.?);
        } else {
            break :blk 0;
        }
    };
    return Self{ .value = @as(u32, arg1Bits) | @shlExact(@as(u32, arg2Bits), 16) };
}

pub fn encodeCallImmediateLower(callData: CallImmediate) Self {
    const immediateBits: usize = @bitCast(callData);
    return Self{ .value = @intCast(immediateBits & LOW_MASK) };
}

pub fn encodeCallImmediateUpper(callData: CallImmediate) Self {
    const immediateBits: usize = @bitCast(callData);
    return Self{ .value = @intCast(@shrExact(immediateBits & HIGH_MASK, 32)) };
}

pub fn decode(self: *const Self, comptime OperandsT: type) OperandsT {
    if (OperandsT == void) {
        return;
    } else {
        if (@bitSizeOf(OperandsT) > 24) {
            @compileError("Operands type must be a packed struct with a bit size <= 24");
        }
        const operands = @shrExact(self.value & 0xFFFFFF00, 8);
        return @bitCast(@as(IntegerFromBitWidth(@bitSizeOf(OperandsT)), @intCast(operands)));
    }
}

/// For multiple byte-code wide instructions, getting the opcode is undefined behaviour.
pub fn getOpCode(self: Self) OpCode {
    return @enumFromInt(self.value & 0xFF);
}

// https://the-ravi-programming-language.readthedocs.io/en/latest/lua_bytecode_reference.html

// ! Load and store operations are not necessary since the script will not do direct memory access,
// ! instead they will go through classes, arrays, or other structures.

/// Instructions are variable width, but generally 4 bytes in size.
/// All 4 byte bytecodes are in one of 3 patterns, where Op is the 1 byte instruction
/// > Op A B C
/// >
/// > Op A B
/// >
/// > Op A
///
/// All Bytecodes follow the format I, dst, src1, src2, where DST is always A, src1 is always B, and src2 is always C.
/// If there is only one `src`, and there is a `dst`, `src` occupies B.
pub const OpCode = enum(u8) {
    // == GENERAL INSTRUCTIONS ==

    /// No operation. Allows 0 set memory to be a technically valid program.
    /// TODO remove this.
    Nop,
    /// Move value between registers src and dst.
    /// TODO figure out how to handle ownership movement? For example with moving a string to another register?
    Move,
    /// Set the register `dst` to zero. Uses `OperandsZero`
    LoadZero,
    /// Load an immediate bool/int/float into `dst`.
    /// The immediate value will be cast to the correct value.
    LoadImmediate,
    /// Load the 64 bit immediate into `dst`. This is a 12 byte instruction.
    /// The immediate value is NOT cast, rather simply has the bits interpreted as whatever type.
    LoadImmediateLong,
    /// Unconditionally jump to `dst`
    Jump,
    /// Jump to `dst` if `src` is 0.
    ///
    /// For comparison `Ordering` prior to calling this `OpCode`, such as string compare:
    /// - `<` performing an `.IntIsEqual` on the immediate `-1` will determine if the ordering value is less than.
    /// - `>` performing an `.IntIsEqual` on the immediate `1` will determine if the ordering value is less than.
    /// - `<=` performing an `.IntIsLessOrEqual` on the immediate `0` will determine if the ordering value is less or equal.
    /// - `>=` performing an `.IntGreaterOrEqual` on the immediate `0` will determine if the ordering value is greater or equal.
    JumpIfZero,
    /// Jump to `dst` if `src` is NOT 0.
    ///
    /// For comparison `Ordering` prior to calling this `OpCode`, such as string compare:
    /// - `<` performing an `.IntIsEqual` on the immediate `-1` will determine if the ordering value is less than.
    /// - `>` performing an `.IntIsEqual` on the immediate `1` will determine if the ordering value is less than.
    /// - `<=` performing an `.IntIsLessOrEqual` on the immediate `0` will determine if the ordering value is less or equal.
    /// - `>=` performing an `.IntGreaterOrEqual` on the immediate `0` will determine if the ordering value is greater or equal.
    JumpIfNotZero,
    /// Return from the calling function, moving the instruction pointer back to the calling function,
    /// or terminating the script if it was called by an owning process.
    /// Uses `OperandsOptionalReturn` or `void` operands. `OperandsOptionalReturn` specifies that the function
    /// may return if `.valueTag` is not `.None`, while `void` specifies no return value at all.
    /// if no value is returned. If the return value exists, copies `src` to a temporary location,
    /// returns to the previous stack frame, and sets `dst` to the return value.
    Return,
    /// Uses `OperandsFunctionArgs` along with `CallImmediate`. This is a multibyte instruction.
    /// Depending on the amount of function args, will read more bytecodes as argument information.
    /// This is in the form `FunctionArg`, where the bytecodes will be interpreted as a pointer to an array of them.
    /// Call a function at `src`, moving the stack pointer, and setting the return address.
    Call,
    /// Deinitializes the value at register `src`, using `tag`. Uses `OperandsSrcTag`.
    /// Sets the register tag to `.None`. Works with zeroed memory as well.
    Deinit,
    /// Multibyte instruction. Uses `OperandsSync` to determine how long the instruction is.
    /// If `.count` of `OperandsSync` is 1, uses the immediate sync data to synchronize just that one object.
    /// If `.count` is not 1, will read the immediate, along with the following bytecodes as an array of `OperandsSync.SyncModifier`.
    Sync,
    /// Uses `void` operands.
    Unsync,
    /// Casts `src` to `dst` where the `src` type is the register tag, and the `dst` type is `tag`.
    /// Works with casting types to strings, but when casting strings to a type, it'll return a result.
    ///
    /// Technical Note:
    /// While specializing a bunch of different cast instructions could be argued to be more performant, the difference in practice would be minimal,
    /// and in the end would result in many more instructions that need to be accounted for and maintained in the future.
    Cast,

    /// Checks the values at `src1` and `src2` for equality, storing the boolean result in `dst`.
    /// The type of comparison used depends on the register tags. Is implemented for bool, int, float, string, and array
    /// currently.
    Equal,
    /// Checks the values at `src1` and `src2` for inequality, storing the boolean result in `dst`.
    /// The type of comparison used depends on the register tags. Is implemented for bool, int, float, string, and array
    /// currently.
    NotEqual,
    /// Checks if `src1` is less than `src2`, storing the boolean result in `dst`.
    /// The type of comparison used depends on the register tags. Is implemented for bool, int, float, and string, currently.
    Less,
    /// Checks if `src1` is greater than `src2`, storing the boolean result in `dst`.
    /// The type of comparison used depends on the register tags. Is implemented for bool, int, float, and string, currently.
    Greater,
    /// Checks if `src1` is less than or equal to `src2`, storing the boolean result in `dst`.
    /// The type of comparison used depends on the register tags. Is implemented for bool, int, float, and string, currently.
    LessOrEqual,
    /// Checks if `src1` is greater than or equal to `src2`, storing the boolean result in `dst`.
    /// The type of comparison used depends on the register tags. Is implemented for bool, int, float, and string, currently.
    GreaterOrEqual,
    /// Adds `src2` to `src1`, storing the result in `dst`. The functionality is dependent on the register tags.
    /// For both ints and floats, its numerical addition with overflow checks for ints. For strings, `src2` is appended to `src1`.
    Add,
    /// Subtracts `src2` from `src1`, storing the result in `dst`. The functionality is dependent on the register tags.
    /// For ints, numerical subtraction is used with overflow checks. For floats, numerical subtraction is also used but without any overflow checks naturally.
    Subtract,
    /// Multiplies `src1` and `src2`, storing the result in `dst`. The functionality is dependent on the register tags.
    /// For both ints and floats, its numerical multiplication with overflow checks for ints.
    Multiply,
    /// Divides `src1` by `src2`, storing the result in `dst`. The functionality is dependent on the register tags.
    /// For floats, its division with fatal divide by zero checks.
    /// For ints, the behaviour is rounding TOWARDS zero. This is equivalent to `src1 / src2` in C, C++, and Rust.
    /// Divide by zero is a fatal error, and overflow is a warning.
    /// https://doc.rust-lang.org/reference/expressions/operator-expr.html#arithmetic-and-logical-binary-operators
    /// https://news.ycombinator.com/item?id=29729890
    /// https://core.ac.uk/download/pdf/187613369.pdf
    Divide,
    /// Divides integers `src2` from `src1`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// The behaviour is rounding down to the nearest integer. This is equivalent to `src1 / src2` in Python. Maybe operator should be `/_`.
    /// https://python-history.blogspot.com/2010/08/why-pythons-integer-division-floors.html
    DivideFloor,

    // ! == Int Instructions (Some Bool compatible) ==

    // /// WORKS WITH BOOLS. Int/Bool equality comparison between `src1` and `src2`. Stores the result in `dst`.
    // /// # Asserts
    // /// Registers may not overlap
    // IntIsEqual,
    // /// WORKS WITH BOOLS. Int/Bool inequality comparison between `sr1` and `src2`. Stores the result on `dst`.
    // /// # Asserts
    // /// Registers may not overlap
    // IntIsNotEqual,
    // /// WORKS WITH BOOLS. Int/Bool less than comparison. Stores a bool result in `dst` register being the condition `src1` is less than `src2`.
    // /// # Asserts
    // /// Registers may not overlap
    // IntIsLessThan,
    // /// WORKS WITH BOOLS. Int/Bool greater than comparison. Stores a bool result in `dst` register being the condition `src1` is greater than `src2`.
    // /// # Asserts
    // /// Registers may not overlap
    // IntIsGreaterThan,
    // /// WORKS WITH BOOLS. Int/Bool less than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is less than or equal to `src2`.
    // /// # Asserts
    // /// Registers may not overlap
    // IntIsLessOrEqual,
    // /// WORKS WITH BOOLS. Int/Bool greater than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is greater than or equal to `src2`.
    // /// # Asserts
    // /// Registers may not overlap
    // IntIsGreaterOrEqual,
    // /// Add integers `src1` and `src2`, storing the result in `dst`.
    // IntAdd,
    // /// Subtracts integers `src2` from `src1`, storing the result in `dst`.
    // IntSubtract,
    // /// Multiplies integers `src1` and `src2`, storing the result in `dst`.
    // IntMultiply,
    // /// Divides integers `src2` from `src1`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    // /// The behaviour is rounding TOWARDS zero. This is equivalent to `src1 / src2` in C, C++, and Rust.
    // /// https://doc.rust-lang.org/reference/expressions/operator-expr.html#arithmetic-and-logical-binary-operators
    // /// https://news.ycombinator.com/item?id=29729890
    // /// https://core.ac.uk/download/pdf/187613369.pdf
    // IntDivideTrunc,
    // /// Divides integers `src2` from `src1`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    // /// The behaviour is rounding down to the nearest integer. This is equivalent to `src1 / src2` in Python. Maybe operator should be `/_`.
    // /// https://python-history.blogspot.com/2010/08/why-pythons-integer-division-floors.html
    // IntDivideFloor,
    /// Modulus operator of `src1` and `src2`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// This is equivalent to `src1 % src2` in python, where the sign of `dst` is the sign of `src2`. Maybe operator should be `%_`.
    /// https://core.ac.uk/download/pdf/187613369.pdf
    IntModulo,
    /// Remainder operator of `src1` and `src2`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// This is equivalent to `src1 % src2` in C, C++, and Rust.
    IntRemainder,
    /// Exponent. Raises `src1` to the power of `src2`, storing the result in `dst`. If `src1 == 0` and `src2 < 0`, a fatal error occurs.
    IntPower,
    /// Inverts the bits of integer `src`, storing the result in `dst`.
    BitwiseComplement,
    /// Bitwise AND between integers `src1 & src2`, storing the result in `dst`.
    BitwiseAnd,
    /// Bitwise OR between integers `src1 | src2`, storing the result in `dst`.
    BitwiseOr,
    /// Bitwise XOR between integers `src1 ^ src2`, storing the result in `dst`.
    BitwiseXor,
    /// Bit left-shift of `src1 << src2`, storing the result in `dst`.
    BitShiftLeft,
    /// Bit right-shift of `src1 >> src2`, storing the result in `dst`, but ALWAYS filling the upper bits with zeroes.
    BitLogicalShiftRight,

    // ! == Bool Instructions ==

    /// If `src == true`, stores `false` in `dst`. If `src == false`, stores `true` in `dst`.
    BoolNot,

    // ! == Float Instructions ==

    // /// Float equality comparison between `src1` and `src2`. Stores the result in `dst`.
    // /// # Asserts
    // /// Registers may not overlap
    // FloatIsEqual,
    // /// Float inequality comparison between `src1` and `src2`. Stores the result in `dst`.
    // /// # Asserts
    // /// Registers may not overlap
    // FloatIsNotEqual,
    // /// Float less than comparison. Stores a bool result in `dst` register being the condition `src1` is less than `src2`.
    // /// # Asserts
    // /// Registers may not overlap
    // FloatIsLessThan,
    // /// Float greater than comparison. Stores a bool result in `dst` register being the condition `src1` is greater than `src2`.
    // /// # Asserts
    // /// Registers may not overlap
    // FloatIsGreaterThan,
    // /// Float less than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is less than or equal to `src2`.
    // /// # Asserts
    // /// Registers may not overlap
    // FloatIsLessOrEqual,
    // /// Float greater than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is greater than or equal to `src2`.
    // /// # Asserts
    // /// Registers may not overlap
    // FloatIsGreaterOrEqual,
    // /// Add `src1` with `src2` storing the result in `dst`.
    // FloatAdd,
    // /// Subtract `src1` by `src2` storing the result in `dst`.
    // FloatSubtract,
    // /// Multiply `src1` with `src2` storing the result in `dst`.
    // FloatMultiply,
    // /// Divide `src1` by `src2` storing the result in `dst`. If `src2 == 0`, this is considered a fatal error.
    // FloatDivide,
    /// Exponent. Raises `src1` to the power of `src2`, storing the result in `dst`. If `src1 == 0` and `src2 < 0`, a fatal error occurs.
    FloatPower,
    /// Stores the square root of `src` in `dst`. Technically this can be done with `.FloatPower`.
    FloatSquareRoot,
    /// Stores the logarithm of `src1` as the argument, and `src2` as the base into `dst`.
    FloatLog,
    // /// Stores the sine of `src` in `dst`. TODO determine degrees or radians or both?
    // FloatSin,
    // /// Stores the cosine of `src` in `dst`. TODO determine degrees or radians or both?
    // FloatCos,
    // /// Stores the tangent of `src` in `dst`. TODO determine degrees or radians or both?
    // FloatTan,
    // NOTE are arc and hyberbolic trig functions necessary?

    // ! == String Instructions ==
    // NOTE LoadZero can make a default, empty string

    /// Make a clone of the string at `src`, storing it in `dst`.
    StringClone,
    /// Store the length in bytes of the string at `src`, storing the value in `dst`.
    StringLen,
    /// Variable length instruction.
    StringFormat,
    /// Check if strings `src1` and `src2` are equal, storing the boolean result in `dst`.
    //StringIsEqual,
    /// Compare strings at `src1` and `src2`, storing the ordering as an integer at `dst`.
    /// The integer can be cast to the enum `Ordering` to determine comparison result.
    //StringCompare,
    StringFind,
    StringReverseFind,
    //StringAppend,
    StringSubstring,
    StringSplit,
    StringRemove,
};

pub const OperandsOnlyDst = packed struct { dst: u8 };
pub const OperandsDstTwoSrc = packed struct { dst: u8, src1: u8, src2: u8 };
pub const OperandsDstSrc = packed struct { dst: u8, src: u8 };
/// If `valueTag` is None, no value is returned.
pub const OperandsOptionalReturn = extern struct { valueTag: u8, src: u8 };
pub const OperandsSrcTag = extern struct { src: u8, tag: u8 };
pub const OperandsSync = extern struct {
    /// May not be 0
    count: u8,
    firstSync: SyncModifier,

    pub const SyncModifier = extern struct {
        src: u8,
        access: enum(u8) { Shared, Exclusive },
    };
};

pub const OperandsFunctionArgs = extern struct {
    argCount: u8,
    captureReturn: bool = false,
    returnDst: u8 = 0,
};

pub const OperandsZero = extern struct { dst: u8, tag: u8 };
pub const OperandsImmediate = packed struct {
    dst: u8,
    valueTag: enum(u2) { Bool, Int, Float },
    immediate: i14,
};
pub const OperandsImmediateLong = packed struct {
    dst: u8,
    tag: u8,
};

pub const FunctionArg = packed struct {
    /// Register to get the function argument from.
    src: u8,
    /// Is `root.valueTag`.
    valueTag: u5,
    modifier: FunctionArgModifiers,

    pub const FunctionArgModifiers = enum(u3) {
        Owned,
        ConstRef,
        MutRef,
    };
};

pub const OperandsCast = extern struct {
    dst: u8,
    src: u8,
    tag: u8,
};

/// The immediate data for a call operation.
pub const CallImmediate = extern struct {
    const PTR_BITMASK = 0x0000FFFFFFFFFFFF;
    const FUNCTION_TYPE_BITMASK = 0x00FF000000000000;
    const REGISTER_BITMASK = 0xFF00000000000000;

    inner: usize,

    pub fn initScriptFunctionPtr(scriptFptr: *const ScriptFunctionPtr) CallImmediate {
        return .{ .inner = @intFromPtr(scriptFptr) };
    }

    // TODO extern function pointer, and function pointer in register

    pub fn getScriptFunctionPtr(self: *const CallImmediate) *const ScriptFunctionPtr {
        assert(self.functionType() == .Script);
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    pub fn functionType(self: *const CallImmediate) FunctionType {
        return @enumFromInt(self.inner & FUNCTION_TYPE_BITMASK);
    }

    pub const FunctionType = enum(usize) {
        Script = 0,
    };
};

/// By default, initializes to be a function with no arguments, with an undefined function pointer.
pub const ScriptFunctionPtr = struct {
    bytecodeStart: [*]const Self = undefined,
    args: []const ArgInfo = &.{},

    pub const ArgInfo = struct {
        valueTag: root.ValueTag,
        modifier: FunctionArg.FunctionArgModifiers,
    };
};

fn IntegerFromBitWidth(comptime width: comptime_int) type {
    switch (width) {
        1 => return u1,
        2 => return u2,
        3 => return u3,
        4 => return u4,
        5 => return u5,
        6 => return u6,
        7 => return u7,
        8 => return u8,
        9 => return u9,
        10 => return u10,
        11 => return u11,
        12 => return u12,
        13 => return u13,
        14 => return u14,
        15 => return u15,
        16 => return u16,
        17 => return u17,
        18 => return u18,
        19 => return u19,
        20 => return u20,
        21 => return u21,
        22 => return u22,
        23 => return u23,
        24 => return u24,
        else => {
            @compileError("Incompatible bit width type for bytecode operands");
        },
    }
}

// TODO string instructions
fn validateOpCodeMatchesOperands(opcode: OpCode, comptime OperandsT: type) void {
    const opcodeName = @tagName(opcode);
    const allocator = std.heap.c_allocator;
    const fmtMessage = "OpCode {s} may not use the type " ++ @typeName(OperandsT) ++ ". Must use {s} instead.";
    const allocPrint = std.fmt.allocPrint;
    switch (opcode) {
        .Nop,
        .Unsync,
        => {
            if (OperandsT != void) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(void) }) catch unreachable;
                @panic(message);
            }
        },
        .Move,
        .BitwiseComplement,
        .BoolNot,
        => {
            if (OperandsT != OperandsDstSrc) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(OperandsDstSrc) }) catch unreachable;
                @panic(message);
            }
        },
        .LoadImmediate => {
            if (OperandsT != OperandsImmediate) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(OperandsImmediate) }) catch unreachable;
                @panic(message);
            }
        },
        .LoadImmediateLong => {
            if (OperandsT != OperandsImmediateLong) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(OperandsImmediateLong) }) catch unreachable;
                @panic(message);
            }
        },
        .Return => {
            if (OperandsT != OperandsOptionalReturn and OperandsT != void) {
                const message = allocPrint(
                    allocator,
                    "OpCode Return may not use the type " ++ @typeName(OperandsT) ++ ". Must use {s} or void instead.",
                    .{@typeName(OperandsOptionalReturn)},
                ) catch unreachable;
                @panic(message);
            }
        },
        .Call => {
            if (OperandsT != OperandsFunctionArgs) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(OperandsFunctionArgs) }) catch unreachable;
                @panic(message);
            }
        },
        .Deinit => {
            if (OperandsT != OperandsSrcTag) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(OperandsSrcTag) }) catch unreachable;
                @panic(message);
            }
        },
        .Sync => {
            if (OperandsT != OperandsSync) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(OperandsSync) }) catch unreachable;
                @panic(message);
            }
        },
        .Cast => {
            if (OperandsT != OperandsCast) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(OperandsCast) }) catch unreachable;
                @panic(message);
            }
        },
        // .IntIsEqual,
        // .IntIsNotEqual,
        // .IntIsLessThan,
        // .IntIsGreaterThan,
        // .IntIsLessOrEqual,
        // .IntIsGreaterOrEqual,
        // .IntAdd,
        // .IntSubtract,
        // .IntMultiply,
        // .IntDivideTrunc,
        // .IntDivideFloor,
        .IntModulo,
        .IntRemainder,
        .IntPower,
        .BitwiseAnd,
        .BitwiseOr,
        .BitwiseXor,
        .BitShiftLeft,
        .BitLogicalShiftRight,
        // .FloatIsEqual,
        // .FloatIsNotEqual,
        // .FloatIsLessThan,
        // .FloatIsGreaterThan,
        // .FloatIsLessOrEqual,
        // .FloatIsGreaterOrEqual,
        // .FloatAdd,
        // .FloatSubtract,
        // .FloatMultiply,
        // .FloatDivide,
        => {
            if (OperandsT != OperandsDstTwoSrc) {
                const message = allocPrint(allocator, fmtMessage, .{ opcodeName, @typeName(OperandsDstTwoSrc) }) catch unreachable;
                @panic(message);
            }
        },
        else => {},
    }
}

//pub fn executeOperation()
