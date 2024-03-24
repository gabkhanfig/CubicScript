const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const Stack = @import("Stack.zig");
const instruction_data = @import("instruction.zig");
const OpCode = instruction_data.OpCode;
const Bytecode = instruction_data.Bytecode;
const Operation = instruction_data.Operation;

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
                const operands = bytecode.decode(instruction_data.OpCode.OperandsMove);
                //const operands = instruction.decodeAB();
                const dstRegisterPos = stackPointer + @as(usize, @intCast(operands.dst));
                const srcRegisterPos = stackPointer + @as(usize, @intCast(operands.src));
                std.debug.print("Move: copying value at src[{}] to dst[{}]\n", .{ operands.src, operands.dst });
                assert(dstRegisterPos != srcRegisterPos); // Cannot be the same location
                stack.stack[dstRegisterPos] = stack.stack[srcRegisterPos];
            },
            .LoadZero => |dst| {
                const operand = bytecode.decode(instruction_data.OpCode.OperandsOnlyDst);
                const dstRegisterPos = stackPointer + @as(usize, @intCast(operand.dst));
                std.debug.print("LoadZero: setting dst[{}] to 0\n", .{dst});
                stack.stack[dstRegisterPos] = std.mem.zeroes(RawValue);
            },
            .LoadImmediate => {
                // NOTE the two bytecodes after `LoadImmediate` are the 64 bit immediate values, thus the instruction
                // pointer will need to be further incremented.
                const operand = bytecode.decode(instruction_data.OpCode.OperandsOnlyDst);
                const dstRegisterPos = stackPointer + @as(usize, @intCast(operand.dst));
                const immediate: usize =
                    @as(usize, @intCast(instructions[instructionPointer + 1].value)) |
                    @shlExact(@as(usize, @intCast(instructions[instructionPointer + 1].value)), 32);
                std.debug.print("LoadImmediate: copying immediate value [decimal: {}, hex: 0x{x}] to dst[{}]\n", .{ immediate, immediate, operand });
                stack.stack[dstRegisterPos].actualValue = immediate;
                instructionPointer += 2;
            },
            else => {
                @panic("not implemented");
            },
        }
        instructionPointer += 1;
    }
}
