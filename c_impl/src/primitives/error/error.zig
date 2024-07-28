const std = @import("std");
const expect = std.testing.expect;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;
const TypeContext = script_value.TypeContext;

pub fn Error(comptime T: type) type {
    return extern struct {
        const Self = @This();
        pub const ValueType = T;

        const ContextType = if (T == void) ?*anyopaque else *const TypeContext;

        name: String,
        metadata: ?*T,
        context: ContextType,

        pub fn init(name: String, metadata: T) Self {
            if (T == void) {
                return Self{ .name = name, .metadata = null, .context = null };
            } else {
                var mutMetadata = metadata;
                const context: ?*const TypeContext = if (T == void) null else TypeContext.auto(T);
                return @bitCast(CubsError.cubs_error_init(name, @ptrCast(&mutMetadata), context));
            }
        }

        pub fn deinit(self: *Self) void {
            CubsError.cubs_error_deinit(self.asRawMut());
        }

        pub fn clone(self: *const Self) Self {
            return @bitCast(CubsError.cubs_error_clone(self.asRaw()));
        }

        /// Cannot call this function twice, as it invalidates the error's metadata
        pub fn takeMetadata(self: *Self) T {
            if (T == void) {
                @compileError("Cannot take void metadata");
            }
            var temp: T = undefined;
            CubsError.cubs_error_take_metadata(@ptrCast(&temp), self.asRawMut());
            return temp;
        }

        /// `other` is passed by reference, not owned
        pub fn eql(self: *const Self, other: Self) bool {
            return CubsError.cubs_error_eql(self.asRaw(), other.asRaw());
        }

        pub fn hash(self: *const Self) usize {
            return CubsError.cubs_error_hash(self.asRaw());
        }

        pub fn asRaw(self: *const Self) *const CubsError {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsError {
            return @ptrCast(self);
        }
    };
}

pub const CubsError = extern struct {
    name: String,
    metadata: ?*anyopaque,
    context: ?*const TypeContext,

    const Self = @This();

    pub extern fn cubs_error_init(name: String, optionalMetadata: ?*anyopaque, optionalContext: ?*const TypeContext) callconv(.C) Self;
    pub extern fn cubs_error_deinit(self: *Self) callconv(.C) void;
    pub extern fn cubs_error_clone(self: *const Self) callconv(.C) Self;
    pub extern fn cubs_error_take_metadata(out: *anyopaque, self: *Self) callconv(.C) void;
    pub extern fn cubs_error_eql(self: *const Self, other: *const Self) callconv(.C) bool;
    pub extern fn cubs_error_hash(self: *const Self) callconv(.C) usize;
};

test "init" {
    {
        var err = Error(void).init(String.initUnchecked("exampleErr"), {});
        defer err.deinit();

        try expect(err.name.eqlSlice("exampleErr"));
    }
    {
        var err = Error(i64).init(String.initUnchecked("exampleErr"), 10);
        defer err.deinit();

        try expect(err.name.eqlSlice("exampleErr"));
        try expect(err.metadata.?.* == 10);
    }
    {
        var err = Error(String).init(String.initUnchecked("exampleErr"), String.initUnchecked("wuh"));
        defer err.deinit();

        try expect(err.name.eqlSlice("exampleErr"));
        try expect(err.metadata.?.eqlSlice("wuh"));
    }
}

test "clone" {
    {
        var err = Error(void).init(String.initUnchecked("exampleErr"), {});
        defer err.deinit();

        var clone = err.clone();
        defer clone.deinit();

        try expect(clone.name.eqlSlice("exampleErr"));
        try expect(clone.metadata == null);
        try expect(clone.context == null);
    }
    {
        var err = Error(i64).init(String.initUnchecked("exampleErr"), 10);
        defer err.deinit();

        var clone = err.clone();
        defer clone.deinit();

        try expect(clone.name.eqlSlice("exampleErr"));
        try expect(clone.metadata.?.* == 10);
    }
    {
        var err = Error(String).init(String.initUnchecked("exampleErr"), String.initUnchecked("wuh"));
        defer err.deinit();

        var clone = err.clone();
        defer clone.deinit();

        try expect(clone.name.eqlSlice("exampleErr"));
        try expect(clone.metadata.?.eqlSlice("wuh"));
    }
}

test "takeMetadata" {
    {
        var err = Error(i64).init(String.initUnchecked("exampleErr"), 10);
        defer err.deinit();

        const metadata = err.takeMetadata();
        try expect(metadata == 10);
    }
    {
        var err = Error(String).init(String.initUnchecked("exampleErr"), String.initUnchecked("wuh"));
        defer err.deinit();

        var metadata = err.takeMetadata();
        defer metadata.deinit();

        try expect(metadata.eqlSlice("wuh"));
    }
}
