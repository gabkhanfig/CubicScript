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
const AllocatoError = std.mem.Allocator.Error;
const CubicScriptState = @import("../state/CubicScriptState.zig");

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
        var it = classConstruct.rtti.memberMapping.keyIterator();
        while (it.next()) |k| {
            k.deinit();
        }
        classConstruct.rtti.memberMapping.deinit(allocator());

        allocator().destroy(classConstruct.rtti);
    } else {
        for (self.classSpecificMembers.items) |*member| {
            member.name.deinit();
        }
        self.classSpecificMembers.deinit(allocator());
    }
}

/// Takes ownership of `name`.
pub fn addMember(self: *Self, name: *const String, dataType: ValueTag) AllocatoError!void {
    assert(self.classConstruct == null);
    try self.classSpecificMembers.append(allocator(), ClassMemberInfo{
        .name = name.clone(),
        .dataType = dataType,
        .index = 0, // Temporary value
    });
}

/// Constructs the memory layout, default values,
pub fn build(self: *Self, state: *const CubicScriptState) AllocatoError!void {
    assert(self.classConstruct == null);

    const rtti = try allocator().create(RuntimeClassInfo);
    const classMemberInfo = try allocator().alloc(ClassMemberInfo, self.classSpecificMembers.items.len);
    @memcpy(classMemberInfo, self.classSpecificMembers.items);
    // Add one for RTTI. TODO interfaces
    const classBaseMem = try allocator().alloc(usize, self.classSpecificMembers.items.len + 1);
    @memset(classBaseMem, 0);

    var memberMapping = RuntimeClassInfo.MemberHashMap{};
    var memberIndex: u16 = 1;
    for (classMemberInfo) |*member| {
        member.index = memberIndex;
        try memberMapping.put(
            allocator(),
            member.name.clone(),
            member,
        );
        memberIndex += 1;
    }

    // TODO some default values

    classBaseMem[0] = @intFromPtr(rtti);
    rtti.* = RuntimeClassInfo{
        .state = state,
        .className = self.name.clone(),
        .fullyQualifiedName = self.fullyQualifiedName.clone(),
        .size = @sizeOf(usize) * (self.classSpecificMembers.items.len + 1),
        .interfaces = undefined,
        .members = classMemberInfo,
        .memberMapping = memberMapping,
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
    const state = CubicScriptState.init(null);
    defer state.deinit();
    { // dont build
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();
    }
    { // build but dont create class
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        try builder.build(state);
    }
    { // create class
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        try builder.build(state);

        var c = builder.new();
        defer c.deinit();

        try expect(c.className().eqlSlice("test"));
        try expect(c.fullyQualifiedClassName().eqlSlice("example.test"));
        try expect(c.membersInfo().len == 0);
    }
}

test "class with one member variable" {
    const state = CubicScriptState.init(null);
    defer state.deinit();
    { // dont build
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        var memberName = String.initSliceUnchecked("wuh");
        defer memberName.deinit();

        try builder.addMember(&memberName, .Int);
    }
    { // build but dont create class

        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        var memberName = String.initSliceUnchecked("wuh");
        defer memberName.deinit();

        try builder.addMember(&memberName, .Int);

        try builder.build(state);
    }
    { // create class
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        var memberName = String.initSliceUnchecked("wuh");
        defer memberName.deinit();

        try builder.addMember(&memberName, .Int);

        try builder.build(state);

        var c = builder.new();
        defer c.deinit();

        try expect(c.className().eqlSlice("test"));
        try expect(c.fullyQualifiedClassName().eqlSlice("example.test"));
        try expect(c.membersInfo().len == 1);
        try expect(c.membersInfo()[0].name.eql(memberName));
        try expect(c.memberIndex(&memberName).? == 1);
        try expect(c.memberTag(&memberName) == .Int);

        c.memberMut(&memberName).int = 10;
        try expect(c.member(&memberName).int == 10);
    }
}
