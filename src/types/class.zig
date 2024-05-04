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
        for (self.membersInfo()) |info| {
            self.uncheckedValueAtMut(info.index).deinit(info.dataType);
        }
        const allocationSize = getRuntimeClassInfo(self).size / 8;
        const ptr: [*]usize = @ptrFromInt(self.inner);
        allocator().free(ptr[0..allocationSize]);
    }

    /// Get the index of a given class member. The index is consistent
    /// for all instances of this class.
    pub fn memberIndex(self: *const Self, memberName: *const String) ?u16 {
        return getRuntimeClassInfo(self).memberMapping.get(memberName.*);
    }

    /// Combines `memberIndex()` and `uncheckedValueAt()` to safely get an immutable reference to a class member.
    /// If this class doesn't contain `memberName`, safety checked undefined behaviour is invoked.
    pub fn value(self: *const Self, memberName: *const String) *const RawValue {
        if (self.memberIndex(memberName)) |index| {
            return self.uncheckedValueAt(index);
        } else {
            unreachable;
        }
    }

    /// Combines `memberIndex()` and `uncheckedValueAtMut()` to safely get a mutable reference to a class member.
    /// If this class doesn't contain `memberName`, safety checked undefined behaviour is invoked.
    pub fn valueMut(self: *Self, memberName: *const String) *const RawValue {
        if (self.memberIndex(memberName)) |index| {
            return self.uncheckedValueAtMut(index);
        } else {
            unreachable;
        }
    }

    /// Get the type of script value of the class at a specific member index.
    /// Combines with `valueAt()` or `mutValueAt()` to determine the active union member.
    /// If this class doesn't contain `memberName`, safety checked undefined behaviour is invoked.
    pub fn valueTag(self: *const Self, memberName: *const String) ValueTag {
        if (self.memberIndex(memberName)) |index| {
            const runtimeInfo = getRuntimeClassInfo(self);
            return runtimeInfo.members[index].dataType;
        } else {
            unreachable;
        }
    }

    /// Directly gets the value at a given index.
    /// Does not check if `index` is valid memory.
    pub fn uncheckedValueAt(self: *const Self, index: u16) *const RawValue {
        const members: [*]const RawValue = @ptrFromInt(self.inner);
        return &members[index];
    }

    /// Directly gets the value at a given index.
    /// Does not check if `index` is valid memory.
    pub fn uncheckedValueAtMut(self: *Self, index: u16) *RawValue {
        const members: [*]RawValue = @ptrFromInt(self.inner);
        return &members[index];
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
    index: u16,
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
    memberMapping: MemberHashMap,
    interfaces: []ClassInterfaceImplInfo,
    // TODO onDeinit

    pub const MemberHashMap = std.HashMapUnmanaged(String, u16, MemberHashContext, 80);

    const MemberHashContext = struct {
        pub fn hash(self: @This(), s: String) u64 {
            _ = self;
            return @as(usize, s.hash());
        }

        pub fn eql(self: @This(), a: String, b: String) bool {
            _ = self;
            return a.eql(b);
        }
    };
};
