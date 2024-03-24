const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const Stack = @import("Stack.zig");
const Bytecode = @import("Bytecode.zig");
const OpCode = Bytecode.OpCode;
const Bool = root.Bool;
const math = @import("../types/math.zig");

const Self = @This();

allocator: Allocator,
_usingExternalAllocator: bool,

pub fn init(allocator: Allocator) Allocator.Error!*Self {
    const self = try allocator.create(Self);
    self.* = Self{
        ._usingExternalAllocator = false,
        .allocator = allocator,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    if (!self._usingExternalAllocator) {
        self.allocator.destroy(self);
        return;
    }

    @panic("deinit using custom external allocator not yet implemented");
}

pub fn run(self: *const Self, stack: *Stack, instructions: []const Bytecode) void {
    _ = self;
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
                std.debug.print("no operation\n", .{});
            },
            .Exit => {
                std.debug.print("forcefully exiting script\n", .{});
                return;
            },
            .Move => {
                const operands = bytecode.decode(Bytecode.OperandsMove);
                const dstRegisterPos = stackPointer + @as(usize, operands.dst);
                const srcRegisterPos = stackPointer + @as(usize, @intCast(operands.src));

                assert(@as(usize, operands.src) < currentStackFrameSize); // Dont bother checking the dst, because that can extend past the stack frame.
                assert(dstRegisterPos != srcRegisterPos); // Cannot be the same location

                std.debug.print("Move: copying value at src[{}] to dst[{}]\n", .{ operands.src, operands.dst });
                stack.stack[dstRegisterPos] = stack.stack[srcRegisterPos];
            },
            .LoadZero => {
                const operand = bytecode.decode(Bytecode.OperandsOnlyDst);
                const dstRegisterPos = stackPointer + @as(usize, @intCast(operand.dst));

                // Dont bother checking the dst, because that can extend past the stack frame.
                assert(@as(usize, operand.dst) < currentStackFrameSize);

                std.debug.print("LoadZero: setting dst[{}] to 0\n", .{operand.dst});
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
                std.debug.print("LoadImmediate: copying immediate value [decimal: {}, hex: 0x{x}] to dst[{}]\n", .{ immediate, immediate, operand.dst });
                stack.stack[dstRegisterPos].actualValue = immediate;
                instructionPointer += 2;
            },
            .IntIsEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(@as(usize, operands.dst) < currentStackFrameSize);
                assert(@as(usize, operands.src1) < currentStackFrameSize);
                assert(@as(usize, operands.src2) < currentStackFrameSize);

                const dstRegisterPos = stackPointer + @as(usize, operands.dst);
                const src1RegisterPos = stackPointer + @as(usize, @intCast(operands.src1));
                const src2RegisterPos = stackPointer + @as(usize, @intCast(operands.src2));

                // TODO decide if registers should be allowed to overlap. Probably not
                assert(dstRegisterPos != src1RegisterPos);
                assert(dstRegisterPos != src2RegisterPos);
                assert(src1RegisterPos != src2RegisterPos);

                // This also works for bools because of the bit representation of signed and unsigned ints.
                stack.stack[dstRegisterPos].boolean = @intFromBool(stack.stack[src1RegisterPos].int == stack.stack[src2RegisterPos].int);
            },
            .IntIsNotEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(@as(usize, operands.dst) < currentStackFrameSize);
                assert(@as(usize, operands.src1) < currentStackFrameSize);
                assert(@as(usize, operands.src2) < currentStackFrameSize);

                const dstRegisterPos = stackPointer + @as(usize, operands.dst);
                const src1RegisterPos = stackPointer + @as(usize, @intCast(operands.src1));
                const src2RegisterPos = stackPointer + @as(usize, @intCast(operands.src2));

                // TODO decide if registers should be allowed to overlap. Probably not
                assert(dstRegisterPos != src1RegisterPos);
                assert(dstRegisterPos != src2RegisterPos);
                assert(src1RegisterPos != src2RegisterPos);

                // This also works for bools because of the bit representation of signed and unsigned ints.
                stack.stack[dstRegisterPos].boolean = @intFromBool(stack.stack[src1RegisterPos].int != stack.stack[src2RegisterPos].int);
            },
            .IntIsLessThan => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(@as(usize, operands.dst) < currentStackFrameSize);
                assert(@as(usize, operands.src1) < currentStackFrameSize);
                assert(@as(usize, operands.src2) < currentStackFrameSize);

                const dstRegisterPos = stackPointer + @as(usize, operands.dst);
                const src1RegisterPos = stackPointer + @as(usize, @intCast(operands.src1));
                const src2RegisterPos = stackPointer + @as(usize, @intCast(operands.src2));

                // TODO decide if registers should be allowed to overlap. Probably not
                assert(dstRegisterPos != src1RegisterPos);
                assert(dstRegisterPos != src2RegisterPos);
                assert(src1RegisterPos != src2RegisterPos);

                // This also works for bools because of the bit representation of signed and unsigned ints.
                stack.stack[dstRegisterPos].boolean = @intFromBool(stack.stack[src1RegisterPos].int < stack.stack[src2RegisterPos].int);
            },
            .IntIsGreaterThan => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(@as(usize, operands.dst) < currentStackFrameSize);
                assert(@as(usize, operands.src1) < currentStackFrameSize);
                assert(@as(usize, operands.src2) < currentStackFrameSize);

                const dstRegisterPos = stackPointer + @as(usize, operands.dst);
                const src1RegisterPos = stackPointer + @as(usize, @intCast(operands.src1));
                const src2RegisterPos = stackPointer + @as(usize, @intCast(operands.src2));

                // TODO decide if registers should be allowed to overlap. Probably not
                assert(dstRegisterPos != src1RegisterPos);
                assert(dstRegisterPos != src2RegisterPos);
                assert(src1RegisterPos != src2RegisterPos);

                // This also works for bools because of the bit representation of signed and unsigned ints.
                stack.stack[dstRegisterPos].boolean = @intFromBool(stack.stack[src1RegisterPos].int > stack.stack[src2RegisterPos].int);
            },
            .IntIsLessOrEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(@as(usize, operands.dst) < currentStackFrameSize);
                assert(@as(usize, operands.src1) < currentStackFrameSize);
                assert(@as(usize, operands.src2) < currentStackFrameSize);

                const dstRegisterPos = stackPointer + @as(usize, operands.dst);
                const src1RegisterPos = stackPointer + @as(usize, @intCast(operands.src1));
                const src2RegisterPos = stackPointer + @as(usize, @intCast(operands.src2));

                // TODO decide if registers should be allowed to overlap. Probably not
                assert(dstRegisterPos != src1RegisterPos);
                assert(dstRegisterPos != src2RegisterPos);
                assert(src1RegisterPos != src2RegisterPos);

                // This also works for bools because of the bit representation of signed and unsigned ints.
                stack.stack[dstRegisterPos].boolean = @intFromBool(stack.stack[src1RegisterPos].int <= stack.stack[src2RegisterPos].int);
            },
            .IntIsGreaterOrEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(@as(usize, operands.dst) < currentStackFrameSize);
                assert(@as(usize, operands.src1) < currentStackFrameSize);
                assert(@as(usize, operands.src2) < currentStackFrameSize);

                const dstRegisterPos = stackPointer + @as(usize, operands.dst);
                const src1RegisterPos = stackPointer + @as(usize, @intCast(operands.src1));
                const src2RegisterPos = stackPointer + @as(usize, @intCast(operands.src2));

                // TODO decide if registers should be allowed to overlap. Probably not
                assert(dstRegisterPos != src1RegisterPos);
                assert(dstRegisterPos != src2RegisterPos);
                assert(src1RegisterPos != src2RegisterPos);

                // This also works for bools because of the bit representation of signed and unsigned ints.
                stack.stack[dstRegisterPos].boolean = @intFromBool(stack.stack[src1RegisterPos].int >= stack.stack[src2RegisterPos].int);
            },

            else => {
                @panic("not implemented");
            },
        }
        instructionPointer += 1;
    }
}

test "int comparisons" {
    const IntComparisonTester = struct {
        fn intCompare(state: *const Self, stack: *Stack, opcode: OpCode, src1Value: root.Int, src2Value: root.Int, shouldBeTrue: bool) !void {
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

            state.run(stack, &instructions);

            if (shouldBeTrue) {
                try expect(stack.stack[2].boolean == root.TRUE);
            } else {
                try expect(stack.stack[2].boolean == root.FALSE);
            }
        }
    };

    {
        const state = try Self.init(std.testing.allocator);
        defer state.deinit();

        const stack = try Stack.init(state);
        defer stack.deinit();

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsEqual, std.math.maxInt(root.Int), std.math.maxInt(root.Int), true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsEqual, std.math.maxInt(root.Int), 123456789, false);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsNotEqual, std.math.maxInt(root.Int), std.math.maxInt(root.Int), false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsNotEqual, std.math.maxInt(root.Int), 123456789, true);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessThan, std.math.maxInt(root.Int), std.math.maxInt(root.Int), false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessThan, std.math.maxInt(root.Int), 123456789, false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessThan, -1, std.math.maxInt(root.Int), true);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterThan, std.math.maxInt(root.Int), std.math.maxInt(root.Int), false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterThan, std.math.maxInt(root.Int), 123456789, true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterThan, -1, std.math.maxInt(root.Int), false);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessOrEqual, std.math.maxInt(root.Int), std.math.maxInt(root.Int), true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessOrEqual, std.math.maxInt(root.Int), 123456789, false);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsLessOrEqual, -1, std.math.maxInt(root.Int), true);

        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterOrEqual, std.math.maxInt(root.Int), std.math.maxInt(root.Int), true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterOrEqual, std.math.maxInt(root.Int), 123456789, true);
        try IntComparisonTester.intCompare(state, stack, OpCode.IntIsGreaterOrEqual, -1, std.math.maxInt(root.Int), false);
    }
}
