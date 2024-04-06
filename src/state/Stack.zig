//! The lifetime of this structure must never outlive the `CubicScriptState` instance that owns it.
//! The `Stack` uses about 16MB of memory per instance.

const std = @import("std");
const root = @import("../root.zig");
const CubicScriptState = @import("CubicScriptState.zig");
const RawValue = root.RawValue;
const assert = std.debug.assert;
const expect = std.testing.expect;

// https://the-ravi-programming-language.readthedocs.io/en/latest/lua_bytecode_reference.html
// https://learn.microsoft.com/en-us/cpp/build/reference/stack-stack-allocations?view=msvc-170

/// Up to 256 different `RawValue`'s can be stored per stack frame.
pub const MAX_STACK_FRAME_SIZE = 256;
const STACK_SPACES: comptime_int = 1024 * 128;
/// 1 Megabyte. Uses the same stack size as the MSVC default.
/// https://learn.microsoft.com/en-us/cpp/build/reference/stack-stack-allocations?view=msvc-170
pub const STACK_SIZE: comptime_int = @sizeOf(RawValue) * STACK_SPACES;

const Stack = @This();

state: *const CubicScriptState = undefined,
stack: [STACK_SPACES]RawValue align(64) = std.mem.zeroes([STACK_SPACES]RawValue),
/// Only used to handle recursive stack frames.
currentBasePointer: usize = 0,
/// If `currentBasePointer` is not zero, this can be used as a negative
/// offset to fetch the previous stack frame data, and restore it.
currentFrameLength: usize = 0,

pub const StackFrame = struct {
    const OLD_INSTRUCTION_POINTER = 0;
    const OLD_FRAME_LENGTH = 1;
    const FIELD_COUNT: usize = 3;

    basePointer: [*]RawValue,

    /// `frameLength` does not include the reserved registers for stack frames.
    /// Works with recursive stack frames.
    pub fn pushFrame(stack: *Stack, frameLength: usize, currentInstructionPointer: usize) error{StackOverflow}!StackFrame {
        assert(frameLength != 0);

        const newBasePointer: [*]RawValue = @ptrCast(&stack.stack[stack.currentBasePointer]);
        if (stack.currentBasePointer == 0) { // is at the beginning of the stack, no recursiveness
            newBasePointer[OLD_INSTRUCTION_POINTER].actualValue = 0;
            newBasePointer[OLD_FRAME_LENGTH].actualValue = 0;
        } else {
            if ((stack.currentFrameLength + FIELD_COUNT) >= STACK_SPACES) {
                return error.StackOverflow;
            }
            //const difference: usize = stack.currentBasePointer - (stack.currentFrameLength + FIELD_COUNT);
            //const oldBasePointer: [*]RawValue = @ptrFromInt(stack.currentBasePointer - difference);
            newBasePointer[OLD_INSTRUCTION_POINTER].actualValue = currentInstructionPointer;
            newBasePointer[OLD_FRAME_LENGTH].actualValue = stack.currentFrameLength;
        }
        stack.currentBasePointer += frameLength + FIELD_COUNT;
        stack.currentFrameLength = frameLength;

        return .{
            .basePointer = newBasePointer,
        };
    }

    /// Gets the old stack frame, or null if there was no previous.
    pub fn popFrame(self: *StackFrame, stack: *Stack) ?struct { instructionPointer: usize, frame: StackFrame } {
        assert(stack.currentBasePointer != 0); // Means that there is no stack to pop.

        const offset: usize = stack.currentFrameLength + FIELD_COUNT;
        stack.currentBasePointer -= offset;
        const oldBasePointer: [*]RawValue = @ptrFromInt(@intFromPtr(self.basePointer) - (stack.currentBasePointer * 8));
        stack.currentFrameLength = self.oldFrameLength();
        const oldIP = self.oldInstructionPointer();

        self.basePointer = undefined;
        return .{
            .instructionPointer = oldIP,
            .frame = .{ .basePointer = oldBasePointer },
        };
    }

    pub fn register(self: *StackFrame, registerIndex: usize) *RawValue {
        return self.basePointer[FIELD_COUNT + registerIndex];
    }

    fn oldInstructionPointer(self: *const StackFrame) usize {
        return self.basePointer[OLD_INSTRUCTION_POINTER].actualValue;
    }

    fn oldFrameLength(self: *const StackFrame) usize {
        return self.basePointer[OLD_FRAME_LENGTH].actualValue;
    }
};

test "push/pop one stack frame" {
    const stack = try std.testing.allocator.create(Stack);
    defer std.testing.allocator.destroy(stack);
    stack.* = .{};

    var frame = try StackFrame.pushFrame(stack, 1, 0);
    defer _ = frame.popFrame(stack);
}

test "push/pop two stack frames" {
    const stack = try std.testing.allocator.create(Stack);
    defer std.testing.allocator.destroy(stack);
    stack.* = .{};

    var frame1 = try StackFrame.pushFrame(stack, 1, 0);
    defer _ = frame1.popFrame(stack);

    const frame1BasePointer = stack.currentBasePointer;
    const frame1FrameLength = stack.currentFrameLength;

    {
        var frame2 = try StackFrame.pushFrame(stack, 2, 0);
        defer _ = frame2.popFrame(stack);

        try expect(stack.currentBasePointer != frame1BasePointer);
        try expect(stack.currentFrameLength != frame1FrameLength);
    }

    try expect(stack.currentBasePointer == frame1BasePointer);
    try expect(stack.currentFrameLength == frame1FrameLength);
}
