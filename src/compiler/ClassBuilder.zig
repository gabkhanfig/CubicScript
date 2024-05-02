//! `ClassBuilder` is a utility that allows

const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const String = root.String;
const allocator = @import("../state/global_allocator.zig").allocator;
const Class = @import("../types/class.zig").Class;
const ClassMemberInfo = @import("../types/class.zig").ClassMemberInfo;
const RuntimeClassInfo = @import("../types/class.zig").RuntimeClassInfo;
const InterfaceRef = @import("../types/interface.zig").InterfaceRef;
const OwnedInterface = @import("../types/interface.zig").OwnedInterface;

// TODO default class values, rather than 0 initialized.

const Self = @This();

name: String,
fullyQualifiedName: String,
classSpecificMembers: ArrayListUnmanaged(ClassMemberInfo) = .{},
classConstruct: ?ClassConstructionInfo = null,

pub fn deinit(self: *Self) void {
    self.name.deinit();
    self.fullyQualifiedName.deinit();
    if (self.classConstruct) |classConstruct| {
        classConstruct.rtti.className.deinit();
        classConstruct.rtti.fullyQualifiedName.deinit();
        // classConstruct.rtti.interfaces
        for (classConstruct.rtti.members) |*member| {
            member.name.deinit();
        }
        allocator().free(classConstruct.rtti.members);
        allocator().free(classConstruct.classBaseMem);
        allocator().destroy(classConstruct.rtti);
    } else {
        self.classSpecificMembers.deinit(allocator());
    }
}

/// Takes ownership of `member`.
pub fn addMember(self: *Self, member: ClassMemberInfo) void {
    assert(self.classConstruct == null);
    self.classSpecificMembers.append(allocator(), member) catch {
        @panic("Script out of memory");
    };
}

/// Constructs the memory layout, default values,
pub fn build(self: *Self) void {
    assert(self.classConstruct == null);

    const rtti = allocator().create(RuntimeClassInfo) catch {
        @panic("Script out of memory");
    };
    const classMemberInfo = allocator().alloc(ClassMemberInfo, self.classSpecificMembers.items.len) catch {
        @panic("Script out of memory");
    };
    @memcpy(classMemberInfo, self.classSpecificMembers.items);
    // Add one for RTTI. TODO interfaces
    const classBaseMem = allocator().alloc(usize, self.classSpecificMembers.items.len + 1) catch {
        @panic("Script out of memory");
    };
    @memset(classBaseMem, 0);

    // TODO some default values

    classBaseMem[0] = @intFromPtr(rtti);
    rtti.* = RuntimeClassInfo{
        .className = self.name.clone(),
        .fullyQualifiedName = self.fullyQualifiedName.clone(),
        .size = @sizeOf(usize) * (self.classSpecificMembers.items.len + 1),
        .interfaces = undefined,
        .members = classMemberInfo,
    };
    // Calling deinit on the strings held in `self.classSpecificMembers` is unnecessary because they have been moved to a different allocation
    self.classSpecificMembers.deinit(allocator());
    self.classConstruct = .{
        .rtti = rtti,
        .classBaseMem = classBaseMem,
    };
}

pub fn new(self: Self) Class {
    const classAllocation = allocator().alloc(usize, self.classConstruct.?.classBaseMem.len) catch {
        @panic("Script out of memory");
    };
    @memcpy(classAllocation, self.classConstruct.?.classBaseMem);
    // TODO execute any initialization logic
    return Class{ .inner = @intFromPtr(classAllocation.ptr) };
}

const ClassConstructionInfo = struct {
    rtti: *RuntimeClassInfo,
    /// Rather than initialize through iteration, memcpy the predefined base
    /// memory of the class. Naturally, this doesn't account for any initialization logic.
    classBaseMem: []usize,
};

test "class with no member variables or member functions" {
    { // dont build
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit(); // deinit should work if the builder doesnt build regardless
    }
    { // build but dont create class
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        builder.build();
    }
    { // create class
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        builder.build();

        var c = builder.new();
        defer c.deinit();

        try expect(c.className().eqlSlice("test"));
        try expect(c.fullyQualifiedClassName().eqlSlice("example.test"));
        try expect(c.membersInfo().len == 0);
    }
}
