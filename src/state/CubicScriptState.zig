const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const TaggedValue = root.TaggedValue;
const Stack = @import("Stack.zig");
const StackFrame = Stack.StackFrame;
const Bytecode = @import("Bytecode.zig");
const OpCode = Bytecode.OpCode;
const String = root.String;
const math = @import("../types/math.zig");
const Error = @import("Errors.zig");
const allocPrintZ = std.fmt.allocPrintZ;
const runtime_safety: bool = std.debug.runtime_safety;
const Mutex = std.Thread.Mutex;
const allocator = @import("global_allocator.zig").allocator;

// TODO scripts using different allocators can risk passing around memory to different states.
// Therefore, all states should use the same global allocator. Perhaps there can be a function to change the allocator.

pub const RuntimeError = Error.RuntimeError;
pub const ErrorSeverity = Error.Severity;
// https://github.com/ziglang/zig/issues/16419
pub const RuntimeErrorCallback = *const fn (err: RuntimeError, severity: ErrorSeverity, message: []const u8) void;
pub const CRuntimeErrorCallback = *const fn (err: c_int, severity: c_int, message: ?[*c]const u8, messageLength: usize) void;

threadlocal var threadLocalStack: Stack = .{};

const Self = @This();

_context: ScriptContext,
_contextMutex: Mutex = .{},

/// Create a new state with an allocator and an optional error callback.
/// If a `null` error callback is provided, the default one will be used, which
/// with `std.debug.runtime_safety`, will log all messages. Without runtime safety,
/// no messages will be logged.
pub fn init(context: ?ScriptContext) *Self {
    const self = allocator().create(Self) catch {
        @panic("Script out of memory");
    };
    self.* = Self{
        ._context = if (context) |ctx| ctx else ScriptContext.default_context,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    self._context.deinit();
    allocator().destroy(self);
}

pub fn run(self: *const Self, instructions: []const Bytecode) FatalScriptError!TaggedValue {
    const previousState = threadLocalStack.state;
    defer threadLocalStack.state = previousState; // Allows nesting script run calls with different state instances
    // NOTE should also do errdefer for if allocation fails anywhere.
    threadLocalStack.state = self;

    //threadLocalStack.instructionPointer = 0; pushing a new frame sets the instructions pointer
    var captureReturn = TaggedValue{ .tag = .None, .value = RawValue{ .actualValue = 0 } };
    var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, &captureReturn.value) catch {
        @panic("Script stack overflow");
    };
    defer _ = frame.popFrame(&threadLocalStack);

    const instructionPointer: *usize = &threadLocalStack.instructionPointer;
    // The stack pointer points to the beginning of the stack frame.
    // This is done to use positive offsets to avoid any obscure exploits or issues from using
    // negative offsets and inadverently mutating the stack frame of the calling script function.

    while (instructionPointer.* < instructions.len) {
        const bytecode = instructions[instructionPointer.*];
        switch (bytecode.getOpCode()) {
            .Nop => {
                //std.debug.print("no operation\n", .{});
            },
            .Move => {
                const operands = bytecode.decode(Bytecode.OperandsMove);
                frame.register(operands.dst).* = frame.register(operands.src).*;
            },
            .LoadZero => {
                const operand = bytecode.decode(Bytecode.OperandsOnlyDst);
                frame.register(operand.dst).* = std.mem.zeroes(RawValue);
            },
            .LoadImmediate => {
                // NOTE the two bytecodes after `LoadImmediate` are the 64 bit immediate values, thus the instruction
                // pointer will need to be further incremented.
                const operand = bytecode.decode(Bytecode.OperandsOnlyDst);
                const immediate: usize =
                    @as(usize, @intCast(instructions[instructionPointer.* + 1].value)) |
                    @shlExact(@as(usize, @intCast(instructions[instructionPointer.* + 2].value)), 32);

                frame.register(operand.dst).actualValue = immediate;
                instructionPointer.* += 2;
            },
            .Return => {
                const operands = bytecode.decode(Bytecode.OperandsOptionalReturn);
                if (operands.valueTag != .None) {
                    frame.setReturnValue(operands.src);
                }
                if (frame.popFrame(&threadLocalStack)) |previousFrame| {
                    frame = previousFrame; // TODO allow runtime tracking of stack types, and use the valueTag to set them from return.
                } else {
                    captureReturn.tag = operands.valueTag;
                    return captureReturn;
                }
            },
            .Call => {
                const operands = bytecode.decode(Bytecode.OperandsFunctionArgs);
                const returnValueAddr: ?*RawValue = blk: {
                    if (operands.captureReturn) {
                        break :blk frame.register(operands.returnDst);
                    } else {
                        break :blk null;
                    }
                };

                {
                    const instructionPtrIncrement = blk: {
                        if (operands.argCount == 0) {
                            break :blk 0;
                        } else {
                            const out = (operands.argCount / @sizeOf(Bytecode.FunctionArg)) + 1;
                            break :blk out;
                        }
                    };
                    instructionPointer.* += instructionPtrIncrement;
                }

                const argsStart: [*]const Bytecode.FunctionArg = @ptrCast(&instructions[instructionPointer.* + 1]);
                for (0..operands.argCount) |i| {
                    const arg = argsStart[i];
                    switch (arg.modifier) {
                        .MoveOrClone => {
                            switch (@as(ValueTag, @enumFromInt(arg.valueTag))) {
                                .Bool, .Int, .Float => {
                                    frame.pushFunctionArgument(frame.register(arg.src).*, i);
                                },
                                .String => {
                                    frame.pushFunctionArgument(RawValue{ .string = frame.register(arg.src).string.clone() }, i);
                                },
                                else => {
                                    @panic("Unsupported move/clone for function argument");
                                },
                            }
                        },
                        else => {
                            @panic("Unsupported argument modifier");
                        },
                    }
                }

                frame = try StackFrame.pushFrame(
                    &threadLocalStack,
                    256,
                    frame.register(operands.funcSrc).actualValue,
                    returnValueAddr,
                );
            },
            .IntIsEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).boolean = frame.register(operands.src1).int == frame.register(operands.src2).int;
            },
            .IntIsNotEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).boolean = frame.register(operands.src1).int != frame.register(operands.src2).int;
            },
            .IntIsLessThan => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).boolean = frame.register(operands.src1).int < frame.register(operands.src2).int;
            },
            .IntIsGreaterThan => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).boolean = frame.register(operands.src1).int > frame.register(operands.src2).int;
            },
            .IntIsLessOrEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).boolean = frame.register(operands.src1).int <= frame.register(operands.src2).int;
            },
            .IntIsGreaterOrEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).boolean = frame.register(operands.src1).int >= frame.register(operands.src2).int;
            },
            .IntAdd => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                const lhs = frame.register(operands.src1).int;
                const rhs = frame.register(operands.src2).int;

                const temp = math.addOverflow(lhs, rhs);
                if (temp.@"1") {
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] + rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.AdditionIntegerOverflow, ErrorSeverity.Warning, message);
                }
                frame.register(operands.dst).int = temp.@"0";
            },
            .IntSubtract => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                const lhs = frame.register(operands.src1).int;
                const rhs = frame.register(operands.src2).int;

                const temp = math.subOverflow(lhs, rhs);
                if (temp.@"1") {
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] - rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.SubtractionIntegerOverflow, ErrorSeverity.Warning, message);
                }
                frame.register(operands.dst).int = temp.@"0";
            },
            .IntMultiply => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                const lhs = frame.register(operands.src1).int;
                const rhs = frame.register(operands.src2).int;

                const temp = math.mulOverflow(lhs, rhs);
                if (temp.@"1") {
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] * rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.MultiplicationIntegerOverflow, ErrorSeverity.Warning, message);
                }
                frame.register(operands.dst).int = temp.@"0";
            },
            .IntDivideTrunc => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                const lhs = frame.register(operands.src1).int;
                const rhs = frame.register(operands.src2).int;

                if (rhs == 0) {
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing integer truncation division", .{ lhs, rhs }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.DivideByZero, ErrorSeverity.Error, message);
                    return FatalScriptError.DivideByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                if (lhs == math.MIN_INT and rhs == -1) {
                    // the absolute value of MIN_INT is 1 greater than MAX_INT, thus overflow would happen.
                    // interestingly the wrap around result would just be MIN_INT.
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing integer truncation division. Using wrap around result of [{}]", .{ lhs, rhs, math.MIN_INT }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.DivisionIntegerOverflow, ErrorSeverity.Warning, message);
                    frame.register(operands.dst).int = math.MIN_INT; // zig doesnt have divison overflow operator
                } else {
                    frame.register(operands.dst).int = @divTrunc(lhs, rhs);
                }
            },
            .IntDivideFloor => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                const lhs = frame.register(operands.src1).int;
                const rhs = frame.register(operands.src2).int;

                if (rhs == 0) {
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing integer floor division", .{ lhs, rhs }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.DivideByZero, ErrorSeverity.Error, message);
                    return FatalScriptError.DivideByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                if (lhs == math.MIN_INT and rhs == -1) {
                    // the absolute value of MIN_INT is 1 greater than MAX_INT, thus overflow would happen.
                    // interestingly the wrap around result would just be MIN_INT.
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing integer floor division. Using wrap around result of [{}]", .{ lhs, rhs, math.MIN_INT }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.DivisionIntegerOverflow, ErrorSeverity.Warning, message);
                    frame.register(operands.dst).int = math.MIN_INT; // zig doesnt have divison overflow operator
                } else {
                    frame.register(operands.dst).int = @divFloor(lhs, rhs);
                }
            },
            .IntModulo => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                const lhs = frame.register(operands.src1).int;
                const rhs = frame.register(operands.src2).int;

                if (rhs == 0) {
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing modulo", .{ lhs, rhs }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.ModuloByZero, ErrorSeverity.Error, message);
                    return FatalScriptError.ModuloByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                frame.register(operands.dst).int = @mod(lhs, rhs);
            },
            .IntRemainder => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                const lhs = frame.register(operands.src1).int;
                const rhs = frame.register(operands.src2).int;

                if (rhs == 0) {
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing remainder", .{ lhs, rhs }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.RemainderByZero, ErrorSeverity.Error, message);
                    return FatalScriptError.RemainderByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                frame.register(operands.dst).int = @rem(lhs, rhs);
            },
            .IntPower => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                const base = frame.register(operands.src1).int;
                const exp = frame.register(operands.src2).int;

                const result = math.powOverflow(base, exp);
                if (result) |numAndOverflow| {
                    frame.register(operands.dst).int = numAndOverflow[0];

                    if (numAndOverflow[1]) {
                        const message = allocPrintZ(allocator(), "Numbers base[{}] to the power of exp[{}]. Using wrap around result of [{}]", .{ base, exp, numAndOverflow[0] }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        self.runtimeError(RuntimeError.PowerIntegerOverflow, ErrorSeverity.Warning, message);
                    }
                } else |_| {
                    const message = allocPrintZ(allocator(), "Numbers base[{}] to the power of exp[{}]", .{ base, exp }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.ZeroToPowerOfNegative, ErrorSeverity.Error, message);
                    return FatalScriptError.ZeroToPowerOfNegative; // TODO figure out how to free all the memory and resources allocated in the callstack
                }
            },
            .BitwiseComplement => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                frame.register(operands.dst).int = ~frame.register(operands.src).int;
            },
            .BitwiseAnd => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).int = frame.register(operands.src1).int & frame.register(operands.src2).int;
            },
            .BitwiseOr => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).int = frame.register(operands.src1).int | frame.register(operands.src2).int;
            },
            .BitwiseXor => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).int = frame.register(operands.src1).int ^ frame.register(operands.src2).int;
            },
            .BitShiftLeft => {
                const MASK = 0b111111;

                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                if (frame.register(operands.src2).int > 63 or frame.register(operands.src2).int < 0) {
                    const message = allocPrintZ(allocator(), "Cannot bitwise left shift by [{}] bits. Instead left shifting using 6 least significant bits: [{}]", .{
                        frame.register(operands.src2).int,
                        frame.register(operands.src2).int & MASK,
                    }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.InvalidBitShiftAmount, ErrorSeverity.Warning, message);
                }

                frame.register(operands.dst).int = frame.register(operands.src1).int << @intCast(frame.register(operands.src2).int & MASK);
            },
            .BitArithmeticShiftRight => {
                const MASK = 0b111111;

                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                if (frame.register(operands.src2).int > 63 or frame.register(operands.src2).int < 0) {
                    const message = allocPrintZ(allocator(), "Cannot bitwise right shift by [{}] bits. Instead right shifting using 6 least significant bits: [{}]", .{
                        frame.register(operands.src2).int,
                        frame.register(operands.src2).int & MASK,
                    }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.InvalidBitShiftAmount, ErrorSeverity.Warning, message);
                }

                frame.register(operands.dst).int = frame.register(operands.src1).int >> @intCast(frame.register(operands.src2).int & MASK);
            },
            .BitLogicalShiftRight => {
                const MASK = 0b111111;

                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                if (frame.register(operands.src2).int > 63 or frame.register(operands.src2).int < 0) {
                    const message = allocPrintZ(allocator(), "Cannot bitwise right shift by [{}] bits. Instead right shifting using 6 least significant bits: [{}]", .{
                        frame.register(operands.src2).int,
                        frame.register(operands.src2).int & MASK,
                    }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.InvalidBitShiftAmount, ErrorSeverity.Warning, message);
                }

                frame.register(operands.dst).actualValue = frame.register(operands.src1).actualValue >> @intCast(frame.register(operands.src2).actualValue & MASK);
            },
            .IntToBool => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                frame.register(operands.dst).boolean = frame.register(operands.src).int != 0;
            },
            .IntToFloat => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                frame.register(operands.dst).float = @floatFromInt(frame.register(operands.src).int);
            },
            .IntToString => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                frame.register(operands.dst).string = String.fromInt(frame.register(operands.src).int);
            },
            .BoolNot => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                frame.register(operands.dst).boolean = !frame.register(operands.src).boolean;
            },
            .BoolToString => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);
                frame.register(operands.dst).string = String.fromBool(frame.register(operands.src).boolean);
            },
            .FloatIsEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(operands.dst != operands.src1);
                assert(operands.dst != operands.src2);
                assert(operands.src1 != operands.src2);

                frame.register(operands.dst).boolean = frame.register(operands.src1).float == frame.register(operands.src2).float;
            },
            .FloatIsNotEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(operands.dst != operands.src1);
                assert(operands.dst != operands.src2);
                assert(operands.src1 != operands.src2);

                frame.register(operands.dst).boolean = frame.register(operands.src1).float != frame.register(operands.src2).float;
            },
            .FloatIsLessThan => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(operands.dst != operands.src1);
                assert(operands.dst != operands.src2);
                assert(operands.src1 != operands.src2);

                frame.register(operands.dst).boolean = frame.register(operands.src1).float < frame.register(operands.src2).float;
            },
            .FloatIsGreaterThan => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(operands.dst != operands.src1);
                assert(operands.dst != operands.src2);
                assert(operands.src1 != operands.src2);

                frame.register(operands.dst).boolean = frame.register(operands.src1).float > frame.register(operands.src2).float;
            },
            .FloatIsLessOrEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(operands.dst != operands.src1);
                assert(operands.dst != operands.src2);
                assert(operands.src1 != operands.src2);

                frame.register(operands.dst).boolean = frame.register(operands.src1).float <= frame.register(operands.src2).float;
            },
            .FloatIsGreaterOrEqual => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                assert(operands.dst != operands.src1);
                assert(operands.dst != operands.src2);
                assert(operands.src1 != operands.src2);

                frame.register(operands.dst).boolean = frame.register(operands.src1).float >= frame.register(operands.src2).float;
            },
            .FloatAdd => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).float = frame.register(operands.src1).float + frame.register(operands.src2).float;
            },
            .FloatSubtract => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).float = frame.register(operands.src1).float - frame.register(operands.src2).float;
            },
            .FloatMultiply => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
                frame.register(operands.dst).float = frame.register(operands.src1).float * frame.register(operands.src2).float;
            },
            .FloatDivide => {
                const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

                if (frame.register(operands.src2).float == 0) {
                    const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing float division", .{
                        frame.register(operands.src1).float,
                        frame.register(operands.src2).float,
                    }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.DivideByZero, ErrorSeverity.Error, message);
                    return FatalScriptError.DivideByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
                }

                frame.register(operands.dst).float = frame.register(operands.src1).float / frame.register(operands.src2).float;
            },
            .FloatToInt => {
                const operands = bytecode.decode(Bytecode.OperandsDstSrc);

                const MAX_INT_AS_FLOAT: f64 = @floatFromInt(math.MAX_INT);
                const MIN_INT_AS_FLOAT: f64 = @floatFromInt(math.MIN_INT);
                const src = frame.register(operands.src).float;

                if (src > MAX_INT_AS_FLOAT) {
                    const message = allocPrintZ(allocator(), "Float number [{}] is greater than the max int value of [{}]. Clamping to max int", .{ src, math.MAX_INT }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.FloatToIntOverflow, ErrorSeverity.Warning, message);
                    frame.register(operands.dst).int = math.MAX_INT;
                } else if (src < MIN_INT_AS_FLOAT) {
                    const message = allocPrintZ(allocator(), "Float number [{}] is less than than the min int value of [{}]. Clamping to max int", .{ src, math.MIN_INT }) catch {
                        @panic("Script out of memory");
                    };
                    defer allocator().free(message);

                    self.runtimeError(RuntimeError.FloatToIntOverflow, ErrorSeverity.Warning, message);
                    frame.register(operands.dst).int = math.MIN_INT;
                } else {
                    frame.register(operands.dst).int = @intFromFloat(src);
                }
            },
            .StringDeinit => {
                const operand = bytecode.decode(Bytecode.OperandsOnlyDst);
                frame.register(operand.dst).string.deinit();
            },
            else => {
                @panic("not implemented");
            },
        }
        instructionPointer.* += 1;
    }
    return captureReturn;
}

fn runtimeError(self: *const Self, err: RuntimeError, severity: ErrorSeverity, message: []const u8) void {
    // Only the mutex and the data it owns are modified here, so removing the const is fine.
    const contextMutex: *Mutex = @constCast(&self._contextMutex);
    contextMutex.lock();
    defer contextMutex.unlock();

    const context: *ScriptContext = @constCast(&self._context);
    context.runtimeError(self, err, severity, message);
}

pub const FatalScriptError = error{
    StackOverflow,
    NullDereference,
    DivideByZero,
    ModuloByZero,
    RemainderByZero,
    ZeroToPowerOfNegative,
};

/// Handles reporting errors, and other user specific data.
/// In `CubicScriptState.zig`, an example of implementing this can be found with `ScriptTestingContextError`.
pub const ScriptContext = extern struct {
    pub const default_context = ScriptContext{
        .ptr = undefined,
        .vtable = &.{
            .errorCallback = defaultContextErrorCallback,
            .deinit = defaultContextDeinit,
        },
    };

    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = extern struct {
        /// `message` will be a null terminated string, using `messageLength` bytes excluding null terminator (number of UTF-8 bytes NOT code points).
        errorCallback: *const fn (self: *anyopaque, state: *const Self, err: RuntimeError, severity: ErrorSeverity, message: [*c]const u8, messageLength: usize) callconv(.C) void,
        /// Deinitializes the script context object itself. Can be used to call C++ destructors, Rust drop, or whatever else.
        deinit: *const fn (self: *anyopaque) callconv(.C) void,
    };

    pub fn runtimeError(self: *ScriptContext, state: *const Self, err: RuntimeError, severity: ErrorSeverity, message: []const u8) void {
        self.vtable.errorCallback(
            self.ptr,
            state,
            err,
            severity,
            @ptrCast(message.ptr),
            message.len,
        );
    }

    pub fn deinit(self: *ScriptContext) void {
        self.vtable.deinit(self.ptr);
    }
};

fn defaultContextErrorCallback(_: *anyopaque, _: *const Self, err: RuntimeError, severity: ErrorSeverity, message: [*c]const u8, messageLength: usize) callconv(.C) void {
    if (runtime_safety) {
        if (messageLength > 0) {
            std.debug.print("Cubic Script {s}: {s}\n\t{s}\n", .{ @tagName(severity), @tagName(err), message });
        } else {
            std.debug.print("Cubic Script {s}: {s}\n", .{ @tagName(severity), @tagName(err) });
        }
    }
}

fn defaultContextDeinit(_: *anyopaque) callconv(.C) void {}

test "nop" {
    const state = Self.init(null);
    defer state.deinit();

    const instructions = [_]Bytecode{
        Bytecode.encode(OpCode.Nop, void, {}),
    };

    _ = try state.run(&instructions);
}

test "return" {
    { // dont return value
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -30),
            Bytecode.encodeImmediateUpper(i64, -30),
            Bytecode.encode(.Return, void, {}),
        };

        _ = try state.run(&instructions);
    }
    { // return value
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -30),
            Bytecode.encodeImmediateUpper(i64, -30),
            Bytecode.encode(.Return, Bytecode.OperandsOptionalReturn, .{ .valueTag = .Int, .src = 0 }),
        };

        const returnedVal = try state.run(&instructions);
        try expect(returnedVal.tag == .Int);
        try expect(returnedVal.value.int == -30);
    }
}

test "call" {
    { // No args, no return
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }), // 0
            Bytecode.encodeImmediateLower(usize, 5), // 1
            Bytecode.encodeImmediateUpper(usize, 5), // 2
            Bytecode.encode(.Call, Bytecode.OperandsFunctionArgs, Bytecode.OperandsFunctionArgs{ .argCount = 0, .funcSrc = 0 }), // 3
            Bytecode.encode(.Return, void, {}), // 4
            // Function
            Bytecode.encode(.Return, void, {}), // 5
        };

        _ = try state.run(&instructions);
    }
}

test "int comparisons" {
    const IntComparisonTester = struct {
        fn intCompare(state: *const Self, opcode: OpCode, src1Value: i64, src2Value: i64, shouldBeTrue: bool) !void {
            const LOW_MASK = 0xFFFFFFFF;
            const HIGH_MASK: usize = @shlExact(0xFFFFFFFF, 32);
            const src1: usize = @bitCast(src1Value);
            const src2: usize = @bitCast(src2Value);

            const instructions = [_]Bytecode{
                Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
                Bytecode{ .value = @intCast(src1 & LOW_MASK) },
                Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
                Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
                Bytecode{ .value = @intCast(src2 & LOW_MASK) },
                Bytecode{ .value = @intCast(@shrExact(src2 & HIGH_MASK, 32)) },
                Bytecode.encode(opcode, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
            };

            _ = try state.run(&instructions);

            var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
            defer _ = frame.popFrame(&threadLocalStack);

            if (shouldBeTrue) {
                try expect(frame.register(2).boolean == true);
            } else {
                try expect(frame.register(2).boolean == false);
            }
        }
    };

    {
        const state = Self.init(null);
        defer state.deinit();

        try IntComparisonTester.intCompare(state, OpCode.IntIsEqual, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, OpCode.IntIsEqual, math.MAX_INT, 123456789, false);

        try IntComparisonTester.intCompare(state, OpCode.IntIsNotEqual, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, OpCode.IntIsNotEqual, math.MAX_INT, 123456789, true);

        try IntComparisonTester.intCompare(state, OpCode.IntIsLessThan, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, OpCode.IntIsLessThan, math.MAX_INT, 123456789, false);
        try IntComparisonTester.intCompare(state, OpCode.IntIsLessThan, -1, math.MAX_INT, true);

        try IntComparisonTester.intCompare(state, OpCode.IntIsGreaterThan, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, OpCode.IntIsGreaterThan, math.MAX_INT, 123456789, true);
        try IntComparisonTester.intCompare(state, OpCode.IntIsGreaterThan, -1, math.MAX_INT, false);

        try IntComparisonTester.intCompare(state, OpCode.IntIsLessOrEqual, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, OpCode.IntIsLessOrEqual, math.MAX_INT, 123456789, false);
        try IntComparisonTester.intCompare(state, OpCode.IntIsLessOrEqual, -1, math.MAX_INT, true);

        try IntComparisonTester.intCompare(state, OpCode.IntIsGreaterOrEqual, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, OpCode.IntIsGreaterOrEqual, math.MAX_INT, 123456789, true);
        try IntComparisonTester.intCompare(state, OpCode.IntIsGreaterOrEqual, -1, math.MAX_INT, false);
    }
}

/// Used for testing to validate that certain errors happened.
fn ScriptTestingContextError(comptime ErrTag: RuntimeError) type {
    return struct {
        shouldExpectError: bool,
        didErrorHappen: bool = false,

        fn errorCallback(self: *@This(), _: *const Self, err: RuntimeError, _: ErrorSeverity, _: [*c]const u8, _: usize) callconv(.C) void {
            if (err == ErrTag) {
                self.didErrorHappen = true;
            } else {
                @panic("unexpected error");
            }
        }

        fn deinit(self: *@This()) callconv(.C) void {
            if (self.shouldExpectError) {
                expect(self.didErrorHappen) catch unreachable;
            } else {
                expect(!self.didErrorHappen) catch unreachable;
            }
        }

        fn asContext(self: *@This()) ScriptContext {
            return ScriptContext{
                .ptr = @ptrCast(self),
                .vtable = &.{ .errorCallback = @ptrCast(&@This().errorCallback), .deinit = @ptrCast(&@This().deinit) },
            };
        }
    };
}

test "int addition" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.AdditionIntegerOverflow){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: i64 = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = 10;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(src1 & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntAdd, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 11);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.AdditionIntegerOverflow){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: i64 = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = math.MAX_INT;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(src1 & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntAdd, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == math.MIN_INT);
    }
}

test "int subtraction" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.AdditionIntegerOverflow){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = 10;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntSubtract, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 9);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.SubtractionIntegerOverflow){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: usize = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = math.MIN_INT;
        const srcAsUsize: usize = @bitCast(src1);

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(srcAsUsize & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(srcAsUsize & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntSubtract, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == math.MAX_INT);
    }
}

test "int multiplication" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.MultiplicationIntegerOverflow){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: i64 = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = math.MAX_INT;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(src1 & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 1 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntMultiply, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == math.MAX_INT);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.MultiplicationIntegerOverflow){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const LOW_MASK = 0xFFFFFFFF;
        const HIGH_MASK: i64 = @bitCast(@as(usize, @shlExact(0xFFFFFFFF, 32)));

        const src1: i64 = math.MAX_INT;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode{ .value = @intCast(src1 & LOW_MASK) },
            Bytecode{ .value = @intCast(@shrExact(src1 & HIGH_MASK, 32)) },
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode{ .value = 2 }, // store decimal 1
            Bytecode{ .value = 0 },
            Bytecode.encode(OpCode.IntMultiply, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == -2); // this ends up being the wrap around. same as unsigned bitshift left by 1 then bitcasted to signed
    }
}

test "int division truncation" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntDivideTrunc, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == -2);
    }
    { // validate integer overflow
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, math.MIN_INT),
            Bytecode.encodeImmediateUpper(i64, math.MIN_INT),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.IntDivideTrunc, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == math.MIN_INT);
    }
    { // validate divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.DivideByZero){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.IntDivideTrunc, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        if (state.run(&instructions)) |_| {
            try expect(false);
        } else |err| {
            _ = err catch {};
        }
    }
}

test "int division floor" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntDivideFloor, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == -3);
    }
    { // validate integer overflow
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, math.MIN_INT),
            Bytecode.encodeImmediateUpper(i64, math.MIN_INT),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.IntDivideFloor, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == math.MIN_INT);
    }
    { // validate divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.DivideByZero){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.IntDivideFloor, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        if (state.run(&instructions)) |_| {
            try expect(false);
        } else |err| {
            _ = err catch {};
        }
    }
}

test "int modulo" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.ModuloByZero){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntModulo, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 1);
    }
    { // divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.ModuloByZero){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.IntModulo, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        if (state.run(&instructions)) |_| {
            try expect(false);
        } else |err| {
            _ = err catch {};
        }
    }
}

test "int remainder" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.RemainderByZero){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntRemainder, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == -1);
    }
    { // divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.RemainderByZero){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.IntRemainder, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        if (state.run(&instructions)) |_| {
            try expect(false);
        } else |err| {
            _ = err catch {};
        }
    }
}

test "int power" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 25);
    }
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const src1: i64 = -5;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, -2),
            Bytecode.encodeImmediateUpper(i64, -2),
            Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 0);
    }
    { // overflow
        var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, math.MAX_INT),
            Bytecode.encodeImmediateUpper(i64, math.MAX_INT),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 2),
            Bytecode.encodeImmediateUpper(i64, 2),
            Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);
    }
    { // 0 to the power of negative error
        var contextObject = ScriptTestingContextError(RuntimeError.ZeroToPowerOfNegative){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0),
            Bytecode.encodeImmediateUpper(i64, 0),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, -2),
            Bytecode.encodeImmediateUpper(i64, -2),
            Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        if (state.run(&instructions)) |_| {
            try expect(false);
        } else |err| {
            _ = err catch {};
        }
    }
}

test "bitwise complement" {
    {
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.BitwiseComplement, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).int == -1);
    }
    {
        const state = Self.init(null);
        defer state.deinit();

        const src1: i64 = 1;

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, src1),
            Bytecode.encodeImmediateUpper(i64, src1),
            Bytecode.encode(OpCode.BitwiseComplement, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).int == -2);
    }
}

test "bitwise and" {
    {
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b011),
            Bytecode.encodeImmediateUpper(i64, 0b011),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.BitwiseAnd, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 0b010);
    }
}

test "bitwise or" {
    {
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b011),
            Bytecode.encodeImmediateUpper(i64, 0b011),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.BitwiseOr, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 0b111);
    }
}

test "bitwise xor" {
    {
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b011),
            Bytecode.encodeImmediateUpper(i64, 0b011),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.BitwiseXor, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 0b101);
    }
}

test "bitshift left" {
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitShiftLeft, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == -2);
    }
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
            Bytecode.encodeImmediateUpper(i64, 65),
            Bytecode.encode(OpCode.BitShiftLeft, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == -2);
    }
}

test "bitshift arithmetic right" {
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 0b011);
    }
    { // retain sign bit
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == -1);
    }
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
            Bytecode.encodeImmediateUpper(i64, 65),
            Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 0b011);
    }
}

test "bitshift logical right" {
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 0b011);
    }
    { // dont retain sign bit
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == math.MAX_INT);
    }
    {
        var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

        const state = Self.init(contextObject.asContext());
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 0b110),
            Bytecode.encodeImmediateUpper(i64, 0b110),
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 1 }),
            Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
            Bytecode.encodeImmediateUpper(i64, 65),
            Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(2).int == 0b011);
    }
}

test "int to bool" {
    { // 0 -> false
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).boolean == false);
    }
    { // 1 -> true
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).boolean == true);
    }
    { // non-zero -> true
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 33),
            Bytecode.encodeImmediateUpper(i64, 33),
            Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).boolean == true);
    }
}

test "int to float" {
    { // 0
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).float == 0.0);
    }
    { // 1
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).float == 1.0);
    }
    { // -1
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).float == -1.0);
    }
    { // arbitrary value
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -2398712938),
            Bytecode.encodeImmediateUpper(i64, -2398712938),
            Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).float == -2398712938.0);
    }
}

test "int to string" {
    { // 0
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).string.eqlSlice("0"));
        frame.register(1).string.deinit();
    }
    { // 1
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, 1),
            Bytecode.encodeImmediateUpper(i64, 1),
            Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).string.eqlSlice("1"));
        frame.register(1).string.deinit();
    }
    { // -1
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -1),
            Bytecode.encodeImmediateUpper(i64, -1),
            Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).string.eqlSlice("-1"));
        frame.register(1).string.deinit();
    }
    { // arbitrary value
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(i64, -2398712938),
            Bytecode.encodeImmediateUpper(i64, -2398712938),
            Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).string.eqlSlice("-2398712938"));
        frame.register(1).string.deinit();
    }
}

test "bool not" {
    {
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encode(OpCode.BoolNot, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).boolean == true);
    }
    {
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(bool, true),
            Bytecode.encodeImmediateUpper(bool, true),
            Bytecode.encode(OpCode.BoolNot, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).boolean == false);
    }
}

test "bool to string" {
    { // true
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(bool, true),
            Bytecode.encodeImmediateUpper(bool, true),
            Bytecode.encode(OpCode.BoolToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).string.eqlSlice("true"));
        frame.register(1).string.deinit();
    }
    { // false
        const state = Self.init(null);
        defer state.deinit();

        const instructions = [_]Bytecode{
            Bytecode.encode(OpCode.LoadImmediate, Bytecode.OperandsOnlyDst, Bytecode.OperandsOnlyDst{ .dst = 0 }),
            Bytecode.encodeImmediateLower(bool, false),
            Bytecode.encodeImmediateUpper(bool, false),
            Bytecode.encode(OpCode.BoolToString, Bytecode.OperandsDstSrc, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
        };

        _ = try state.run(&instructions);

        var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
        defer _ = frame.popFrame(&threadLocalStack);
        try expect(frame.register(1).string.eqlSlice("false"));
        frame.register(1).string.deinit();
    }
}
