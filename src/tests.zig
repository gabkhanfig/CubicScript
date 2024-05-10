comptime {
    _ = @import("types/atomic_ref_count.zig");
    _ = @import("types/string.zig");
    _ = @import("types/array.zig");
    _ = @import("types/hash.zig");
    _ = @import("types/map.zig");
    _ = @import("types/vector.zig");
    _ = @import("types/math.zig");
    _ = @import("types/option.zig");
    _ = @import("state/CubicScriptState.zig");
    _ = @import("state/Stack.zig");
    _ = @import("state/Bytecode.zig");
    _ = @import("state/sync_queue.zig");
    _ = @import("state/global_allocator.zig");
    _ = @import("types/result.zig");
    _ = @import("types/references.zig");
    _ = @import("types/class.zig");
    _ = @import("compiler/FunctionBuilder.zig");
    _ = @import("compiler/ClassBuilder.zig");
    _ = @import("types/function.zig");
}
