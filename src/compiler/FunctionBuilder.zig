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
        _ = function;
    } else {
        self._argTypes.deinit(allocator());
    }
}

/// Asserts that the final instruction in `bytecode` is a return instruction.
pub fn build(self: *Self, bytecode: []Bytecode) AllocatoError!void {
    assert(bytecode[bytecode.len - 1].getOpCode() == .Return);

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
            .argCount = argTypes.len,
            .argTypes = if (argTypes) |a| a.ptr else null,
        },
        .defintion = bytecode,
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
};

pub const FunctionDeclaration = extern struct {
    /// If is `.None` no value is returned. Equivalent to `void` return.
    returnType: ValueTag,
    /// Can be 0, meaning the function takes no arguments.
    argCount: u8,
    /// If is `null`, the function takes no arguments.
    argTypes: ?[*]ValueTag, // This can be compressed into an array of u8
    // TODO should argument names be stored?
};
