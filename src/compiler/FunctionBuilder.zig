const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const ValueTag = root.ValueTag;
const String = root.String;
const allocator = @import("../state/global_allocator.zig").allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Bytecode = @import("../state/Bytecode.zig");
const AllocatoError = std.mem.Allocator.Error;
//const CubicScriptState = @import("../state/CubicScriptState.zig");

// TODO should recursion be allowed?

const Self = @This();

name: String,
fullyQualifiedName: String,
_returnType: ValueTag = .None,
_argTypes: ArrayListUnmanaged(ValueTag) = .{},
_function: ?*FunctionDefinition = null,

pub fn deinit(self: *Self) void {
    self.name.deinit();
    self.fullyQualifiedName.deinit();
    if (self._function) |function| {
        allocator().free(function.defintion);
        if (function.declaration.argTypes) |argTypes| {
            allocator().free(argTypes[0..function.declaration.argCount]);
        }

        function.name.deinit();
        function.fullyQualifiedName.deinit();
        allocator().destroy(function);
    } else {
        self._argTypes.deinit(allocator());
    }
}

pub fn setReturnType(self: *Self, retType: ValueTag) void {
    self._returnType = retType;
}

pub fn addArg(self: *Self, name: *const String, argType: ValueTag) AllocatoError!void {
    _ = name;
    try self._argTypes.append(allocator(), argType);
}

/// Takes ownership of `bytecode`. `stackSpaceRequired` includes function arguments.
/// Asserts that the final instruction in `bytecode` is a return instruction.
/// Asserts that `stackSpaceRequired` is greater than or equal to the number of function arguments.
pub fn build(self: *Self, bytecode: []Bytecode, stackSpaceRequired: u8) AllocatoError!void {
    assert(bytecode[bytecode.len - 1].getOpCode() == .Return);
    assert(stackSpaceRequired >= self._argTypes.items.len);

    const argTypes: ?[]ValueTag = blk: {
        if (self._argTypes.items.len == 0) {
            break :blk null;
        } else {
            const argMem = try allocator().alloc(ValueTag, self._argTypes.items.len);
            @memcpy(argMem, self._argTypes.items);
            break :blk argMem;
        }
    };
    const definition = try allocator().create(FunctionDefinition);
    definition.* = FunctionDefinition{
        .name = self.name.clone(),
        .fullyQualifiedName = self.fullyQualifiedName.clone(),
        .declaration = FunctionDeclaration{
            .returnType = self._returnType,
            .argCount = @intCast(self._argTypes.items.len),
            .argTypes = if (argTypes) |a| a.ptr else null,
        },
        .defintion = bytecode,
        .stackSpaceRequired = stackSpaceRequired,
    };

    self._function = definition;
    self._argTypes.deinit(allocator());
}

pub const FunctionDefinition = struct {
    name: String,
    fullyQualifiedName: String,
    declaration: FunctionDeclaration,
    /// The bytecode will ALWAYS end in a return instruction.
    defintion: []Bytecode,
    stackSpaceRequired: u8,
};

pub const FunctionDeclaration = extern struct {
    /// If is `.None` no value is returned. Equivalent to `void` return.
    returnType: ValueTag,
    /// Can be 0, meaning the function takes no arguments.
    argCount: u8,
    /// If is `null`, the function takes no arguments. Is an array with length `argCount`.
    argTypes: ?[*]ValueTag, // This can be compressed into an array of u8
    // TODO should argument names be stored?
};

test "function no return no args one instruction" {
    const inst = [_]Bytecode{Bytecode.encode(.Return, {})};
    {
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        builder.deinit();
    }
    {
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        const functionInstructions = try allocator().alloc(Bytecode, 1);
        @memcpy(functionInstructions, &inst);

        try builder.build(functionInstructions, 0);
    }
    {
        var builder = Self{ .name = String.initSliceUnchecked("test"), .fullyQualifiedName = String.initSliceUnchecked("example.test") };
        defer builder.deinit();

        const functionInstructions = try allocator().alloc(Bytecode, 1);
        @memcpy(functionInstructions, &inst);

        try builder.build(functionInstructions, 0);

        try expect(builder._function.?.name.eqlSlice("test"));
        try expect(builder._function.?.fullyQualifiedName.eqlSlice("example.test"));

        try expect(builder._function.?.defintion.len == 1);
        try expect(builder._function.?.defintion[0].getOpCode() == .Return);

        try expect(builder._function.?.declaration.returnType == .None);
        try expect(builder._function.?.declaration.argCount == 0);
        try expect(builder._function.?.declaration.argTypes == null);
    }
    // TODO call the function through a script state
}
