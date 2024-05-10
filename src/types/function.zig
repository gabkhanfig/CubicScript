const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const ValueTag = root.ValueTag;
const String = root.String;
const TaggedValue = root.TaggedValue;
const allocator = @import("../state/global_allocator.zig").allocator;
const FunctionDefinition = @import("../compiler/FunctionBuilder.zig").FunctionDefinition;

pub const FunctionPtr = extern struct {
    const PTR_BITMASK = 0xFFFFFFFFFFFF;
    const TAG_BITMASK: usize = ~@as(usize, PTR_BITMASK);

    const Self = @This();

    inner: usize,

    pub fn initC(func: *const CFunction) Self {
        return Self{ .inner = @as(usize, @intFromEnum(FunctionType.C)) | @intFromPtr(func) };
    }

    /// Takes ownership of the values in `args`, NOT the slice itself.
    /// So does not try to `free` the slice. The `args` after calling this
    /// function will all be zeroed, setting the tag to `.None` and the value
    /// to 0.
    pub fn callRaw(self: *const Self, args: []TaggedValue) TaggedValue {
        switch (self.funcType()) {
            .Script => {
                const scriptFunc = self.scriptFunction();
                _ = scriptFunc;
                @panic("not yet implemented");
            },
            .C => {
                const cFunc = self.cFunction();
                return cFunc(ScriptFunctionArgs{ .args = args.ptr, .len = args.len });
            },
        }
    }

    fn funcType(self: *const Self) FunctionType {
        return @enumFromInt(self.inner & TAG_BITMASK);
    }

    fn scriptFunction(self: *const Self) *const FunctionDefinition {
        assert(self.funcType() == .Script);
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    fn cFunction(self: *const Self) *const CFunction {
        assert(self.funcType() == .C);
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    /// Gets a reference to a `ScriptFunctionArgs`, so calling `deinit()` on the instance
    /// is unnecessary.
    pub const CFunction = fn (ScriptFunctionArgs) callconv(.C) TaggedValue;
};

pub const ScriptFunctionArgs = extern struct {
    const Self = @This();

    /// If `len` is 0, the memory this points to is invalid.
    /// Otherwise, it is valid memory up to `len - 1`.
    args: [*]TaggedValue,
    /// If `len` is 0, there are no arguments, and reading `arg` is invalid.
    len: usize,

    // pub fn deinit(self: *Self) void {
    //     if (self.argCount == 0) {
    //         return;
    //     }

    //     const slice = self.args[0..self.argCount];
    //     for (slice) |*arg| {
    //         arg.deinit();
    //     }
    //     allocator().free(slice);
    //     self.args = undefined;
    //     self.argCount = 0;
    // }

    /// Take ownership of a specific argument, invalidating the old location.
    /// Not all args have to be taken.
    pub fn takeArg(self: *Self, arg: usize) void {
        assert(arg < self.len);
        const temp = self.args[arg];
        self.args[arg] = std.mem.zeroes(TaggedValue); // Sets the tag to none, and value to 0
        return temp;
    }
};

/// Asserts that it's just for script functions.
pub fn callScriptFuncPtrWithoutArgs(fptr: *const FunctionPtr) void {
    assert(fptr.funcType() == .Script);
}

pub fn isFuncPtrCFunc(fptr: *const FunctionPtr) bool {
    return fptr.funcType() == .C;
}

const FunctionType = enum(usize) {
    Script = 0,
    C = 1 << 48,
};

test "function pointer call C" {
    const Example = struct {
        fn func(args: ScriptFunctionArgs) callconv(.C) TaggedValue {
            assert(args.len == 2);
            assert(args.args[0].tag == .Int);
            assert(args.args[1].tag == .Int);

            return TaggedValue.initInt(args.args[0].value.int + args.args[1].value.int);
        }
    };

    const fptr = FunctionPtr.initC(&Example.func);

    var args = [_]TaggedValue{
        TaggedValue.initInt(1),
        TaggedValue.initInt(1),
    };

    const result = fptr.callRaw(&args);
    try expect(result.tag == .Int);
    try expect(result.value.int == 2);
}
