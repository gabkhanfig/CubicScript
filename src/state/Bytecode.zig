const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;

const Self = @This();

value: u32,

pub fn encode(opcode: OpCode, comptime OperandsT: type, operands: OperandsT) Self {
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

    const immediateBits: usize = @bitCast(immediate);
    return Self{ .value = @intCast(immediateBits & LOW_MASK) };
}

pub fn encodeImmediateUpper(comptime T: type, immediate: T) Self {
    if (T == bool) {
        const immediateBits: usize = @intFromBool(immediate);
        return Self{ .value = @intCast(@shrExact(immediateBits & HIGH_MASK, 32)) };
    } else if (@sizeOf(T) != 8) {
        @compileError("Invalid immediate type. Must be 8 bytes in size or boolean");
    }

    const immediateBits: usize = @bitCast(immediate);
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
    /// Copy value between registers src and dst.
    Move,
    /// Set the register `dst` to zero.
    /// # Asserts
    /// Registers may not overlap.
    LoadZero,
    /// Load the 64 bit immediate into `dst`. This is a 12 byte instruction.
    LoadImmediate,
    /// Unconditionally jump to `dst`
    Jump,
    /// Jump to `dst` if `src` is 0
    JumpIfZero,
    /// Jump to `dst` if `src` is NOT 0
    JumpIfNotZero,
    /// Return from the calling function, moving the instruction pointer back to the calling function,
    /// or terminating the script if it was called by an owning process.
    /// Uses `OperandsOptionalReturn` operands, but `void` can be passed in while encoding
    /// if no value is returned. If the return value exists, copies `src` to a temporary location,
    /// returns to the previous stack frame, and sets `dst` to the return value.
    Return,
    /// Call a function at `src`, moving the stack pointer, and setting the return address.
    Call,
    /// Call a function from the host process at `src`, moving the stack pointer and setting the return address.
    /// Maybe all extern functions take a reference to a slice of the available stack frame arguments.
    /// For C, this would be a pointer to the beginning of the available stack frame for arg1, and a length of the length of the slice for arg2.
    /// The `extern` function would then return a `TaggedValue`, in which `void` uses the `None` tag.
    /// The runtime could assert that the correct type is returned. NOTE maybe should return only a raw value, and when "linking"
    /// the function, the return tag can be specified?
    CallExtern,

    // ! == Int Instructions (Some Bool compatible) ==

    /// WORKS WITH BOOLS. Int/Bool equality comparison between `src1` and `src2`. Stores the result in `dst`.
    /// # Asserts
    /// Registers may not overlap
    IntIsEqual,
    /// WORKS WITH BOOLS. Int/Bool inequality comparison between `sr1` and `src2`. Stores the result on `dst`.
    /// # Asserts
    /// Registers may not overlap
    IntIsNotEqual,
    /// WORKS WITH BOOLS. Int/Bool less than comparison. Stores a bool result in `dst` register being the condition `src1` is less than `src2`.
    /// # Asserts
    /// Registers may not overlap
    IntIsLessThan,
    /// WORKS WITH BOOLS. Int/Bool greater than comparison. Stores a bool result in `dst` register being the condition `src1` is greater than `src2`.
    /// # Asserts
    /// Registers may not overlap
    IntIsGreaterThan,
    /// WORKS WITH BOOLS. Int/Bool less than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is less than or equal to `src2`.
    /// # Asserts
    /// Registers may not overlap
    IntIsLessOrEqual,
    /// WORKS WITH BOOLS. Int/Bool greater than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is greater than or equal to `src2`.
    /// # Asserts
    /// Registers may not overlap
    IntIsGreaterOrEqual,
    /// Add integers `src1` and `src2`, storing the result in `dst`.
    IntAdd,
    /// Subtracts integers `src2` from `src1`, storing the result in `dst`.
    IntSubtract,
    /// Multiplies integers `src1` and `src2`, storing the result in `dst`.
    IntMultiply,
    /// Divides integers `src2` from `src1`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// The behaviour is rounding TOWARDS zero. This is equivalent to `src1 / src2` in C, C++, and Rust.
    /// https://doc.rust-lang.org/reference/expressions/operator-expr.html#arithmetic-and-logical-binary-operators
    /// https://news.ycombinator.com/item?id=29729890
    /// https://core.ac.uk/download/pdf/187613369.pdf
    IntDivideTrunc,
    /// Divides integers `src2` from `src1`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// The behaviour is rounding down to the nearest integer. This is equivalent to `src1 / src2` in Python. Maybe operator should be `/_`.
    /// https://python-history.blogspot.com/2010/08/why-pythons-integer-division-floors.html
    IntDivideFloor,
    /// Modulus operator of `src1` and `src2`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// This is equivalent to `src1 % src2` in python, where the sign of `dst` is the sign of `src2`. Maybe operator should be `%_`.
    /// https://core.ac.uk/download/pdf/187613369.pdf
    IntModulo,
    /// Remainder operator of `src1` and `src2`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// This is equivalent to `src1 % src2` in C, C++, and Rust.
    IntRemainder,
    /// Exponent. Raises `src1` to the power of `src2`, storing the result in `dst`. If `src1 == 0` and `src2 < 0`, a fatal error occurs.
    /// NOTE should this be part of a math library?
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
    /// Bit right-shift of `src1 >> src2`, storing the result in `dst`.
    /// The vacant bits will be filled by the sign bit.
    /// https://learn.microsoft.com/en-us/cpp/cpp/left-shift-and-right-shift-operators-input-and-output?view=msvc-170#right-shifts
    BitArithmeticShiftRight,
    /// Bit right-shift of `src1 >> src2`, storing the result in `dst`, but ALWAYS filling the upper bits with zeroes.
    BitLogicalShiftRight,
    /// Convert an integer `src` to a bool, storing the result in `dst`.
    /// If `src` is non-zero, `true` is stored. If `src` is zero, `false` is stored.
    IntToBool,
    /// Convert an integer `src` to a float, storing the result in `dst`.
    IntToFloat,
    /// Convert an integer `src` to a new string, storing the result in `dst`.
    IntToString,

    // ! == Bool Instructions ==
    // NOTE converting a bool to int can just use the same register.

    /// If `src == true`, stores `false` in `dst`. If `src == false`, stores `true` in `dst`.
    BoolNot,
    /// Convert bool `src` into a new string, storing the result in `dst`.
    BoolToString,

    // ! == Float Instructions ==

    /// Float equality comparison between `src1` and `src2`. Stores the result in `dst`.
    /// # Asserts
    /// Registers may not overlap
    FloatIsEqual,
    /// Float inequality comparison between `src1` and `src2`. Stores the result in `dst`.
    /// # Asserts
    /// Registers may not overlap
    FloatIsNotEqual,
    /// Float less than comparison. Stores a bool result in `dst` register being the condition `src1` is less than `src2`.
    /// # Asserts
    /// Registers may not overlap
    FloatIsLessThan,
    /// Float greater than comparison. Stores a bool result in `dst` register being the condition `src1` is greater than `src2`.
    /// # Asserts
    /// Registers may not overlap
    FloatIsGreaterThan,
    /// Float less than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is less than or equal to `src2`.
    /// # Asserts
    /// Registers may not overlap
    FloatIsLessOrEqual,
    /// Float greater than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is greater than or equal to `src2`.
    /// # Asserts
    /// Registers may not overlap
    FloatIsGreaterOrEqual,
    /// Add `src1` with `src2` storing the result in `dst`.
    FloatAdd,
    /// Subtract `src1` by `src2` storing the result in `dst`.
    FloatSubtract,
    /// Multiply `src1` with `src2` storing the result in `dst`.
    FloatMultiply,
    /// Divide `src1` by `src2` storing the result in `dst`. If `src2 == 0`, this is considered a fatal error.
    FloatDivide,
    /// Convert `src` float to an int, storing it in `dst`.
    /// If `src` is out of the range of an integer, the value will be clamped to the max/min int values.
    FloatToInt,
    /// Convert `src` float to a new string, storing it in `dst`.
    FloatToString,

    // 48 instructions SO FAR up to this point

    // ! == String Instructions ==
    // NOTE LoadZero can make a default, empty string

    /// Deinitialize the string at `src`.
    StringDeinit,
    /// Make a clone of the string at `src`, storing it in `dst`.
    StringClone,
    /// Store the length in bytes of the string at `src`, storing the value in `dst`.
    StringLen,
    /// Variable length instruction.
    StringFormat,
    /// Check if strings `src1` and `src2` are equal, storing the boolean result in `dst`.
    StringIsEqual,
    /// Compare strings at `src1` and `src2`, storing the ordering as an integer at `dst`.
    /// The integer can be cast to the enum `Ordering` to determine comparison result.
    StringCompare,
    StringFind,
    StringReverseFind,
    StringAppend,
    StringSubstring,
    StringSplit,
    StringRemove,
    StringToInt,
    StringToFloat,
    StringToBool,

    // NOTE should these math functions be part of a math library?
    // FloatPower,
    // FloatSquareRoot,
    // FloatSin,
    // FloatCos,
    // FloatTan,
    // // NOTE are arc and hyberbolic trig functions necessary?
    // FloatLog,
};

/// `dst` is a u9 because it allows moving values to registers within the
/// next stack frame for function calls.
pub const OperandsMove = packed struct { dst: u9, src: u8 };
pub const OperandsOnlyDst = packed struct { dst: u8 };
pub const OperandsDstTwoSrc = packed struct { dst: u8, src1: u8, src2: u8 };
pub const OperandsDstSrc = packed struct { dst: u8, src: u8 };
pub const OperandsOptionalReturn = extern struct { hasValue: bool, src: u8 };

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
