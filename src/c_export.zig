const std = @import("std");
const runtime_safety: bool = std.debug.runtime_safety;
const root = @import("root.zig");
const CubicScriptState = root.CubicScriptState;
const String = root.String;

export fn cubs_state_init() callconv(.C) ?*CubicScriptState {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    if (CubicScriptState.init(allocator, null)) |state| {
        std.debug.print("holy moly zig was called by msvc!", .{});
        return state;
    } else |_| {
        @panic("Failed to allocate memory in extern C");
        //return null;
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
