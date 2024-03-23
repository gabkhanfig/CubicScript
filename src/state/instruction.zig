const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

/// The overwhelming majority of instructions are 4 bytes, but there are a few multibyte instructions.
/// Therefore simply iterating through is not valid.
pub const Bytecode = extern struct {
    const Self = @This();

    value: u32,

    pub fn encodeABC(opcode: OpCode, a: u8, b: u8, c: u8) Self {
        const opcodeNum = @as(u32, @intFromEnum(opcode));
        const aShifted = @shlExact(@as(u32, @intCast(a)), 8);
        const bShifted = @shlExact(@as(u32, @intCast(b)), 16);
        const cShifted = @shlExact(@as(u32, @intCast(c)), 24);
        return Self{ .value = opcodeNum | aShifted | bShifted | cShifted };
    }

    pub fn encodeAB(opcode: OpCode, a: u8, b: u8) Self {
        const opcodeNum = @as(u32, @intFromEnum(opcode));
        const aShifted = @shlExact(@as(u32, @intCast(a)), 8);
        const bShifted = @shlExact(@as(u32, @intCast(b)), 16);
        return Self{ .value = opcodeNum | aShifted | bShifted };
    }

    pub fn encodeA(opcode: OpCode, a: u8) Self {
        const opcodeNum = @as(u32, @intFromEnum(opcode));
        const aShifted = @shlExact(@as(u32, @intCast(a)), 8);
        return Self{ .value = opcodeNum | aShifted };
    }

    pub fn decodeABC(self: Self) OperandsABC {
        const a: u8 = @intCast(@shrExact(self.value & 0xFF00, 8));
        const b: u8 = @intCast(@shrExact(self.value & 0xFF0000, 16));
        const c: u8 = @intCast(@shrExact(self.value & 0xFF000000, 24));
        return .{ .a = a, .b = b, .c = c };
    }

    pub fn decodeAB(self: Self) OperandsAB {
        const a: u8 = @intCast(@shrExact(self.value & 0xFF00, 8));
        const b: u8 = @intCast(@shrExact(self.value & 0xFF0000, 16));
        return .{ .a = a, .b = b };
    }

    pub fn decodeA(self: Self) u8 {
        const a: u8 = @intCast(@shrExact(self.value & 0xFF00, 8));
        return a;
    }

    /// For multiple byte-code wide instructions, getting the opcode is undefined behaviour.
    pub fn getOpCode(self: Self) OpCode {
        return @enumFromInt(self.value & 0xFF);
    }

    const OperandsABC = struct {
        a: u8,
        b: u8,
        c: u8,
    };

    const OperandsAB = struct {
        a: u8,
        b: u8,
    };
};

// https://the-ravi-programming-language.readthedocs.io/en/latest/lua_bytecode_reference.html

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
    ///// Copy value `src` to `dst`, and set `src` to 0.
    //Take,
    /// Copy the value at the address held at src into dst
    Load, // TODO is this actually necessary. Maybe it would be better to use class indexing?
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
    /// Return from the calling function, moving the instruction pointer back to the calling function,
    /// or terminating the script if it was called by an owning process.
    Return,
    /// Call a function at `src`, moving the stack pointer, and setting the return address.
    Call,
    /// Call a function from the host process at `src`, moving the stack pointer and setting the return address.
    CallExtern,

    // == Int Instructions (Some Bool compatible) ==

    /// WORKS WITH BOOLS. Int/Bool equality comparison between `src1` and `src2`. Stores the result in `dst`.
    IntIsEqual,
    /// WORKS WITH BOOLS. Int/Bool inequality comparison between `sr1` and `src2`. Stores the result on `dst`.
    IntIsNotEqual,
    /// WORKS WITH BOOLS. Int/Bool less than comparison. Stores a bool result in `dst` register being the condition `src1` is less than `src2`.
    IntIsLessThan,
    /// WORKS WITH BOOLS. Int/Bool greater than comparison. Stores a bool result in `dst` register being the condition `src1` is greater than `src2`.
    IntIsGreaterThan,
    /// WORKS WITH BOOLS. Int/Bool less than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is less than or equal to `src2`.
    IntIsLessOrEqual,
    /// WORKS WITH BOOLS. Int/Bool greater than or equal to comparison. Stores a bool result in `dst` register being the condition `src1` is greater than or equal to `src2`.
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
