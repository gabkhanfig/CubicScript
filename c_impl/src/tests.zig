comptime {
    // Force linker to link all Zig re-implemented exports
    _ = @import("util/global_allocator.zig");

    _ = @import("primitives/string.zig");
}
