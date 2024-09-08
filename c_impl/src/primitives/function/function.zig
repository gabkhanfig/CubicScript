const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const script_value = @import("../script_value.zig");
const String = script_value.String;
const TypeContext = script_value.TypeContext;

pub const Function = extern struct {
    _inner: *const anyopaque,
    funcType: FunctionPtrType,

    pub const FunctionPtrType = enum(c_int) {
        C = 0,
        Script = 1,
    };
};
