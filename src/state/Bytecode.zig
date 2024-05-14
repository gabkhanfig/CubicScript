const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;

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

pub fn encodeDataAsBytecode(comptime T: type, data: T) Self {
    if (@sizeOf(T) > @sizeOf(Self)) {
        @compileError("Invalid encoding type. Must be 4 bytes or smaller");
    }
    const bytecodeValue: IntegerFromBitWidth(@bitSizeOf(T)) = @bitCast(data);
    return Self{ .value = @intCast(bytecodeValue) };
}

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
    /// No operation. Allows 0 set memory to be a technically valid program.
    Nop = 0,
    /// Move value between registers `src` and `dst`. The tag at `src` is set to `.None`.
    Move = 1,
    /// Explicitly clone the value at `src`, storing the clone in `dst`.
    Clone = 2,
    /// Set the register `dst` to zero. Uses `OperandsZero`
    LoadZero = 3,
    /// Performs special initialization for types that cannot just be zero intiailized, such as arrays, sets, and maps.
    LoadDefault = 4,
    /// Load an immediate bool/int/float into `dst`.
    /// The immediate value will be cast to the correct value.
    LoadImmediate = 5,
    /// Load the 64 bit immediate into `dst`. This is a 12 byte instruction.
    /// Expects the bits to be a valid `RawValue`, in which the held value is cloned.
    /// Uses `OperandsImmediateLong`.
    LoadImmediateLong = 6,
    /// Unconditionally jump to `dst`
    Jump,
    /// Jump to `dst` if `src` is 0.
    JumpIfZero,
    /// Jump to `dst` if `src` is NOT 0.
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
    /// If `src == true`, stores `false` in `dst`. If `src == false`, stores `true` in `dst`.
    BoolNot,
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
    /// Integer modulus operator of `src1` and `src2`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// This is equivalent to `src1 % src2` in python, where the sign of `dst` is the sign of `src2`. Maybe operator should be `%_`.
    /// https://core.ac.uk/download/pdf/187613369.pdf
    Modulo,
    /// Integer remainder operator of `src1` and `src2`, storing the result in `dst`. `src2` may not be 0. If it is, an error will have to be handled.
    /// This is equivalent to `src1 % src2` in C, C++, and Rust.
    Remainder,
    /// Exponent. Raises `src1` to the power of `src2`, storing the result in `dst`. If `src1 == 0` and `src2 < 0`, a fatal error occurs.
    /// Works with integers and floats, depending on the register tag.
    Power,
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
    /// Math operations that have one input and one output.
    /// Does an `op` on `src`, storing the result in `dst`. Uses `OperandsMathExt`
    FloatMathExt,
    /// Stores the logarithm of `src1` as the argument, and `src2` as the base into `dst`.
    /// Bases of e, 2, and 10 are handled in `OpCode.MathExt`.
    FloatLogWithBase,
    /// Get the length or size of a value at `src`, storing it in `dst`.
    /// The type depends on the register tag. Works with strings, arrays, sets, and maps.
    /// Uses `OperandsDstSrc`.
    Len,
    /// 8 byte (2 bytecode) instruction.
    /// The bytecode after is an `OperandsSubstring`
    Substring,
    /// Pushes data into a structure.
    /// For arrays, pushes an element to the end of the array.
    /// For sets, pushes an element into the set.
    /// For maps, pushes a key and value into the map.
    /// Uses `OperandsPush`.
    Push,

    //StringFind, TODO find and reverse find can be generic for strings, arrays, sets, and maps, returning the appropriate optional type
    //StringReverseFind,

    // Variable length instruction.
    //StringFormat,
    //StringSplit,
    //StringRemove,
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

pub const OperandsDefault = packed struct {
    dst: u8,
    /// Is the actual tag of the type, such as `.Int` or `.Array`
    tag: u5,
    /// If `tag` is:
    /// - `.Array` -> this is the type that the array holds.
    /// - `.Set` or `.Map` -> the key type
    keyTag: u5,
    /// Used only for if tag is `.Map`, specifying the value type.
    valueTag: u5 = 0,
};

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

pub const OperandsMathExt = packed struct {
    src: u8,
    dst: u8,
    op: enum(u8) {
        Floor,
        Ceil,
        Round,
        Trunc,
        Sqrt,
        LogE,
        Log2,
        Log10,
        /// Uses radians
        Sin,
        /// Uses radians
        Cos,
        /// Uses radians. Due to PI being impossible to accurately represent in floating point form, the result will never be undefined.
        Tan,
        /// Uses radians. If the value at `src` is greater than 1, or less than -1, a fatal error occurs.
        Arcsin,
        /// Uses radians. If the value at `src` is greater than 1, or less than -1, a fatal error occurs.
        Arccos,
        /// Uses radians
        Arctan,
        HyperbolicSin,
        HyperbolicCos,
        HyperbolicTan,
        HyperbolicArcsin,
        HyperbolicArccos,
        HyperbolicArctan,
        // TODO maybe other trig functions like csc?
    },
};

pub const OperandsSubstring = extern struct { dst: u8, strSrc: u8, startSrc: u8, endSrc: u8 };

pub const OperandsPush = extern struct { pushSrc: u8, keySrc: u8, valSrcOptional: u8 = 0 };

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
        25 => return u25,
        26 => return u26,
        27 => return u27,
        28 => return u28,
        29 => return u29,
        30 => return u30,
        31 => return u31,
        32 => return u32,
        else => {
            @compileError("Unsupported bit width");
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
        .Modulo,
        .Remainder,
        .Power,
        .BitwiseAnd,
        .BitwiseOr,
        .BitwiseXor,
        .BitShiftLeft,
        .BitLogicalShiftRight,
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
