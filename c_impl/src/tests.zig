comptime {
    // Force linker to link all Zig re-implemented exports
    _ = @import("util/global_allocator.zig");

    // Many tests are within the structs themselves, so importing .ScriptThread for example is necessary.
    _ = @import("sync/script_thread.zig").ScriptThread;
    _ = @import("sync/locks.zig").Mutex;
    _ = @import("sync/locks.zig").RwLock;

    _ = @import("primitives/string/string.zig").String;
    _ = @import("primitives/array/array.zig").Array;
    _ = @import("primitives/set/set.zig").Set;
    _ = @import("primitives/map/map.zig").Map;
    _ = @import("primitives/script_value.zig").TaggedValue;
    _ = @import("primitives/option/option.zig").Option;
    _ = @import("primitives/result/result.zig").Error;
    _ = @import("primitives/result/result.zig").Result;
}
