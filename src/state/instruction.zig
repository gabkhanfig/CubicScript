const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

/// The overwhelming majority of instructions are 4 bytes, but there are a few multibyte instructions.
/// Therefore simply iterating through is not valid.
pub const Bytecode = extern struct {
    const Self = @This();

    value: u32,

    pub fn opcode(self: Self) OpCode {
        return @enumFromInt(self & 0xFF);
    }
};

// https://the-ravi-programming-language.readthedocs.io/en/latest/lua_bytecode_reference.html

/// Instructions are variable width, but generally 4 bytes in size.
/// All 4 byte bytecodes are in one of 3 patterns, where Op is the 1 byte instruction
/// > Op A B C A = 1 byte operand, B = 1 byte operand, C = 1 byte operand
/// >
/// > Op A B A   = 1 byte operand, B = 2 byte operand
/// >
/// > Op A       = 3 byte operand
pub const OpCode = enum(u8) {
    // == GENERAL INSTRUCTIONS ==

    /// No operation. Allows 0 set memory to be a technically valid program.
    Nop,
    /// End of script, return control to calling program
    Exit,
    /// Copy value between registers
    Move,
    /// Copy the value at the address held at src into dst
    Load,
    /// Copy the value at the address held at `src + offset` into `dst`. `offset` is a sign extended immediate.
    LoadOffset,
    /// Set the register `dst` to zero
    LoadZero,
    /// Load the 64 bit immediate into `dst`. This is a 12 byte instruction.
    LoadImmediate,
    /// Copy value at `src` into the address held at `dst`
    Store,
    /// Copy value at `src + offset` into the address held at `dst`. `offset` is a sign extended immediate.
    StoreOffset,
    /// Unconditionally jump to `dst`
    Jump,
    /// Jump to `dst` if `src` is 0
    JumpIfZero,
    /// Jump to `dst` if `src` is NOT 0
    JumpIfNotZero,

    // == Int Instructions (Some Bool compatible) ==

    /// WORKS WITH BOOLS. Int/Bool equality comparison between `src1` and `src2`. Stores the result in `dst`.
    IntIsEqual,
    /// WORKS WITH BOOLS. Int/Bool inequality comparison between `sr1` and `src2`. Stores the result on `dst`.
    IntIsNotEqual,
    /// WORKS WITH BOOOS. Int/Bool less than comparison. Stores a bool result in `dst` register being the condition `src1` is less than `src2`.
    IntIsLessThan,
    /// WORKS WITH BOOOS. Int/Bool greater than comparison. Stores a bool result in `dst` register being the condition `src1` is greater than `src2`.
    IntIsGreaterThan,
    /// WORKS WITH BOOOS. Int/Bool less than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is less than or equal to `src2`.
    IntIsLessOrEqual,
    /// WORKS WITH BOOOS. Int/Bool greater than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is greater than or equal to `src2`.
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
    IntAnd,
    /// Bitwise OR between integers `src1 | src2`, storing the result in `dst`.
    IntOr,
    /// Bitwise XOR between integers `src1 ^ src2`, storing the result in `dst`.
    IntXor,
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
