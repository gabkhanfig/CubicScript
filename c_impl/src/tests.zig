comptime {
    // Force linker to link all Zig re-implemented exports
    _ = @import("util/global_allocator.zig");

    // Many tests are within the structs themselves, so importing .String for example is necessary.
    _ = @import("primitives/string.zig").String;
}
