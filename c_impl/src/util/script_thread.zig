const std = @import("std");

const c = struct {
    extern fn cubs_thread_spawn(owner: ?*anyopaque) callconv(.C) ScriptThread;
    extern fn cubs_thread_close(thread: *ScriptThread) callconv(.C) void;
    extern fn cubs_thread_get_id(thread: *const ScriptThread) callconv(.C) c_int;
};

pub const ScriptThread = extern struct {
    const Self = @This();

    threadObj: *anyopaque,
    vtable: *const VTable,

    pub fn spawn() Self {
        return c.cubs_thread_spawn(null);
    }

    /// Explicitly close the thread. If `self.vtable.close == null`, does nothing.
    pub fn close(self: *Self) void {
        c.cubs_thread_close(self);
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
};
