comptime {
    // Force linker to link all Zig re-implemented exports
    _ = @import("util/global_allocator.zig");

    // Many tests are within the structs themselves, so importing .ScriptThread for example is necessary.
    _ = @import("util/script_thread.zig").ScriptThread;

    _ = @import("primitives/string.zig").String;
    _ = @import("primitives/array.zig").Array;
    _ = @import("primitives/map.zig").Map;
}
