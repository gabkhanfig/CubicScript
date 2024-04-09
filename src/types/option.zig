const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const TaggedValue = root.TaggedValue;
const CubicScriptState = @import("../state/CubicScriptState.zig");
const allocator = @import("../state/global_allocator.zig").allocator;

pub const Option = extern struct {
    const Self = @This();

    /// Has ownership of the tagged value, allocated somewhere.
    value: ?*TaggedValue,

    pub fn init(inValue: ?TaggedValue) Self {
        if (inValue == null) {
            return Self{ .value = null };
        }
        const value = allocator().create(TaggedValue) catch {
            @panic("Script out of memory");
        };
        value.* = inValue.?;
        return Self{ .value = value };
    }

    pub fn deinit(self: *Self) void {
        if (self.value == null) {
            return;
        }

        self.value.?.deinit();
        allocator().destroy(self.value.?);
        self.value = null;
    }

    pub fn take(self: *Self) Error!TaggedValue {
        if (self.value) |value| {
            const temp = value.*; // take ownership
            allocator().destroy(value);
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
    var opt = Option{ .value = null };
    defer opt.deinit();

    if (opt.take()) |_| {
        try expect(false);
    } else |_| {}
}

test "not null" {
    var opt = Option.init(TaggedValue.initString(root.String.initSlice("aa")));
    defer opt.deinit();

    try expect(opt.value != null);

    if (opt.take()) |string| {
        try expect(string.tag == root.ValueTag.String);
        try expect(string.value.string.eqlSlice("aa"));
        var s = string;
        s.value.string.deinit();
    } else |_| {
        try expect(false);
    }
}
