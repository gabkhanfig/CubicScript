const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const TaggedValue = root.TaggedValue;
const Stack = @import("Stack.zig");
const StackFrame = Stack.StackFrame;
const Bytecode = @import("Bytecode.zig");
const OpCode = Bytecode.OpCode;
const String = root.String;
const math = @import("../types/math.zig");
const Error = @import("Errors.zig");
const allocPrintZ = std.fmt.allocPrintZ;
const runtime_safety: bool = std.debug.runtime_safety;
const Mutex = std.Thread.Mutex;
const allocator = @import("global_allocator.zig").allocator;
const sync_queue = @import("sync_queue.zig");

// TODO scripts using different allocators can risk passing around memory to different states.
// Therefore, all states should use the same global allocator. Perhaps there can be a function to change the allocator.

pub const RuntimeError = Error.RuntimeError;
pub const ErrorSeverity = Error.Severity;
pub const FatalScriptError = Error.FatalScriptError;
// https://github.com/ziglang/zig/issues/16419
pub const RuntimeErrorCallback = *const fn (err: RuntimeError, severity: ErrorSeverity, message: []const u8) void;
pub const CRuntimeErrorCallback = *const fn (err: c_int, severity: c_int, message: ?[*c]const u8, messageLength: usize) void;

const Self = @This();

_context: ScriptContext,
_contextMutex: Mutex = .{},

/// Create a new state with an allocator and an optional error callback.
/// If a `null` error callback is provided, the default one will be used, which
/// with `std.debug.runtime_safety`, will log all messages. Without runtime safety,
/// no messages will be logged.
pub fn init(context: ?ScriptContext) *Self {
    const self = allocator().create(Self) catch {
        @panic("Script out of memory");
    };
    self.* = Self{
        ._context = if (context) |ctx| ctx else ScriptContext.default_context,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    self._context.deinit();
    allocator().destroy(self);
}

/// Handles reporting errors, and other user specific data.
/// In `CubicScriptState.zig`, an example of implementing this can be found with `ScriptTestingContextError`.
pub const ScriptContext = extern struct {
    pub const default_context = ScriptContext{
        .ptr = undefined,
        .vtable = &.{
            .errorCallback = defaultContextErrorCallback,
            .deinit = defaultContextDeinit,
        },
    };

    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = extern struct {
        /// `message` will be a null terminated string, using `messageLength` bytes excluding null terminator (number of UTF-8 bytes NOT code points).
        errorCallback: *const fn (self: *anyopaque, state: *const Self, err: RuntimeError, severity: ErrorSeverity, message: [*c]const u8, messageLength: usize) callconv(.C) void,
        /// Deinitializes the script context object itself. Can be used to call C++ destructors, Rust drop, or whatever else.
        deinit: *const fn (self: *anyopaque) callconv(.C) void,
    };

    pub fn runtimeError(self: *ScriptContext, state: *const Self, err: RuntimeError, severity: ErrorSeverity, message: []const u8) void {
        self.vtable.errorCallback(
            self.ptr,
            state,
            err,
            severity,
            @ptrCast(message.ptr),
            message.len,
        );
    }

    pub fn deinit(self: *ScriptContext) void {
        self.vtable.deinit(self.ptr);
    }

    fn defaultContextErrorCallback(_: *anyopaque, _: *const Self, err: RuntimeError, severity: ErrorSeverity, message: [*c]const u8, messageLength: usize) callconv(.C) void {
        if (runtime_safety) {
            if (messageLength > 0) {
                std.debug.print("Cubic Script {s}: {s}\n\t{s}\n", .{ @tagName(severity), @tagName(err), message });
            } else {
                std.debug.print("Cubic Script {s}: {s}\n", .{ @tagName(severity), @tagName(err) });
            }
        }
    }

    fn defaultContextDeinit(_: *anyopaque) callconv(.C) void {}
};
