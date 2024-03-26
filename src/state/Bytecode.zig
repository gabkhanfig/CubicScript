const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

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
    Nop,
    /// End of script, return control to calling program
    Exit,
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
    Return,
    /// Call a function at `src`, moving the stack pointer, and setting the return address.
    Call,
    /// Call a function from the host process at `src`, moving the stack pointer and setting the return address.
    CallExtern,

    // == Int Instructions (Some Bool compatible) ==

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
    IntDivide,
    /// Exponent. Raises `src1` to the power of `src2`, storing the result in `dst`.
    IntPower,
    /// Modulus (remainder) operator of `src1 % src2`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    IntMod,
    /// Inverts the bits of integer `src`, storing the result in `dst`.
    IntNot,
    /// Bitwise AND between integers `src1 & src2`, storing the result in `dst`.
    And,
    /// Bitwise OR between integers `src1 | src2`, storing the result in `dst`.
    Or,
    /// Bitwise XOR between integers `src1 ^ src2`, storing the result in `dst`.
    Xor,
    /// Bit left-shift of `src1 << src2`, storing the result in `dst`. `src2` may not be negative,
    /// and may not be greater than 63. If either error conditions are met, an error will have to be handled
    BitShiftLeft,
    /// Bit left-shift of `src1 >> src2`, storing the result in `dst`. `src2` may not be negative,
    /// and may not be greater than 63. If either error conditions are met, an error will have to be handled
    BitShiftRight,
    /// Convert an integer `src` to a bool, storing the result in `dst`.
    /// If `src` is non-zero, `true` is stored. If `src` is zero, `false` is stored.
    IntToBool,
    /// Convert an integer `src` to a float, storing the result in `dst`.
    IntToFloat,
    /// Convert an integer `src` to a new string, storing the result in `dst`.
    IntToString,

    // == Bool Instructions ==
    // NOTE converting a bool to int can just use the same register.

    /// If `src == true`, stores `false` in `dst`. If `src == false`, stores `true` in `dst`.
    BoolNot,
    /// Convert bool `src` into a new string, storing the result in `dst`.
    BoolToString,
};

/// `dst` is a u9 because it allows moving values to registers within the
/// next stack frame for function calls.
pub const OperandsMove = packed struct { dst: u9, src: u8 };
pub const OperandsOnlyDst = packed struct { dst: u8 };
pub const OperandsDstTwoSrc = packed struct { dst: u8, src1: u8, src2: u8 };

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
        25 => return u25,
        26 => return u26,
        else => {
            @compileError("Incompatible bit width type for bytecode operands");
        },
    }
}
