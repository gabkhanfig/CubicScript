const std = @import("std");
const cubic_script = @import("cubic_script");
const String = cubic_script.String;
const ValueTag = cubic_script.ValueTag;
const Map = cubic_script.Map;
const TaggedValue = cubic_script.TaggedValue;
const CubicScriptState = cubic_script.CubicScriptState;
const Stack = cubic_script.Stack;
const Bytecode = cubic_script.Bytecode;
const OpCode = Bytecode.OpCode;

pub fn main() !void {
    const mem = cubic_script.allocator().alloc(u8, 2) catch unreachable;
    std.debug.print("{}\n", .{mem[0]});
}
