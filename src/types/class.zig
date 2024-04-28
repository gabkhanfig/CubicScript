const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const String = root.String;
const allocator = @import("../state/global_allocator.zig").allocator;

pub const Class = extern struct {
    const PTR_BITMASK: usize = 0x0000FFFFFFFFFFFF;
    const MAX_CLASS_MEMBERS = std.math.maxInt(u16);

    const Self = @This();

    /// Points to a region of memory starting with a pointer to the runtime class info,
    /// followed by all of the class members.
    inner: usize,

    pub fn deinit(self: *Self) void {
        // TODO execute script deinit as well
        for (self.membersInfo(), 0..) |info, i| {
            self.valueAt(i).deinit(info.dataType);
        }
        const allocationSize = @sizeOf(*const RuntimeClassInfo) + (@sizeOf(RawValue) * self.membersInfo().len);
        const ptr: *u8 = @ptrFromInt(self.inner);
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
};

pub fn getRuntimeClassInfo(class: *const Class) *const RuntimeClassInfo {
    return @ptrFromInt(class.inner);
}

pub const RuntimeClassInfo = struct {
    className: String,
    fullyQualifiedName: String,
    members: []ClassMemberInfo,
    // TODO onDeinit, interfaces
};

pub const ClassMemberInfo = extern struct {
    name: String,
    dataType: ValueTag,
};
