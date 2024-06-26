const std = @import("std");
const assert = std.debug.assert;
const runtime_safety: bool = std.debug.runtime_safety;
const root = @import("root.zig");
const CubicScriptState = root.CubicScriptState;
const String = root.String;
const Allocator = std.mem.Allocator;
const ScriptContext = CubicScriptState.ScriptContext;
const global_allocator = @import("state/global_allocator.zig");

export fn cubs_state_init(contextPtr: ?*anyopaque, contextVTable: ?*const ScriptContext.VTable) callconv(.C) ?*CubicScriptState {
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
    return CubicScriptState.init(context);
}

export fn cubs_state_deinit(state: ?*CubicScriptState) callconv(.C) void {
    if (state) |s| {
        s.deinit();
    }
}

export fn cubs_set_allocator(allocatorPtr: ?*anyopaque, allocatorVTable: ?*const global_allocator.ScriptExternAllocator.ExternVTable) callconv(.C) void {
    if (allocatorPtr == null) {
        std.debug.print("[cubs_set_global_allocator]: Expected non-null allocatorPtr", .{});
        return;
    }
    if (allocatorVTable == null) {
        std.debug.print("[cubs_set_global_allocator]: Expected non-null allocatorVTable", .{});
        return;
    }

    global_allocator.externAllocator = .{ .externAllocatorPtr = allocatorPtr.?, .externVTable = allocatorVTable.? };
    global_allocator.setAllocator(Allocator{ .ptr = @ptrCast(&global_allocator.externAllocator), .vtable = &.{
        .alloc = &global_allocator.ScriptExternAllocator.externAlloc,
        .resize = &global_allocator.ScriptExternAllocator.externResize,
        .free = &global_allocator.ScriptExternAllocator.externFree,
    } });
}

export fn cubs_string_init_slice(outString: *String, buffer: [*c]const u8, length: usize) bool {
    if (buffer == null) {
        outString.* = String{};
        return true;
    }
    if (runtime_safety) { // evalutated at compile time
        for (0..length) |i| {
            if (buffer[i] == 0) {
                const message = std.fmt.allocPrint(std.heap.c_allocator, "String slice null terminator found before length of {}\n", .{length}) catch unreachable;
                std.debug.print("String slice null terminator found before length of {}\n", .{length});
                @panic(message);
            }
        }
    }
    if (String.initSlice(buffer[0..length])) |string| {
        outString.* = string;
        return true;
    } else |_| {
        return false;
    }
}

export fn cubs_string_init_slice_unchecked(buffer: [*c]const u8, length: usize) callconv(.C) String {
    if (buffer == null) {
        return String{};
    }
    return String.initSliceUnchecked(buffer[0..length]);
}

export fn cubs_string_clone(inString: *const String) callconv(.C) String {
    return inString.clone();
}

export fn cubs_string_deinit(inString: *String) callconv(.C) void {
    inString.deinit();
}

export fn cubs_string_len(inString: *const String) callconv(.C) usize {
    return inString.len();
}

export fn cubs_string_c_str(inString: *const String) callconv(.C) [*c]const u8 {
    return inString.toSlice().ptr;
}

// Utility stuff
