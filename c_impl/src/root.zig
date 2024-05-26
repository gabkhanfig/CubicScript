//! Root module for the Zig implementation of CubicScript.
//! The only extra requirement to running is that a snippet of code
//! is used in whatever is the compilations root. For example,
//! compiling an exe with the root file of `main.zig` will require the following.
//! ```
//! // main.zig
//! comptime {
//!     _ = @import("cubic_script");
//! }
//! ```
//! This is required to export certain re-implemented functions that take
//! advantage of some features of Zig, while simultaneously preserving functionality in C.

comptime {
    _ = @import("util/global_allocator.zig");
}

pub const String = @import("primitives/string.zig").String;
pub const Array = @import("primitives/array.zig").Array;
pub const Set = @import("primitives/set/set.zig").Set;
pub const Map = @import("primitives/map.zig").Map;
