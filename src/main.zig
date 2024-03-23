const std = @import("std");
const cubic_script = @import("cubic_script");
const String = cubic_script.String;
const ValueTag = cubic_script.ValueTag;
const Map = cubic_script.Map;
const TaggedValue = cubic_script.TaggedValue;
const CubicScriptState = cubic_script.CubicScriptState;
const Stack = cubic_script.Stack;
const OpCode = cubic_script.instruction.OpCode;
const Bytecode = cubic_script.instruction.Bytecode;

pub fn main() !void {
    const state = try CubicScriptState.init(std.heap.c_allocator);
    const stack = try Stack.init(state);

    const instructions = [_]Bytecode{
        Bytecode{ .value = @intFromEnum(OpCode.Nop) },
        Bytecode.encodeA(OpCode.LoadImmediate, 0),
        Bytecode{ .value = 0xFFFFFFFF },
        Bytecode{ .value = 0xFFFFFFFF },
    };

    state.run(stack, &instructions);

    std.debug.print("{}\n", .{stack.stack[0].actualValue});

    state.run(stack, &.{Bytecode.encodeA(OpCode.LoadZero, 0)});

    std.debug.print("{}\n", .{stack.stack[0].actualValue});
}
