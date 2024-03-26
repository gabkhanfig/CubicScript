const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const TaggedValue = root.TaggedValue;
const CubicScriptState = @import("../state/CubicScriptState.zig");

pub const Option = extern struct {
    const Self = @This();

    /// Has ownership of the tagged value, allocated somewhere.
    value: ?*TaggedValue,

    pub fn init(inValue: ?TaggedValue, state: *const CubicScriptState) Allocator.Error!Self {
        if (inValue == null) {
            return Self{ .value = null };
        }
        const value = try state.allocator.create(TaggedValue);
        value.* = inValue.?;
        return Self{ .value = value };
    }

    pub fn deinit(self: *Self, state: *const CubicScriptState) void {
        if (self.value == null) {
            return;
        }

        self.value.?.deinit(state);
        state.allocator.destroy(self.value.?);
        self.value = null;
    }

    pub fn take(self: *Self, state: *const CubicScriptState) Error!TaggedValue {
        if (self.value) |value| {
            const temp = value.*; // take ownership
            state.allocator.destroy(value);
            self.value = null;
            return temp;
        } else {
            return Error.IsNull;
        }
    }

    pub const Error = error{
        IsNull,
    };
};

test "null" {
    var state = try CubicScriptState.init(std.testing.allocator, null);
    defer state.deinit();

    var opt = Option{ .value = null };
    defer opt.deinit(state);

    if (opt.take(state)) |_| {
        try expect(false);
    } else |_| {}
}

test "not null" {
    var state = try CubicScriptState.init(std.testing.allocator, null);
    defer state.deinit();

    var opt = try Option.init(TaggedValue.initString(try root.String.initSlice("aa", state)), state);
    defer opt.deinit(state);

    try expect(opt.value != null);

    if (opt.take(state)) |string| {
        try expect(string.tag == root.ValueTag.String);
        try expect(string.value.string.eqlSlice("aa"));
        var s = string;
        s.value.string.deinit(state);
    } else |_| {
        try expect(false);
    }
}
