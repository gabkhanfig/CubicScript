const std = @import("std");
const assert = std.debug.assert;
const runtime_safety: bool = std.debug.runtime_safety;
const root = @import("root.zig");
const CubicScriptState = root.CubicScriptState;
const String = root.String;
const Allocator = std.mem.Allocator;
const ScriptContext = CubicScriptState.ScriptContext;

export fn cubs_state_init(
    contextPtr: ?*anyopaque,
    contextVTable: ?*const ScriptContext.VTable,
    allocatorPtr: ?*anyopaque,
    allocatorVTable: ?*const ScriptExternAllocator.ExternVTable,
) callconv(.C) ?*CubicScriptState {
    const context = blk: {
        if (contextPtr) |validContext| {
            assert(contextVTable != null);
            break :blk ScriptContext{ .ptr = validContext, .vtable = contextVTable.? };
        } else {
            break :blk ScriptContext.default_context;
        }
    };
    if (contextPtr != null) {
        assert(contextVTable != null);
    }

    const maybeState = stateBlk: {
        if (allocatorPtr) |validExternAllocator| {
            assert(allocatorVTable != null);
            const externAllocator = ScriptExternAllocator{ .externAllocatorPtr = validExternAllocator, .externVTable = allocatorVTable.? };
            break :stateBlk CubicScriptState.initWithExternAllocator(externAllocator, context);
        } else {
            const allocator = allocBlk: {
                if (runtime_safety) {
                    ScriptGeneralPurposeAllocator.assignFunc();
                    break :allocBlk ScriptGeneralPurposeAllocator.allocator;
                } else {
                    break :allocBlk std.heap.c_allocator;
                }
            };
            break :stateBlk CubicScriptState.init(allocator, context);
        }
    };
    if (maybeState) |state| {
        return state;
    } else |_| {
        return null;
    }
}

export fn cubs_string_init_slice(buffer: [*c]const u8, length: usize, state: *const CubicScriptState) callconv(.C) String {
    if (buffer == null) {
        return String{};
    }
    if (runtime_safety) { // evalutated at compile time
        for (0..length) |i| {
            if (buffer[i] == 0) {
                const message = std.fmt.allocPrint(state.allocator, "String slice null terminator found before length of {}\n", .{length}) catch {
                    @panic("Failed to allocate memory in extern C");
                };
                std.debug.print("String slice null terminator found before length of {}\n", .{length});
                @panic(message);
            }
        }
    }
    return String.initSlice(buffer[0..length], state) catch {
        @panic("Failed to allocate memory in extern C");
    };
}

export fn cubs_string_clone(inString: *const String) callconv(.C) String {
    return inString.clone();
}

export fn cubs_string_deinit(inString: *String, state: *const CubicScriptState) callconv(.C) void {
    inString.deinit(state);
}

export fn cubs_string_len(inString: *const String) callconv(.C) i64 {
    return inString.len();
}

export fn cubs_string_c_str(inString: *const String) callconv(.C) [*c]const u8 {
    return inString.toSlice().ptr;
}

// Utility stuff

const ScriptGeneralPurposeAllocator = struct {
    var allocator: Allocator = undefined;
    var once = std.once(@This().assignFunc);

    fn assignFunc() void {
        // Lives for the entire duration of the program, but is only created once.
        // Cannot just make the GPA on the stack, as that would be invalid memory.
        var gpa = std.heap.c_allocator.create(std.heap.GeneralPurposeAllocator(.{})) catch {
            @panic("Failed to create script general purpose allocator instance");
        };
        gpa.* = .{};
        allocator = gpa.allocator();
    }
};

pub const ScriptExternAllocator = struct {
    const Self = @This();

    externAllocatorPtr: *anyopaque,
    externVTable: *const ExternVTable,

    const ExternVTable = extern struct {
        alloc: *const fn (ctx: *anyopaque, len: usize, ptrAlign: u8) callconv(.C) ?*anyopaque,
        resize: *const fn (ctx: *anyopaque, bufPtr: *anyopaque, bufLen: usize, newLen: usize) callconv(.C) bool,
        free: *const fn (ctx: *anyopaque, bufPtr: ?*anyopaque, bufLen: usize, bufAlign: u8) callconv(.C) void,
        deinit: ?*const fn (ctx: *anyopaque) callconv(.C) void,
    };

    pub fn externAlloc(ctx: *anyopaque, len: usize, ptrAlign: u8, retAddr: usize) ?[*]u8 {
        _ = retAddr;
        assert(len > 0);
        const self: *Self = @ptrCast(@alignCast(ctx));
        const ptr = self.externVTable.alloc(self.externAllocatorPtr, len, ptrAlign);
        if (ptr) |allocation| {
            return @ptrCast(allocation);
        } else {
            return null;
        }
    }

    pub fn externResize(ctx: *anyopaque, buf: []u8, bufAlign: u8, newLen: usize, retAddr: usize) bool {
        _ = retAddr;
        _ = bufAlign;
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.externVTable.resize(
            self.externAllocatorPtr,
            buf.ptr,
            buf.len,
            newLen,
        );
    }

    pub fn externFree(ctx: *anyopaque, buf: []u8, bufAlign: u8, retAddr: usize) void {
        _ = retAddr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.externVTable.free(self.externAllocatorPtr, buf.ptr, buf.len, bufAlign);
    }

    pub fn deinit(self: *Self) void {
        if (self.externVTable.deinit) |deinitFunc| {
            deinitFunc(self.externAllocatorPtr);
        }
    }
};
