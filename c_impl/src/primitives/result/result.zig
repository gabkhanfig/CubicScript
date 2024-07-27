const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const script_value = @import("../script_value.zig");
const ValueTag = script_value.ValueTag;
const RawValue = script_value.RawValue;
const CTaggedValue = script_value.CTaggedValue;
const TaggedValue = script_value.TaggedValue;
const String = script_value.String;
const TypeContext = script_value.TypeContext;
const Error = script_value.Error;
const CubsError = script_value.c.CubsError;
const Map = script_value.Map;

/// `OkT` is the type of the ok variant. It mustn't be an error type. It may be `void` to represent
/// an empty ok.
/// `ErrMetadataT` is the metadata type held by the `Error`. Can be `void` to represent an error with only
/// a name and no metadata.
pub fn Result(comptime OkT: type, comptime ErrMetadataT: type) type {
    return extern struct {
        const Self = @This();
        pub const SCRIPT_SELF_TAG: ValueTag = .result;
        pub const ValueType = OkT;
        pub const ErrorMetadataType = ErrMetadataT;

        comptime {
            if (OkT != void and OkT != bool and OkT != i64 and OkT != f64) {
                if (@hasDecl(OkT, "SCRIPT_SELF_TAG")) {
                    if (OkT.SCRIPT_SELF_TAG == .err) {
                        @compileError("Result Ok type may not be an error type");
                    }
                }
            }
            if (ErrMetadataT != void and ErrMetadataT != bool and ErrMetadataT != i64 and ErrMetadataT != f64) {
                if (@hasDecl(ErrMetadataT, "SCRIPT_SELF_TAG")) {
                    if (ErrMetadataT.SCRIPT_SELF_TAG == .err) {
                        @compileError("Result Error Metadata type may not be an error type");
                    }
                }
            }
        }

        metadata: [@sizeOf(CubsError) / @sizeOf(*anyopaque)]?*anyopaque,
        isErr: bool,
        /// Context of the ok value. If `NULL`, is an empty ok value.
        context: ?*const TypeContext,

        pub fn initOk(inOk: OkT) Self {
            if (OkT == void) {
                return @bitCast(CubsResult.cubs_result_init_ok_user_class(null, null));
            } else {
                var mutValue = inOk;
                const context = TypeContext.auto(OkT);
                return @bitCast(CubsResult.cubs_result_init_ok_user_class(@ptrCast(&mutValue), context));
            }
        }

        pub fn initErr(inErr: Error(ErrMetadataT)) Self {
            if (OkT == void) {
                return @bitCast(CubsResult.cubs_result_init_err_user_class(@bitCast(inErr), null));
            } else {
                const context = TypeContext.auto(OkT);
                return @bitCast(CubsResult.cubs_result_init_err_user_class(@bitCast(inErr), context));
            }
        }

        pub fn deinit(self: *Self) void {
            CubsResult.cubs_result_deinit(self.asRawMut());
        }

        pub fn getOk(self: *const Self) *const OkT {
            return @ptrCast(@alignCast(CubsResult.cubs_result_get_ok(self.asRaw())));
        }

        pub fn getOkMut(self: *Self) *OkT {
            return @ptrCast(@alignCast(CubsResult.cubs_result_get_ok_mut(self.asRawMut())));
        }

        pub fn takeOk(self: *Self) OkT {
            var out: OkT = undefined;
            CubsResult.cubs_result_take_ok(@ptrCast(&out), self.asRawMut());
            return out;
        }

        pub fn getErr(self: *const Self) *const Error(ErrMetadataT) {
            return @ptrCast(@alignCast(CubsResult.cubs_result_get_err(self.asRaw())));
        }

        pub fn getErrMut(self: *Self) *Error(ErrMetadataT) {
            return @ptrCast(@alignCast(CubsResult.cubs_result_get_err_mut(self.asRawMut())));
        }

        pub fn takeErr(self: *Self) Error(ErrMetadataT) {
            return @bitCast(CubsResult.cubs_result_take_err(self.asRawMut()));
        }

        pub fn asRaw(self: *const Self) *const CubsResult {
            return @ptrCast(self);
        }

        pub fn asRawMut(self: *Self) *CubsResult {
            return @ptrCast(self);
        }
    };
}

pub const CubsResult = extern struct {
    metadata: [@sizeOf(CubsError) / @sizeOf(*anyopaque)]?*anyopaque,
    isErr: bool,
    /// Context of the ok value. If `NULL`, is an empty ok value.
    context: ?*const TypeContext,

    const Self = @This();
    pub const SCRIPT_SELF_TAG: ValueTag = .result;

    pub extern fn cubs_result_init_ok_primitive(okValue: ?*anyopaque, okTag: ValueTag) callconv(.C) Self;
    pub extern fn cubs_result_init_ok_user_class(okValue: ?*anyopaque, okContext: ?*const TypeContext) callconv(.C) Self;
    pub extern fn cubs_result_init_err_primitive(err: CubsError, okTag: ValueTag) callconv(.C) Self;
    pub extern fn cubs_result_init_err_user_class(err: CubsError, okContext: ?*const TypeContext) callconv(.C) Self;
    pub extern fn cubs_result_deinit(self: *Self) callconv(.C) void;
    pub extern fn cubs_result_get_ok(self: *const Self) callconv(.C) *const anyopaque;
    pub extern fn cubs_result_get_ok_mut(self: *Self) callconv(.C) *anyopaque;
    pub extern fn cubs_result_take_ok(outOk: *anyopaque, self: *Self) callconv(.C) void;
    pub extern fn cubs_result_get_err(self: *const Self) callconv(.C) *const CubsError;
    pub extern fn cubs_result_get_err_mut(self: *Self) callconv(.C) *CubsError;
    pub extern fn cubs_result_take_err(self: *Self) callconv(.C) CubsError;
};

test "initOk" {
    {
        var res = Result(void, void).initOk({});
        defer res.deinit();

        try expect(!res.isErr);
    }
    {
        var res = Result(i64, void).initOk(5);
        defer res.deinit();

        try expect(!res.isErr);
    }
    {
        var res = Result(String, void).initOk(String.initUnchecked("hello to this absolutely amazing world!"));
        defer res.deinit();

        try expect(!res.isErr);
    }
    {
        var res = Result(Map(i64, i64), void).initOk(Map(i64, i64){});
        defer res.deinit();

        try expect(!res.isErr);
    }
}

test "initErr" {
    {
        var res = Result(void, void).initErr(Error(void).init(String.initUnchecked("wuh"), {}));
        defer res.deinit();

        try expect(res.isErr);
    }
    {
        var res = Result(void, i64).initErr(Error(i64).init(String.initUnchecked("wuh"), 10));
        defer res.deinit();

        try expect(res.isErr);
    }
    {
        var res = Result(i64, i64).initErr(Error(i64).init(String.initUnchecked("wuh"), 10));
        defer res.deinit();

        try expect(res.isErr);
    }
    {
        var res = Result(void, String).initErr(Error(String).init(
            String.initUnchecked("wuh"),
            String.initUnchecked("extra"),
        ));
        defer res.deinit();

        try expect(res.isErr);
    }
}

test "getOk" {
    {
        var res = Result(i64, void).initOk(10);
        defer res.deinit();

        try expect(res.getOk().* == 10);
    }
    {
        var res = Result(String, void).initOk(String.initUnchecked("wuh"));
        defer res.deinit();

        try expect(res.getOk().eqlSlice("wuh"));
    }
    {
        var res = Result(Map(i64, i64), void).initOk(Map(i64, i64){});
        defer res.deinit();

        try expect(res.getOk().len == 0);
    }
}

test "getErr" {
    {
        var res = Result(void, void).initErr(Error(void).init(String.initUnchecked("exampleError"), {}));
        defer res.deinit();

        try expect(res.getErr().name.eqlSlice("exampleError"));
    }
    {
        var res = Result(void, i64).initErr(Error(i64).init(String.initUnchecked("exampleError"), 10));
        defer res.deinit();

        try expect(res.getErr().name.eqlSlice("exampleError"));
        try expect(res.getErr().metadata.?.* == 10);
    }
}

test "getOkMut" {
    {
        var res = Result(i64, void).initOk(10);
        defer res.deinit();

        res.getOkMut().* = 5;

        try expect(res.getOk().* == 5);
    }
    {
        var res = Result(String, void).initOk(String.initUnchecked("wuh"));
        defer res.deinit();

        res.getOkMut().deinit();
        res.getOkMut().* = String.initUnchecked("euh");

        try expect(res.getOk().eqlSlice("euh"));
    }
    {
        var res = Result(Map(i64, i64), void).initOk(Map(i64, i64){});
        defer res.deinit();

        res.getOkMut().insert(1, 1);

        try expect(res.getOk().len == 1);
        try expect(res.getOk().find(&@as(i64, 1)).?.* == 1);
    }
}

test "getErrMut" {
    {
        var res = Result(void, void).initErr(Error(void).init(String.initUnchecked("exampleError"), {}));
        defer res.deinit();

        res.getErrMut().name.deinit();
        res.getErrMut().name = String.initUnchecked("otherError");

        try expect(res.getErr().name.eqlSlice("otherError"));
    }
    {
        var res = Result(void, i64).initErr(Error(i64).init(String.initUnchecked("exampleError"), 10));
        defer res.deinit();

        res.getErrMut().name.deinit();
        res.getErrMut().name = String.initUnchecked("otherError");
        res.getErrMut().metadata.?.* = 5;

        try expect(res.getErr().name.eqlSlice("otherError"));
        try expect(res.getErr().metadata.?.* == 5);
    }
}

test "takeOk" {
    { // with deinit
        var res = Result(i64, void).initOk(10);
        defer res.deinit();

        const num = res.takeOk();

        try expect(num == 10);
    }
    { // without deinit
        var res = Result(i64, void).initOk(10);

        const num = res.takeOk();

        try expect(num == 10);
    }

    { // with deinit
        var res = Result(String, void).initOk(String.initUnchecked("wuh"));
        defer res.deinit();

        var str = res.takeOk();
        defer str.deinit();

        try expect(str.eqlSlice("wuh"));
    }
    { // without deinit
        var res = Result(String, void).initOk(String.initUnchecked("wuh"));

        var str = res.takeOk();
        defer str.deinit();

        try expect(str.eqlSlice("wuh"));
    }
    { // with deinit
        var res = Result(Map(i64, i64), void).initOk(Map(i64, i64){});
        defer res.deinit();

        var map = res.takeOk();
        defer map.deinit();

        try expect(map.len == 0);
    }
    { // without deinit
        var res = Result(Map(i64, i64), void).initOk(Map(i64, i64){});

        var map = res.takeOk();
        defer map.deinit();

        try expect(map.len == 0);
    }
}

test "takeErr" {
    { // with deinit
        var res = Result(void, void).initErr(Error(void).init(String.initUnchecked("exampleError"), {}));
        defer res.deinit();

        var err = res.takeErr();
        defer err.deinit();

        try expect(err.name.eqlSlice("exampleError"));
    }
    { // without deinit
        var res = Result(void, void).initErr(Error(void).init(String.initUnchecked("exampleError"), {}));

        var err = res.takeErr();
        defer err.deinit();

        try expect(err.name.eqlSlice("exampleError"));
    }
    { // with deinit
        var res = Result(void, i64).initErr(Error(i64).init(String.initUnchecked("exampleError"), 10));
        defer res.deinit();

        var err = res.takeErr();
        defer err.deinit();

        try expect(err.name.eqlSlice("exampleError"));
        try expect(err.metadata.?.* == 10);
    }
    { // without deinit
        var res = Result(void, i64).initErr(Error(i64).init(String.initUnchecked("exampleError"), 10));

        var err = res.takeErr();
        defer err.deinit();

        try expect(err.name.eqlSlice("exampleError"));
        try expect(err.metadata.?.* == 10);
    }
}
