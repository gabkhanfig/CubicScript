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
    _ = @import("platform/mem.zig");
}

pub const String = script_value.String;
pub const Array = script_value.Array;
pub const Set = script_value.Set;
pub const Map = script_value.Map;
pub const Option = script_value.Option;
pub const Error = script_value.Error;
pub const Result = script_value.Result;
pub const Unique = script_value.Unique;
pub const Shared = script_value.Unique;
pub const Weak = script_value.Weak;
pub const Vec2i = script_value.Vec2i;
pub const Vec3i = script_value.Vec3i;
pub const Vec4i = script_value.Vec4i;
pub const Vec2f = script_value.Vec2f;
pub const Vec3f = script_value.Vec3f;
pub const Vec4f = script_value.Vec4f;

pub const c = script_value.c;

pub const sync_queue = @import("sync/sync_queue.zig");

const script_value = @import("primitives/script_value.zig");
