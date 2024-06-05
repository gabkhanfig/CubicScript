const std = @import("std");
const expect = std.testing.expect;

const c = struct {
    extern fn cubs_program_init(params: Program.InitParams) callconv(.C) Program;
    extern fn cubs_program_deinit(self: *Program) callconv(.C) void;

    extern fn _cubs_internal_program_runtime_error(self: *const Program, err: Program.RuntimeError, message: [*c]const u8, messageLength: usize) callconv(.C) void;
    extern fn _cubs_internal_program_print(self: *const Program, message: [*c]const u8, messageLength: usize) callconv(.C) void;
};

pub const Program = extern struct {
    const Self = @This();

    _inner: *anyopaque,

    pub fn init(params: InitParams) Self {
        return c.cubs_program_init(params);
    }

    pub fn deinit(self: *Self) void {
        c.cubs_program_deinit(self);
    }

    pub const Context = extern struct {
        ptr: ?*anyopaque,
        vtable: *const VTable,

        pub const VTable = extern struct {
            errorCallback: *const fn (self: *anyopaque, program: *const Program, stackTrace: *anyopaque, err: RuntimeError, message: [*c]const u8, messageLength: usize) callconv(.C) void,
            print: *const fn (self: *anyopaque, program: *const Program, message: [*c]const u8, messageLength: usize) callconv(.C) void,
            deinit: *const fn (self: *anyopaque) callconv(.C) void,
        };
    };

    pub const InitParams = extern struct {
        context: ?*Context = null,
    };

    pub const RuntimeError = enum(c_int) {
        None = 0,
        NullDereference = 1,
        AdditionIntegerOverflow = 2,
        SubtractionIntegerOverflow = 3,
        MultiplicationIntegerOverflow = 4,
        DivisionIntegerOverflow = 5,
        DivideByZero = 6,
        ModuloByZero = 7,
        RemainderByZero = 8,
        PowerIntegerOverflow = 9,
        ZeroToPowerOfNegative = 10,
        InvalidBitShiftAmount = 11,
        FloatToIntOverflow = 12,
        NegativeRoot = 13,
        LogarithmZeroOrNegative = 14,
        ArcsinUndefined = 15,
        ArccosUndefined = 16,
        HyperbolicArccosUndefined = 17,
        HyperbolicArctanUndefined = 18,
    };

    test init {
        { // default context
            var program = Self.init(.{});
            defer program.deinit();
        }
        { // custom context
            const CustomContext = struct {
                unused: *usize,

                pub fn init(num: *usize) *@This() {
                    const self = std.testing.allocator.create(@This()) catch unreachable;
                    self.unused = num;
                    return self;
                }

                pub fn deinit(self: *@This()) callconv(.C) void {
                    std.testing.allocator.destroy(self);
                }

                pub fn errorCallback(self: *@This(), _: *const Program, _: *anyopaque, _: RuntimeError, _: [*c]const u8, _: usize) callconv(.C) void {
                    // Validate its actually called
                    self.unused.* = 12345;
                }

                pub fn print(self: *@This(), _: *const Program, _: [*c]const u8, _: usize) callconv(.C) void {
                    // Validate its actually called
                    self.unused.* = 67890;
                }
            };

            var trackNum: usize = 0;

            var context = Program.Context{
                .ptr = @ptrCast(CustomContext.init(&trackNum)),
                .vtable = &.{
                    .errorCallback = @ptrCast(&CustomContext.errorCallback),
                    .print = @ptrCast(&CustomContext.print),
                    .deinit = @ptrCast(&CustomContext.deinit),
                },
            };

            var program = Program.init(.{ .context = &context });
            defer program.deinit();

            c._cubs_internal_program_runtime_error(&program, @enumFromInt(0), "".ptr, "".len);
            try expect(trackNum == 12345);

            c._cubs_internal_program_print(&program, "".ptr, "".len);
            try expect(trackNum == 67890);
        }
    }
};
