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

pub const String = script_value.String;
pub const Array = script_value.Array;
pub const Set = script_value.Set;
pub const Map = script_value.Map;
pub const Option = script_value.Option;

const script_value = @import("primitives/script_value.zig");
