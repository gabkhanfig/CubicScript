//! The lifetime of this structure must never outlive the `CubicScriptState` instance that owns it.
//! The `Stack` uses about 16MB of memory per instance.

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const CubicScriptState = @import("CubicScriptState.zig");
const RawValue = root.RawValue;

// https://the-ravi-programming-language.readthedocs.io/en/latest/lua_bytecode_reference.html

/// Up to 256 different `RawValue`'s can be stored per stack frame.
pub const MAX_STACK_FRAME_SIZE = 256;
const STACK_SPACES: comptime_int = 1024 * 1024 * 2;
/// About 16 Megabytes
pub const STACK_SIZE: comptime_int = @sizeOf(RawValue) * STACK_SPACES;

const Self = @This();

state: *const CubicScriptState,
stack: [STACK_SPACES]RawValue align(64),

pub fn init(state: *const CubicScriptState) Allocator.Error!*Self {
    const self = try state.allocator.create(Self);
    // Cannot do inner.* = Inner{...} because of stack overflow. This is the next best option
    self.state = state;
    @memset(&self.stack, std.mem.zeroes(RawValue));
    return self;
}

pub fn deinit(self: *Self) void {
    self.state.allocator.destroy(self);
}

test "init deinit" {
    const state = try CubicScriptState.init(std.testing.allocator);
    defer state.deinit();

    const stack = try Self.init(state);
    defer stack.deinit();
}
