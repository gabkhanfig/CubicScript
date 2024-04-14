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
nextBasePointer: usize = 0,
/// If `currentBasePointer` is not zero, this can be used as a negative
/// offset to fetch the previous stack frame data, and restore it.
currentFrameLength: usize = 0,
instructionPointer: usize = 0,
returnValueDst: ?*RawValue = null,

pub const StackFrame = struct {
    const OLD_INSTRUCTION_POINTER = 0;
    const OLD_FRAME_LENGTH = 1;
    const OLD_RETURN_VALUE_DST = 2;
    const FIELD_COUNT: usize = @typeInfo(StackFrame).Struct.fields.len;

    basePointer: [*]RawValue,
    frameLength: usize,
    returnValueDst: ?*RawValue,

    /// `frameLength` does not include the reserved registers for stack frames.
    /// Works with recursive stack frames.
    pub fn pushFrame(stack: *Stack, frameLength: usize, newInstructionPointer: usize, returnValueDst: ?*RawValue) error{StackOverflow}!StackFrame {
        assert(frameLength != 0);

        const newBasePointer: [*]RawValue = @ptrCast(&stack.stack[stack.nextBasePointer]);
        if (stack.nextBasePointer == 0) { // is at the beginning of the stack, no recursiveness
            newBasePointer[OLD_INSTRUCTION_POINTER].actualValue = 0;
            newBasePointer[OLD_FRAME_LENGTH].actualValue = 0;
            newBasePointer[OLD_RETURN_VALUE_DST].actualValue = 0;
        } else {
            if ((stack.currentFrameLength + FIELD_COUNT) >= STACK_SPACES) {
                return error.StackOverflow;
            }
            newBasePointer[OLD_INSTRUCTION_POINTER].actualValue = stack.instructionPointer;
            newBasePointer[OLD_FRAME_LENGTH].actualValue = stack.currentFrameLength;
            newBasePointer[OLD_RETURN_VALUE_DST].actualValue = @intFromPtr(stack.returnValueDst);
        }
        stack.nextBasePointer += frameLength + FIELD_COUNT;
        stack.currentFrameLength = frameLength;
        stack.instructionPointer = newInstructionPointer;
        stack.returnValueDst = returnValueDst;

        return .{
            .basePointer = newBasePointer,
            .frameLength = frameLength,
            .returnValueDst = returnValueDst,
        };
    }

    /// Gets the old stack frame, or null if there was no previous.
    pub fn popFrame(self: *StackFrame, stack: *Stack) ?StackFrame {
        if (stack.nextBasePointer == 0) { // calling pop multiple times is ok, and makes executing the bytecodes easier
            return null;
        }
        const offset: usize = stack.currentFrameLength + FIELD_COUNT;
        stack.nextBasePointer -= offset;
        if (stack.nextBasePointer == 0) {
            return null;
        }
        const oldBasePointer: [*]RawValue = @ptrFromInt(@intFromPtr(self.basePointer) - (stack.nextBasePointer * 8));
        stack.currentFrameLength = self.oldFrameLength();
        const oldIP = self.oldInstructionPointer();
        stack.instructionPointer = oldIP;
        const oldRetValueDst = self.oldReturnValueDst();
        stack.returnValueDst = oldRetValueDst;

        self.basePointer = undefined;
        self.frameLength = undefined;
        self.frameLength = undefined;
        return .{
            .basePointer = oldBasePointer,
            .frameLength = stack.currentFrameLength,
            .returnValueDst = oldRetValueDst,
        };
    }

    /// Basically array indexing, but cannot access the previous stack frame's instruction pointer,
    /// nor previous stack frame's frame length.
    pub fn register(self: *StackFrame, registerIndex: usize) *RawValue {
        assert(registerIndex < self.frameLength);
        return &self.basePointer[FIELD_COUNT + registerIndex];
    }

    /// Sets the return value of this stack frame to whatever is held at register `registerIndex`.
    /// If this frame does not have a return value destination, safety check undefined behaviour is executed.
    pub fn setReturnValue(self: *StackFrame, registerIndex: usize) void {
        if (self.returnValueDst) |retDst| {
            retDst.* = self.register(registerIndex).*;
        } else {
            unreachable;
        }
    }

    fn oldInstructionPointer(self: *const StackFrame) usize {
        return self.basePointer[OLD_INSTRUCTION_POINTER].actualValue;
    }

    fn oldFrameLength(self: *const StackFrame) usize {
        return self.basePointer[OLD_FRAME_LENGTH].actualValue;
    }

    fn oldReturnValueDst(self: *const StackFrame) ?*RawValue {
        return @ptrFromInt(self.basePointer[OLD_RETURN_VALUE_DST].actualValue);
    }
};

test "push/pop one stack frame" {
    const stack = try std.testing.allocator.create(Stack);
    defer std.testing.allocator.destroy(stack);
    stack.* = .{};

    var frame = try StackFrame.pushFrame(stack, 1, 0, null);
    defer _ = frame.popFrame(stack);
}

test "push/pop two stack frames" {
    const stack = try std.testing.allocator.create(Stack);
    defer std.testing.allocator.destroy(stack);
    stack.* = .{};

    var frame1 = try StackFrame.pushFrame(stack, 1, 0, null);
    defer _ = frame1.popFrame(stack);

    const frame1BasePointer = stack.nextBasePointer;
    const frame1FrameLength = stack.currentFrameLength;

    {
        var frame2 = try StackFrame.pushFrame(stack, 2, 0, null);
        defer _ = frame2.popFrame(stack);

        try expect(stack.nextBasePointer != frame1BasePointer);
        try expect(stack.currentFrameLength != frame1FrameLength);
    }

    try expect(stack.nextBasePointer == frame1BasePointer);
    try expect(stack.currentFrameLength == frame1FrameLength);
}

test "stack frame access register" {
    const stack = try std.testing.allocator.create(Stack);
    defer std.testing.allocator.destroy(stack);
    stack.* = .{};

    var frame = try StackFrame.pushFrame(stack, 1, 0, null);
    defer _ = frame.popFrame(stack);

    frame.register(0).int = -1;
    try expect(frame.register(0).int == -1);
}

test "stack frame nested retain register" {
    const stack = try std.testing.allocator.create(Stack);
    defer std.testing.allocator.destroy(stack);
    stack.* = .{};

    var frame1 = try StackFrame.pushFrame(stack, 1, 0, null);
    defer _ = frame1.popFrame(stack);

    frame1.register(0).int = 20;
    try expect(frame1.register(0).int == 20);

    {
        var frame2 = try StackFrame.pushFrame(stack, 2, 0, null);
        defer _ = frame2.popFrame(stack);
    }

    try expect(frame1.register(0).int == 20);
}
