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

/// Use *anyopaque to make simple compatibility with C / other languages.
/// The address this points to will never change during it's lifetime.
inner: *align(@alignOf(Inner)) anyopaque,

pub fn init(state: *const CubicScriptState) Allocator.Error!Self {
    const inner = try state.allocator.create(Inner);
    // Cannot do inner.* = Inner{...} because of stack overflow. This is the next best option
    inner.state = state;
    @memset(&inner.stack, std.mem.zeroes(RawValue));
    return Self{ .inner = @ptrCast(inner) };
}

pub fn deinit(self: Self) void {
    var mutSelf = self;
    const inner = mutSelf.asInnerMut();
    inner.state.allocator.destroy(inner);
}

pub fn asInner(self: Self) *const Inner {
    return @ptrCast(self.inner);
}

pub fn asInnerMut(self: *Self) *Inner {
    return @ptrCast(self.inner);
}

const Inner = struct {
    state: *const CubicScriptState,
    stack: [STACK_SPACES]RawValue align(64),
};

test "init deinit" {
    var state = try CubicScriptState.init(std.testing.allocator);
    defer state.deinit();

    const stack = try Self.init(state);
    defer stack.deinit();
}
