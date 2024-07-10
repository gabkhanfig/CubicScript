comptime {
    // Force linker to link all Zig re-implemented exports
    _ = @import("util/global_allocator.zig");

    _ = @import("program/program.zig").Program;
    _ = @import("interpreter/interpreter.zig");

    // Many tests are within the structs themselves, so importing .ScriptThread for example is necessary.
    _ = @import("sync/thread.zig").ScriptThread;
    _ = @import("sync/locks.zig").Mutex;
    _ = @import("sync/locks.zig").RwLock;
    _ = @import("sync/sync_queue.zig");

    _ = @import("primitives/script_value.zig").TypeContext;

    _ = @import("primitives/string/string.zig").String;
    _ = @import("primitives/array/array.zig");
    _ = @import("primitives/set/set.zig");
    _ = @import("primitives/map/map.zig");
    //_ = @import("primitives/script_value.zig").TaggedValue;
    _ = @import("primitives/option/option.zig");
    _ = @import("primitives/error/error.zig");
    _ = @import("primitives/result/result.zig");
    _ = @import("primitives/vector/vector.zig").Vec2i;
    _ = @import("primitives/vector/vector.zig").Vec3i;
    _ = @import("primitives/vector/vector.zig").Vec4i;
    _ = @import("primitives/vector/vector.zig").Vec2f;
    _ = @import("primitives/vector/vector.zig").Vec3f;
    _ = @import("primitives/vector/vector.zig").Vec4f;
}
