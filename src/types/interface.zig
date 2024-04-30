const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const String = root.String;
const allocator = @import("../state/global_allocator.zig").allocator;
const Class = @import("class.zig").Class;
const ClassMemberInfo = @import("class.zig").ClassMemberInfo;
const RuntimeClassInfo = @import("class.zig").RuntimeClassInfo;

/// `Interface` is actually just an offset pointer into a class, starting at the class's
/// version of the interface vtable.
pub const Interface = extern struct {
    const Self = @This();

    /// Frees the actual class that this interface "owns".
    ///
    /// NOTE
    ///
    /// Ensure that this instance actually owns the class, rather than is a reference.
    pub fn deinit(self: *Self) void {
        var classObj = Class{ .inner = @intFromPtr(self) };
        classObj.deinit();
    }

    pub fn interfaceName(self: *const Self) *const String {
        return &getRuntimeInterfaceInfo(self).interfaceName;
    }

    pub fn fullyQualifiedInterfaceName(self: *const Self) *const String {
        return &getRuntimeInterfaceInfo(self).fullyQualifiedName;
    }

    pub fn className(self: *const Self) *const String {
        const classInfo: *const RuntimeClassInfo = @ptrCast(classStartPtr(self));
        return &classInfo.className;
    }

    pub fn fullyQualifiedClassName(self: *const Self) *const String {
        const classInfo: *const RuntimeClassInfo = @ptrCast(classStartPtr(self));
        return &classInfo.fullyQualifiedName;
    }
};

pub fn getRuntimeInterfaceInfo(interface: *const Interface) *const RuntimeInterfaceInfo {
    // The first element is always the runtime interface info
    return @ptrCast(interface);
}

/// Returns a pointer to the start of the class data.
/// This also happens to be `*const RuntimeClassInfo`.
fn classStartPtr(interface: *const Interface) *align(@alignOf(usize)) const anyopaque {
    const topOffset = getRuntimeInterfaceInfo(interface).topOffset;
    const interfaceAddr = @intFromPtr(interface);
    const classAddr: usize = interfaceAddr - topOffset;
    return @ptrFromInt(classAddr);
}

/// Returns a pointer to the start of the class data.
/// This also happens to be `*const RuntimeClassInfo`.
fn classStartPtrMut(interface: *Interface) *align(@alignOf(usize)) anyopaque {
    const topOffset = getRuntimeInterfaceInfo(interface).topOffset;
    const interfaceAddr = @intFromPtr(interface);
    const classAddr: usize = interfaceAddr - topOffset;
    return @ptrFromInt(classAddr);
}

pub const RuntimeInterfaceInfo = struct {
    /// Specifies the byte offset from the start of the inner memory layout
    /// of a class.
    topOffset: usize,
    interfaceName: String,
    fullyQualifiedName: String,
    members: []ClassMemberInfo,
};
