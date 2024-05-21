const std = @import("std");
const expect = std.testing.expect;

const c = struct {
    extern fn cubs_thread_spawn(closeWithScript: bool) callconv(.C) ScriptThread;
    extern fn cubs_thread_close(thread: *ScriptThread) callconv(.C) void;
    extern fn cubs_thread_get_id(thread: *const ScriptThread) callconv(.C) u32;
};

pub const ScriptThread = extern struct {
    const Self = @This();

    threadObj: *anyopaque,
    vtable: *const VTable,

    /// Create an instance of an OS specific script thread. Implemention is defined in `script_thread.c`.
    pub fn spawn() Self {
        return c.cubs_thread_spawn(false);
    }

    /// Explicitly close the thread. If `self.vtable.close == null`, does nothing.
    pub fn close(self: *Self) void {
        c.cubs_thread_close(self);
    }

    pub fn getId(self: *const Self) u32 {
        return c.cubs_thread_get_id(self);
    }

    pub const VTable = extern struct {
        onScriptClose: ?*const fn (threadObj: *anyopaque) callconv(.C) void = null,
        getId: *const fn (threadObj: *const anyopaque) callconv(.C) c_int,
        close: ?*const fn (threadObj: *anyopaque) callconv(.C) void = null,
    };

    test spawn { // also tests close
        var thread = Self.spawn();
        defer thread.close();
    }

    test getId {
        var thread = Self.spawn();
        defer thread.close();

        try expect(@as(u32, @intCast(std.Thread.getCurrentId())) != thread.getId());
    }
};
