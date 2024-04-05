//! The lifetime of this structure must never outlive the `CubicScriptState` instance that owns it.
//! The `Stack` uses about 16MB of memory per instance.

const std = @import("std");
const root = @import("../root.zig");
const CubicScriptState = @import("CubicScriptState.zig");
const RawValue = root.RawValue;

// https://the-ravi-programming-language.readthedocs.io/en/latest/lua_bytecode_reference.html
// https://learn.microsoft.com/en-us/cpp/build/reference/stack-stack-allocations?view=msvc-170

/// Up to 256 different `RawValue`'s can be stored per stack frame.
pub const MAX_STACK_FRAME_SIZE = 256;
const STACK_SPACES: comptime_int = 1024 * 128;
/// 1 Megabyte. Uses the same stack size as the MSVC default.
/// https://learn.microsoft.com/en-us/cpp/build/reference/stack-stack-allocations?view=msvc-170
pub const STACK_SIZE: comptime_int = @sizeOf(RawValue) * STACK_SPACES;

const Self = @This();

state: *const CubicScriptState = undefined,
stack: [STACK_SPACES]RawValue align(64) = std.mem.zeroes([STACK_SPACES]RawValue),
