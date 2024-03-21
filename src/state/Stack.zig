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

pub const MAX_FUNCTION_LOCAL_VARIABLES = 256;
const STACK_SPACES: comptime_int = 1024 * 1024 * 2;
/// About 16 Megabytes
pub const STACK_SIZE: comptime_int = @sizeOf(RawValue) * STACK_SPACES;

const Self = @This();

/// Use *anyopaque to make simple compatibility with C / other languages.
/// The address this points to will never change during it's lifetime.
inner: *align(@alignOf(Inner)) anyopaque,

pub fn init(state: *const CubicScriptState) Allocator.Error!Self {
    const inner = try state.allocator.create(Inner);
    inner.* = Inner{
        .state = state,
        .stack = std.mem.zeroes([STACK_SPACES]RawValue),
    };
    return Self{ .inner = @ptrCast(inner) };
}

pub fn deinit(self: Self) void {
    const inner = self.asInnerMut();
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
