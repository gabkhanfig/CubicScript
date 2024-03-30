const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const Stack = @import("Stack.zig");
const Bytecode = @import("Bytecode.zig");
const OpCode = Bytecode.OpCode;
const String = root.String;
const math = @import("../types/math.zig");
const Error = @import("Errors.zig");
const allocPrintZ = std.fmt.allocPrintZ;
const runtime_safety: bool = std.debug.runtime_safety;
const Mutex = std.Thread.Mutex;

pub const RuntimeError = Error.RuntimeError;
pub const ErrorSeverity = Error.Severity;
// https://github.com/ziglang/zig/issues/16419
pub const RuntimeErrorCallback = *const fn (err: RuntimeError, severity: ErrorSeverity, message: []const u8) void;
pub const CRuntimeErrorCallback = *const fn (err: c_int, severity: c_int, message: ?[*c]const u8, messageLength: usize) void;

const Self = @This();

allocator: Allocator,
_context: ScriptContext,
_contextMutex: Mutex = .{},

/// Create a new state with an allocator and an optional error callback.
/// If a `null` error callback is provided, the default one will be used, which
/// with `std.debug.runtime_safety`, will log all messages. Without runtime safety,
/// no messages will be logged.
pub fn init(allocator: Allocator, context: ?ScriptContext) Allocator.Error!*Self {
    const self = try allocator.create(Self);
    self.* = Self{
        .allocator = allocator,
        ._context = if (context) |ctx| ctx else default_context,
    };
    return self;
}

// /// With runtime safety on, will catch double frees.
// /// When off, just uses the C allocator.
// /// Returns null if allocation failed.
// pub fn initExternC(context: ?ScriptContext) ?*Self {
//     const allocator = blk: {
//         if (std.debug.runtime_safety) {
//             var gpa = std.heap.GeneralPurposeAllocator(.{});
//             break :blk gpa.allocator();
//         } else {
//             break :blk std.heap.c_allocator;
//         }
//     };

//     const self = Self.init(allocator, context) catch return null;
//     return self;
// }

pub fn deinit(self: *Self) void {
    self._context.deinit();

    self.allocator.destroy(self);
    return;
}

fn runtimeError(self: *const Self, err: RuntimeError, severity: ErrorSeverity, message: []const u8) void {
    // Only the mutex and the data it owns are modified here, so removing the const is fine.
    const contextMutex: *Mutex = @constCast(&self._contextMutex);
    contextMutex.lock();
    defer contextMutex.unlock();

    const context: *ScriptContext = @constCast(&self._context);
    context.runtimeError(self, err, severity, message);
}

pub fn run(self: *const Self, stack: *Stack, instructions: []const Bytecode) Allocator.Error!void {
    var instructionPointer: usize = 0;
    // The stack pointer points to the beginning of the stack frame.
    // This is done to use positive offsets to avoid any obscure exploits or issues from using
    // negative offsets and inadverently mutating the stack frame of the calling script function.
    const stackPointer: usize = 0; // NOTE will be var instead of const when functions come into play
    const currentStackFrameSize: usize = 256;

    while (instructionPointer < instructions.len) {
        const bytecode = instructions[instructionPointer];
        switch (bytecode.getOpCode()) {
            .Nop => {
                //std.debug.print("no operation\n", .{});
            },
            .Move => {
                const operands = bytecode.decode(Bytecode.OperandsMove);
                const dstRegisterPos = stackPointer + @as(usize, operands.dst);
                const srcRegisterPos = stackPointer + @as(usize, operands.src);

                assert(@as(usize, operands.src) < currentStackFrameSize); // Dont bother checking the dst, because that can extend past the stack frame.
                assert(dstRegisterPos != srcRegisterPos); // Cannot be the same location

                //std.debug.print("Move: copying value at src[{}] to dst[{}]\n", .{ operands.src, operands.dst });
                stack.stack[dstRegisterPos] = stack.stack[srcRegisterPos];
            },
            .LoadZero => {
                const operand = bytecode.decode(Bytecode.OperandsOnlyDst);
                const dstRegisterPos = stackPointer + @as(usize, operand.dst);

                // Dont bother checking the dst, because that can extend past the stack frame.
                assert(@as(usize, operand.dst) < currentStackFrameSize);

                //std.debug.print("LoadZero: setting dst[{}] to 0\n", .{operand.dst});
                stack.stack[dstRegisterPos] = std.mem.zeroes(RawValue);
            },
            .LoadImmediate => {
                // NOTE the two bytecodes after `LoadImmediate` are the 64 bit immediate values, thus the instruction
                // pointer will need to be further incremented.
                const operand = bytecode.decode(Bytecode.OperandsOnlyDst);

                assert(@as(usize, operand.dst) < currentStackFrameSize); // Dont bother checking the dst, because that can extend past the stack frame.

                const dstRegisterPos = stackPointer + @as(usize, @intCast(operand.dst));
                const immediate: usize =
                    @as(usize, @intCast(instructions[instructionPointer + 1].value)) |
                    @shlExact(@as(usize, @intCast(instructions[instructionPointer + 2].value)), 32);
                //std.debug.print("LoadImmediate: copying immediate value [decimal: {}, hex: 0x{x}] to dst[{}]\n", .{ immediate, immediate, operand.dst });
                stack.stack[dstRegisterPos].actualValue = immediate;
                instructionPointer += 2;
            },
            .IntIsEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                assert(registers.dst != registers.src1);
                assert(registers.dst != registers.src2);
                assert(registers.src1 != registers.src2);

                stack.stack[registers.dst].boolean = stack.stack[registers.src1].int == stack.stack[registers.src2].int;
            },
            .IntIsNotEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                assert(registers.dst != registers.src1);
                assert(registers.dst != registers.src2);
                assert(registers.src1 != registers.src2);

                stack.stack[registers.dst].boolean = stack.stack[registers.src1].int != stack.stack[registers.src2].int;
            },
            .IntIsLessThan => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                assert(registers.dst != registers.src1);
                assert(registers.dst != registers.src2);
                assert(registers.src1 != registers.src2);

                stack.stack[registers.dst].boolean = stack.stack[registers.src1].int < stack.stack[registers.src2].int;
            },
            .IntIsGreaterThan => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                assert(registers.dst != registers.src1);
                assert(registers.dst != registers.src2);
                assert(registers.src1 != registers.src2);

                stack.stack[registers.dst].boolean = stack.stack[registers.src1].int > stack.stack[registers.src2].int;
            },
            .IntIsLessOrEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                assert(registers.dst != registers.src1);
                assert(registers.dst != registers.src2);
                assert(registers.src1 != registers.src2);

                stack.stack[registers.dst].boolean = stack.stack[registers.src1].int <= stack.stack[registers.src2].int;
            },
            .IntIsGreaterOrEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                assert(registers.dst != registers.src1);
                assert(registers.dst != registers.src2);
                assert(registers.src1 != registers.src2);

                stack.stack[registers.dst].boolean = stack.stack[registers.src1].int >= stack.stack[registers.src2].int;
            },
            .IntAdd => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                const lhs = stack.stack[registers.src1].int;
                const rhs = stack.stack[registers.src2].int;

                const temp = math.addOverflow(lhs, rhs);
                if (temp.@"1") {
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] + rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.AdditionIntegerOverflow, ErrorSeverity.Warning, message);
                }
                stack.stack[registers.dst].int = temp.@"0";
            },
            .IntSubtract => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                const lhs = stack.stack[registers.src1].int;
                const rhs = stack.stack[registers.src2].int;

                const temp = math.subOverflow(lhs, rhs);
                if (temp.@"1") {
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] - rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.SubtractionIntegerOverflow, ErrorSeverity.Warning, message);
                }
                stack.stack[registers.dst].int = temp.@"0";
            },
            .IntMultiply => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                const lhs = stack.stack[registers.src1].int;
                const rhs = stack.stack[registers.src2].int;

                const temp = math.mulOverflow(lhs, rhs);
                if (temp.@"1") {
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] * rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.MultiplicationIntegerOverflow, ErrorSeverity.Warning, message);
                }
                stack.stack[registers.dst].int = temp.@"0";
            },
            .IntDivideTrunc => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                const lhs = stack.stack[registers.src1].int;
                const rhs = stack.stack[registers.src2].int;
                if (rhs == 0) {
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] / rhs[{}] doing truncation division", .{ lhs, rhs });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.DivideByZero, ErrorSeverity.Fatal, message);
                    return; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                if (lhs == math.MIN_INT and rhs == -1) {
                    // the absolute value of MIN_INT is 1 greater than MAX_INT, thus overflow would happen.
                    // interestingly the wrap around result would just be MIN_INT.
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] / rhs[{}] doing truncation division. Using wrap around result of [{}]", .{ lhs, rhs, math.MIN_INT });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.DivisionIntegerOverflow, ErrorSeverity.Warning, message);
                    stack.stack[registers.dst].int = math.MIN_INT; // zig doesnt have divison overflow operator
                } else {
                    stack.stack[registers.dst].int = @divTrunc(lhs, rhs);
                }
            },
            .IntDivideFloor => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                const lhs = stack.stack[registers.src1].int;
                const rhs = stack.stack[registers.src2].int;
                if (rhs == 0) {
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] / rhs[{}] doing floor division", .{ lhs, rhs });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.DivideByZero, ErrorSeverity.Fatal, message);
                    return; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                if (lhs == math.MIN_INT and rhs == -1) {
                    // the absolute value of MIN_INT is 1 greater than MAX_INT, thus overflow would happen.
                    // interestingly the wrap around result would just be MIN_INT.
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] / rhs[{}] doing floor division. Using wrap around result of [{}]", .{ lhs, rhs, math.MIN_INT });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.DivisionIntegerOverflow, ErrorSeverity.Warning, message);
                    stack.stack[registers.dst].int = math.MIN_INT; // zig doesnt have divison overflow operator
                } else {
                    stack.stack[registers.dst].int = @divFloor(lhs, rhs);
                }
            },
            .IntModulo => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                const lhs = stack.stack[registers.src1].int;
                const rhs = stack.stack[registers.src2].int;
                if (rhs == 0) {
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] / rhs[{}] doing modulo", .{ lhs, rhs });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.ModuloByZero, ErrorSeverity.Fatal, message);
                    return; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                stack.stack[registers.dst].int = @mod(lhs, rhs);
            },
            .IntRemainder => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                const lhs = stack.stack[registers.src1].int;
                const rhs = stack.stack[registers.src2].int;
                if (rhs == 0) {
                    const message = try allocPrintZ(self.allocator, "Numbers lhs[{}] / rhs[{}] doing remainder", .{ lhs, rhs });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.RemainderByZero, ErrorSeverity.Fatal, message);
                    return; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                stack.stack[registers.dst].int = @rem(lhs, rhs);
            },
            .IntPower => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                const base = stack.stack[registers.src1].int;
                const exp = stack.stack[registers.src2].int;

                const result = math.powOverflow(base, exp);
                if (result) |numAndOverflow| {
                    stack.stack[registers.dst].int = numAndOverflow[0];

                    if (numAndOverflow[1]) {
                        const message = try allocPrintZ(self.allocator, "Numbers base[{}] to the power of exp[{}]. Using wrap around result of [{}]", .{ base, exp, numAndOverflow[0] });
                        defer self.allocator.free(message);

                        self.runtimeError(RuntimeError.PowerIntegerOverflow, ErrorSeverity.Warning, message);
                    }
                } else |_| {
                    const message = try allocPrintZ(self.allocator, "Numbers base[{}] to the power of exp[{}]", .{ base, exp });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.ZeroToPowerOfNegative, ErrorSeverity.Fatal, message);
                    return; // TODO figure out how to free all the memory and resources allocated in the callstack
                }
            },
            .BitwiseComplement => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                const registers = getAndValidateDstSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].int = ~stack.stack[registers.src].int;
            },
            .BitwiseAnd => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].int = stack.stack[registers.src1].int & stack.stack[registers.src2].int;
            },
            .BitwiseOr => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].int = stack.stack[registers.src1].int | stack.stack[registers.src2].int;
            },
            .BitwiseXor => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].int = stack.stack[registers.src1].int ^ stack.stack[registers.src2].int;
            },
            .BitShiftLeft => {
                const MASK = 0b111111;

                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                if (stack.stack[registers.src2].int > 63 or stack.stack[registers.src2].int < 0) {
                    const message = try allocPrintZ(self.allocator, "Cannot bitwise left shift by [{}] bits. Instead left shifting using 6 least significant bits: [{}]", .{
                        stack.stack[registers.src2].int,
                        stack.stack[registers.src2].int & MASK,
                    });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.InvalidBitShiftAmount, ErrorSeverity.Warning, message);
                }

                stack.stack[registers.dst].int = stack.stack[registers.src1].int << @intCast(stack.stack[registers.src2].int & MASK);
            },
            .BitArithmeticShiftRight => {
                const MASK = 0b111111;

                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                if (stack.stack[registers.src2].int > 63 or stack.stack[registers.src2].int < 0) {
                    const message = try allocPrintZ(self.allocator, "Cannot bitwise right shift by [{}] bits. Instead right shifting using 6 least significant bits: [{}]", .{
                        stack.stack[registers.src2].int,
                        stack.stack[registers.src2].int & MASK,
                    });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.InvalidBitShiftAmount, ErrorSeverity.Warning, message);
                }

                stack.stack[registers.dst].int = stack.stack[registers.src1].int >> @intCast(stack.stack[registers.src2].int & MASK);
            },
            .BitLogicalShiftRight => {
                const MASK = 0b111111;

                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                const registers = getAndValidateDstTwoSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                if (stack.stack[registers.src2].int > 63 or stack.stack[registers.src2].int < 0) {
                    const message = try allocPrintZ(self.allocator, "Cannot bitwise right shift by [{}] bits. Instead right shifting using 6 least significant bits: [{}]", .{
                        stack.stack[registers.src2].int,
                        stack.stack[registers.src2].int & MASK,
                    });
                    defer self.allocator.free(message);

                    self.runtimeError(RuntimeError.InvalidBitShiftAmount, ErrorSeverity.Warning, message);
                }

                stack.stack[registers.dst].actualValue = stack.stack[registers.src1].actualValue >> @intCast(stack.stack[registers.src2].actualValue & MASK);
            },
            .IntToBool => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                const registers = getAndValidateDstSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].boolean = stack.stack[registers.src].int != 0;
            },
            .IntToFloat => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                const registers = getAndValidateDstSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].float = @floatFromInt(stack.stack[registers.src].int);
            },
            .IntToString => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                const registers = getAndValidateDstSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].string = try String.fromInt(stack.stack[registers.src].int, self);
            },
            .BoolNot => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                const registers = getAndValidateDstSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].boolean = !stack.stack[registers.src].boolean;
            },
            .BoolToString => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                const registers = getAndValidateDstSrcRegisterPos(stackPointer, currentStackFrameSize, operands);

                stack.stack[registers.dst].string = try String.fromBool(stack.stack[registers.src].boolean, self);
            },
            else => {
                @panic("not implemented");
            },
        }
        instructionPointer += 1;
    }
}

fn getAndValidateDstTwoSrcRegisterPos(stackPointer: usize, currentStackFrameSize: usize, operands: Bytecode.OperandsDstTwoSrc) struct { dst: usize, src1: usize, src2: usize } {
    assert(@as(usize, operands.dst) < currentStackFrameSize);
    assert(@as(usize, operands.src1) < currentStackFrameSize);
    assert(@as(usize, operands.src2) < currentStackFrameSize);

    const dstRegisterPos = stackPointer + @as(usize, operands.dst);
    const src1RegisterPos = stackPointer + @as(usize, operands.src1);
    const src2RegisterPos = stackPointer + @as(usize, operands.src2);

    return .{ .dst = dstRegisterPos, .src1 = src1RegisterPos, .src2 = src2RegisterPos };
}

fn getAndValidateDstSrcRegisterPos(stackPointer: usize, currentStackFrameSize: usize, operands: Bytecode.OperandsDstSrc) struct { dst: usize, src: usize } {
    assert(@as(usize, operands.dst) < currentStackFrameSize);
    assert(@as(usize, operands.src) < currentStackFrameSize);

    const dstRegisterPos = stackPointer + @as(usize, operands.dst);
    const srcRegisterPos = stackPointer + @as(usize, operands.src);

    return .{ .dst = dstRegisterPos, .src = srcRegisterPos };
}

/// Handles reporting errors, and other user specific data.
/// In `CubicScriptState.zig`, an example of implementing this can be found with `ScriptTestingContextError`.
pub const ScriptContext = extern struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = extern struct {
        /// `message` will be a null terminated string, using `messageLength` bytes excluding null terminator (number of UTF-8 bytes NOT code points).
        errorCallback: *const fn (self: *anyopaque, state: *const Self, err: RuntimeError, severity: ErrorSeverity, message: [*c]const u8, messageLength: usize) callconv(.C) void,
        /// Deinitializes the script context object itself. Can be used to call C++ destructors, Rust drop, or whatever else.
        deinit: *const fn (self: *anyopaque) callconv(.C) void,
    };

    pub fn runtimeError(self: *ScriptContext, state: *const Self, err: RuntimeError, severity: ErrorSeverity, message: []const u8) void {
        self.vtable.errorCallback(
            self.ptr,
            state,
            err,
            severity,
            @ptrCast(message.ptr),
            message.len,
        );
    }

    pub fn deinit(self: *ScriptContext) void {
        self.vtable.deinit(self.ptr);
    }
};

const default_context = ScriptContext{
    .ptr = undefined,
    .vtable = &.{
        .errorCallback = defaultContextErrorCallback,
        .deinit = defaultContextDeinit,
    },
};

fn defaultContextErrorCallback(_: *anyopaque, _: *const Self, err: RuntimeError, severity: ErrorSeverity, message: [*c]const u8, messageLength: usize) callconv(.C) void {
    if (runtime_safety) {
        if (messageLength > 0) {
            std.debug.print("Cubic Script {s}: {s}\n\t{s}\n", .{ @tagName(severity), @tagName(err), message });
        } else {
            std.debug.print("Cubic Script {s}: {s}\n", .{ @tagName(severity), @tagName(err) });
        }
    }
}

fn defaultContextDeinit(_: *anyopaque) callconv(.C) void {}

test "nop" {
    const state = try Self.init(std.testing.allocator, null);
    defer state.deinit();

    const stack = try Stack.init(state);
    defer stack.deinit();

    const instructions = [_]Bytecode{
        Bytecode.encode(OpCode.Nop, void, {}),
    };

    try state.run(stack, &instructions);
}

test "int comparisons" {
    const IntComparisonTester = struct {
        fn intCompare(state: *const Self, stack: *Stack, opcode: OpCode, src1Value: i64, src2Value: i64, shouldBeTrue: bool) !void {
            const LOW_MASK = 0xFFFFFFFF;
            const HIGH_MASK: usize = @shlExact(0xFFFFFFFF, 32);
            const src1: usize = @bitCast(src1Value);
            const src2: usize = @bitCast(src2Value);

            const instructions = [_]Bytecode{
                Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
                Bytecode{ .value = @intCast(src1 & LOW_MASK) },
                Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
                Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
                Bytecode{ .value = @intCast(src2 & LOW_MASK) },
                Bytecode{ .value = @intCast(@shrExact(src2 & HIGH_MASK, 32)) },
                Bytecode.encode(opcode, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
            };

            try state.run(stack, &instructions);

            if (shouldBeTrue) {
                try expect(stack.stack[2].boolean == true);
            } else {
                try expect(stack.stack[2].boolean == false);
            }
        }
    };

    {
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsEqual, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsEqual, math.MAX_INT, 123456789, false);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsNotEqual, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsNotEqual, math.MAX_INT, 123456789, true);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessThan, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessThan, math.MAX_INT, 123456789, false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessThan, -1, math.MAX_INT, true);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterThan, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterThan, math.MAX_INT, 123456789, true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterThan, -1, math.MAX_INT, false);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessOrEqual, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessOrEqual, math.MAX_INT, 123456789, false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessOrEqual, -1, math.MAX_INT, true);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterOrEqual, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterOrEqual, math.MAX_INT, 123456789, true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterOrEqual, -1, math.MAX_INT, false);
    }
}

/// Used for testing to validate that certain errors happened.
fn ScriptTestingContextError(comptime ErrTag: RuntimeError) type {
    return struct {
        shouldExpectError: bool,
        didErrorHappen: bool = false,

        fn errorCallback(self: *@This(), _: *const Self, err: RuntimeError, _: ErrorSeverity, _: [*c]const u8, _: usize) callconv(.C) void {
            if (err == ErrTag) {
                self.didErrorHappen = true;
            } else {
                @panic("unexpected error");
            }
        }

        fn deinit(self: *@This()) callconv(.C) void {
            if (self.shouldExpectError) {
                expect(self.didErrorHappen) catch unreachable;
            } else {
                expect(!self.didErrorHappen) catch unreachable;
            }
        }

        fn asContext(self: *@This()) ScriptContext {
            return ScriptContext{
                .ptr = @ptrCast(self),
                .vtable = &.{ .errorCallback = @ptrCast(&@This().errorCallback), .deinit = @ptrCast(&@This().deinit) },
            };
        }
    };
}

test "int addition" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.AdditionIntegerOverflow){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: i64 = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = 10;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(src1 & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntAdd, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 11);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.AdditionIntegerOverflow){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: i64 = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = math.MAX_INT;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(src1 & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntAdd, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == math.MIN_INT);
    }
}

test "int subtraction" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.AdditionIntegerOverflow){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = 10;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntSubtract, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 9);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.SubtractionIntegerOverflow){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: usize = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = math.MIN_INT;
        const srcAsUsize: usize = @bitCast(src1);

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(srcAsUsize & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(srcAsUsize & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntSubtract, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == math.MAX_INT);
    }
}

test "int multiplication" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.MultiplicationIntegerOverflow){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: i64 = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = math.MAX_INT;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(src1 & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntMultiply, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == math.MAX_INT);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.MultiplicationIntegerOverflow){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: i64 = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = math.MAX_INT;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(src1 & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 2 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntMultiply, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == -2); // this ends up being the wrap around. same as unsigned bitshift left by 1 then bitcasted to signed
    }
}

test "int division truncation" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntDivideTrunc, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == -2);
    }
    { // validate integer overflow
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, math.MIN_INT),
            Bytecode.encodeImmediateUpper(i64, math.MIN_INT),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.IntDivideTrunc, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == math.MIN_INT);
    }
    { // validate divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.DivideByZero){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.IntDivideTrunc, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
    }
}

test "int division floor" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntDivideFloor, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == -3);
    }
    { // validate integer overflow
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, math.MIN_INT),
            Bytecode.encodeImmediateUpper(i64, math.MIN_INT),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.IntDivideFloor, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == math.MIN_INT);
    }
    { // validate divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.DivideByZero){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.IntDivideFloor, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
    }
}

test "int modulo" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.ModuloByZero){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntModulo, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 1);
    }
    { // divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.ModuloByZero){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.IntModulo, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
    }
}

test "int remainder" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.RemainderByZero){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntRemainder, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == -1);
    }
    { // divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.RemainderByZero){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.IntRemainder, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
    }
}

test "int power" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 25);
    }
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, -2),
            Bytecode.encodeImmediateUpper(i64, -2),
            Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 0);
    }
    { // overflow
        var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, math.MAX_INT),
            Bytecode.encodeImmediateUpper(i64, math.MAX_INT),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
    }
    { // 0 to the power of negative error
        var contextObject = ScriptTestingContextError(RuntimeError.ZeroToPowerOfNegative){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, -2),
            Bytecode.encodeImmediateUpper(i64, -2),
            Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
    }
}

test "bitwise complement" {
    {
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.BitwiseComplement, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].int == -1); // ~0
    }
    {
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const src1: i64 = 1;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.BitwiseComplement, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].int == -2); // ~1
    }
}

test "bitwise and" {
    {
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b011),
            Bytecode.encodeImmediateUpper(i64, 0b011),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.BitwiseAnd, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 0b010);
    }
}

test "bitwise or" {
    {
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b011),
            Bytecode.encodeImmediateUpper(i64, 0b011),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.BitwiseOr, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 0b111);
    }
}

test "bitwise xor" {
    {
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b011),
            Bytecode.encodeImmediateUpper(i64, 0b011),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.BitwiseXor, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 0b101);
    }
}

test "bitshift left" {
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitShiftLeft, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == -2);
    }
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
            Bytecode.encodeImmediateUpper(i64, 65),
            Bytecode.encode(OpCode.BitShiftLeft, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == -2);
    }
}

test "bitshift arithmetic right" {
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 0b011);
    }
    { // retain sign bit
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == -1);
    }
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
            Bytecode.encodeImmediateUpper(i64, 65),
            Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 0b011);
    }
}

test "bitshift logical right" {
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 0b011);
    }
    { // dont retain sign bit
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == math.MAX_INT);
    }
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

        const state = try Self.init(std.testing.allocator, contextObject.asContext());
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
            Bytecode.encodeImmediateUpper(i64, 65),
            Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[2].int == 0b011);
    }
}

test "int to bool" {
    { // 0 -> false
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].boolean == false);
    }
    { // 1 -> true
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].boolean == true);
    }
    { // non-zero -> true
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 33),
            Bytecode.encodeImmediateUpper(i64, 33),
            Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].boolean == true);
    }
}

test "int to float" {
    { // 0
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].float == 0.0);
    }
    { // 1
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].float == 1.0);
    }
    { // -1
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].float == -1.0);
    }
    { // arbitrary value
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -2398712938),
            Bytecode.encodeImmediateUpper(i64, -2398712938),
            Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].float == -2398712938.0);
    }
}

test "int to string" {
    { // 0
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].string.eqlSlice("0"));
        stack.stack[1].string.deinit(state);
    }
    { // 1
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].string.eqlSlice("1"));
        stack.stack[1].string.deinit(state);
    }
    { // -1
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].string.eqlSlice("-1"));
        stack.stack[1].string.deinit(state);
    }
    { // arbitrary value
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -2398712938),
            Bytecode.encodeImmediateUpper(i64, -2398712938),
            Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].string.eqlSlice("-2398712938"));
        stack.stack[1].string.deinit(state);
    }
}

test "bool not" {
    {
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.BoolNot, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].boolean == true);
    }
    {
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(bool, true),
            Bytecode.encodeImmediateUpper(bool, true),
            Bytecode.encode(OpCode.BoolNot, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].boolean == false);
    }
}

test "bool to string" {
    { // true
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(bool, true),
            Bytecode.encodeImmediateUpper(bool, true),
            Bytecode.encode(OpCode.BoolToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].string.eqlSlice("true"));
        stack.stack[1].string.deinit(state);
    }
    { // false
        const state = try Self.init(std.testing.allocator, null);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(bool, false),
            Bytecode.encodeImmediateUpper(bool, false),
            Bytecode.encode(OpCode.BoolToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        try state.run(stack, &instructions);
        try expect(stack.stack[1].string.eqlSlice("false"));
        stack.stack[1].string.deinit(state);
    }
}
