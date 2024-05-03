const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const String = root.String;
const allocator = @import("../state/global_allocator.zig").allocator;
const InterfaceRef = @import("interface.zig").InterfaceRef;
const OwnedInterface = @import("interface.zig").OwnedInterface;

pub const Class = extern struct {
    const PTR_BITMASK: usize = 0x0000FFFFFFFFFFFF;

    const Self = @This();

    /// Stores a pointer to the arbitrary memory in the following layout
    /// - [0] class RTTI
    /// - [1 -> n] class members
    /// - [v1] interface 1 vtable
    /// - [m1] interface 1 members
    /// - [v2] interface 2 vtable
    /// - [m2] interface 2 members
    /// - ...
    ///
    /// If the class implements no interfaces, only the RTTI and members are stored.
    inner: usize,

    pub fn deinit(self: *Self) void {
        // TODO execute script deinit as well
        for (self.membersInfo(), 0..) |info, i| {
            self.mutValueAt(i).deinit(info.dataType);
        }
        const allocationSize = getRuntimeClassInfo(self).size / 8;
        const ptr: [*]usize = @ptrFromInt(self.inner);
        allocator().free(ptr[0..allocationSize]);
    }

    /// Get an immutable reference to a class member.
    /// Used with `valueTagAt()` to determine the active union member.
    pub fn valueAt(self: *const Self, memberIndex: usize) *const RawValue {
        assert(memberIndex < getRuntimeClassInfo(self).members.len);
        const members: [*]const RawValue = @ptrCast(&@as([*]const RawValue, @ptrFromInt(self.inner))[1]); // Use index 1 to go past the RTTI
        return &members[memberIndex];
    }

    /// Get a mutable reference to a class member.
    /// Used with `valueTagAt()` to determine the active union member.
    pub fn mutValueAt(self: *Self, memberIndex: usize) *RawValue {
        assert(memberIndex < getRuntimeClassInfo(self).members.len);
        const members: [*]RawValue = @ptrCast(&@as([*]RawValue, @ptrFromInt(self.inner))[1]); // Use index 1 to go past the RTTI
        return &members[memberIndex];
    }

    /// Get the type of script value of the class at a specific member index.
    /// Combines with `valueAt()` or `mutValueAt()` to determine the active union member.
    pub fn valueTagAt(self: *const Self, memberIndex: usize) ValueTag {
        const runtimeInfo = getRuntimeClassInfo(self);
        assert(memberIndex < runtimeInfo.members.len);
        return runtimeInfo.members[memberIndex].dataType;
    }

    /// Get the name of this class. An example would be `"Player"`.
    /// To get the fully qualified name, see `fullyQualifiedClassName()`.
    /// This value is the same across multiple instances of this class.
    pub fn className(self: *const Self) *const String {
        return &getRuntimeClassInfo(self).className;
    }

    /// Get the fully qualified name of this class. An example would be `"example.Player"`.
    /// To get the class name alone, see `className()`.
    /// This value is the same across multiple instances of this class.
    pub fn fullyQualifiedClassName(self: *const Self) *const String {
        return &getRuntimeClassInfo(self).fullyQualifiedName;
    }

    /// Get a slice of the info of all the members of this class.
    /// This is the member name and script data type.
    pub fn membersInfo(self: *const Self) []const ClassMemberInfo {
        return getRuntimeClassInfo(self).members;
    }

    pub fn interfaces(self: *const Self) []const ClassInterfaceImplInfo {
        return getRuntimeClassInfo(self).interfaces;
    }

    /// `interfaceName` is expected to be fully qualified.
    pub fn doesImplement(self: *const Self, interfaceName: *const String) bool {
        const classInfo = getRuntimeClassInfo(self);
        for (classInfo.interfaces) |iface| {
            if (iface.fullyQualifiedInterfaceName.eql(interfaceName.*)) {
                return true;
            }
        }
        return false;
    }

    /// `interfaceName` is expected to be fully qualified.
    pub fn interfaceRef(self: *const Self, interfaceName: *const String) *const InterfaceRef {
        const offset = self.findInterfaceOffset(interfaceName);
        if (offset) |byteOffset| {
            return @ptrFromInt(self.inner + @as(usize, byteOffset));
        } else {
            @panic("Class does not implement interface");
        }
    }

    /// `interfaceName` is expected to be fully qualified.
    pub fn interfaceRefMut(self: *Self, interfaceName: *const String) *InterfaceRef {
        const offset = self.findInterfaceOffset(interfaceName);
        if (offset) |byteOffset| {
            return @ptrFromInt(self.inner + @as(usize, byteOffset));
        } else {
            @panic("Class does not implement interface");
        }
    }

    /// Invalidates `self`, converting this into an owned interface, which takes ownership
    /// of the class data.
    /// `interfaceName` is expected to be fully qualified.
    pub fn toOwnedInterface(self: *Self, interfaceName: *const String) OwnedInterface {
        const iface = self.interfaceRefMut(interfaceName);
        const takeOwnership = @import("interface.zig").takeOwnership;
        const owned = takeOwnership(iface);
        self.inner = 0;
        return owned;
    }

    fn findInterfaceOffset(self: *const Self, interfaceName: *const String) ?u32 {
        const classInfo = getRuntimeClassInfo(self);
        for (classInfo.interfaces, 0..) |iface, i| {
            if (iface.fullyQualifiedInterfaceName.eql(interfaceName.*)) {
                return @intCast(i);
            }
        }
        return null;
    }
};

pub fn getRuntimeClassInfo(class: *const Class) *const RuntimeClassInfo {
    const elements: [*]const usize = @ptrFromInt(class.inner);
    return @ptrFromInt(elements[0]);
}

pub const ClassMemberInfo = extern struct {
    name: String,
    dataType: ValueTag,
};

pub const ClassInterfaceImplInfo = extern struct {
    fullyQualifiedInterfaceName: String,
    /// Specifies the offset in bytes required to get to the class's implementation of the interface.
    offset: usize,
};

pub const RuntimeClassInfo = struct {
    className: String,
    fullyQualifiedName: String,
    /// Number of bytes this class uses
    size: usize,
    members: []ClassMemberInfo,
    interfaces: []ClassInterfaceImplInfo,
    // TODO onDeinit
};
