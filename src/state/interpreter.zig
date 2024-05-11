const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const CubicScriptState = @import("CubicScriptState.zig");
const Stack = @import("Stack.zig");
const StackFrame = Stack.StackFrame;
const Bytecode = @import("Bytecode.zig");
const OpCode = Bytecode.OpCode;
const String = root.String;
const math = @import("../types/math.zig");
const Error = @import("Errors.zig");
const allocPrintZ = std.fmt.allocPrintZ;
const sync_queue = @import("sync_queue.zig");
const Mutex = std.Thread.Mutex;
const ScriptContext = CubicScriptState.ScriptContext;
const FatalScriptError = CubicScriptState.FatalScriptError;
const RuntimeError = Error.RuntimeError;
const ErrorSeverity = Error.Severity;
const allocator = @import("global_allocator.zig").allocator;

threadlocal var threadLocalStack: Stack = .{};

/// Execute the operation at `stack.instructionPointer[0]`, and increment the instruction pointer as necessary.
/// If returns `true`, it means a return operation wasn't executed that also exited script execution, and
/// execution can continue. If returns `false`, a return operation occurred and there are no more stack frames.
pub fn executeOperation(state: *const CubicScriptState, stack: *Stack, frame: *StackFrame) FatalScriptError!bool {
    // Tracks how much to increment the instruction pointer by.
    var ipIncrement: usize = 1;
    const bytecode = stack.instructionPointer[0];
    switch (bytecode.getOpCode()) {
        .Nop => {
            //std.debug.print("no operation\n", .{});
        },
        .Move => {
            const operands = bytecode.decode(Bytecode.OperandsDstSrc);
            frame.register(operands.dst).* = frame.register(operands.src).*;
            frame.setRegisterTag(operands.dst, frame.registerTag(operands.src));
        },
        .LoadZero => {
            const operands = bytecode.decode(Bytecode.OperandsZero);
            frame.register(operands.dst).* = std.mem.zeroes(RawValue);
            frame.setRegisterTag(operands.dst, @enumFromInt(operands.tag));
        },
        .LoadImmediate => {
            const operands = bytecode.decode(Bytecode.OperandsImmediate);
            switch (operands.valueTag) {
                .Bool => {
                    if (operands.immediate == 0) {
                        frame.register(operands.dst).boolean = false;
                    } else if (operands.immediate == 1) {
                        frame.register(operands.dst).boolean = true;
                    } else {
                        unreachable;
                    }
                    frame.setRegisterTag(operands.dst, .Bool);
                },
                .Int => {
                    frame.register(operands.dst).int = operands.immediate;
                    frame.setRegisterTag(operands.dst, .Int);
                },
                .Float => {
                    frame.register(operands.dst).float = @floatFromInt(operands.immediate);
                    frame.setRegisterTag(operands.dst, .Float);
                },
            }
        },
        .LoadImmediateLong => {
            // NOTE the two bytecodes after `LoadImmediate` are the 64 bit immediate values, thus the instruction
            // pointer will need to be further incremented.
            const operands = bytecode.decode(Bytecode.OperandsImmediateLong);
            const immediate: usize =
                @as(usize, @intCast(stack.instructionPointer[1].value)) |
                @shlExact(@as(usize, @intCast(stack.instructionPointer[2].value)), 32);

            frame.register(operands.dst).actualValue = immediate;
            frame.setRegisterTag(operands.dst, @enumFromInt(operands.tag));
            ipIncrement += 2;
        },
        .Return => {
            const operands = bytecode.decode(Bytecode.OperandsOptionalReturn);
            if (operands.valueTag != ValueTag.None.asU8()) {
                //assert(frame.registerTag(operands.src).* == operands.valueTag);
                frame.setReturnValue(operands.src);
            }
            if (frame.popFrame(&threadLocalStack)) |previousFrame| {
                frame.* = previousFrame;
            } else {
                return false;
            }
        },
        .Call => {
            const operands = bytecode.decode(Bytecode.OperandsFunctionArgs);
            const returnValueAddr: ?StackFrame.FrameReturnDestination = blk: {
                if (operands.captureReturn) {
                    break :blk .{
                        .val = frame.register(operands.returnDst),
                        .tag = frame.registerTagAddr(operands.returnDst),
                    };
                } else {
                    break :blk null;
                }
            };

            const argsStart: [*]const Bytecode.FunctionArg = @ptrCast(&stack.instructionPointer[3]);
            for (0..operands.argCount) |i| {
                const arg = argsStart[i];
                const valueTag: ValueTag = @enumFromInt(arg.valueTag);
                switch (arg.modifier) {
                    .Owned => {
                        switch (valueTag) {
                            .Bool, .Int, .Float => {
                                frame.pushFunctionArgument(frame.register(arg.src).*, frame.registerTag(arg.src), i);
                            },
                            .String => {
                                frame.pushFunctionArgument(RawValue{ .string = frame.register(arg.src).string.clone() }, frame.registerTag(arg.src), i);
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

            const immediate: Bytecode.CallImmediate = blk: {
                const temp: usize =
                    @as(usize, @intCast(stack.instructionPointer[1].value)) |
                    @shlExact(@as(usize, @intCast(stack.instructionPointer[2].value)), 32);
                break :blk @bitCast(temp);
            };

            {
                const instructionPtrIncrement = blk: {
                    if (operands.argCount == 0) {
                        break :blk 2; // 2 bytecodes to increment for immediate
                    } else {
                        const out = ((operands.argCount + 1) / @sizeOf(Bytecode.FunctionArg)) + 2; // add 3 to be instruction after + immediate
                        break :blk out;
                    }
                };
                // Forcefully increment the instruction pointer here, rather than later, to avoid
                // moving the instruction pointer in a function call.
                stack.instructionPointer = @ptrCast(&stack.instructionPointer[instructionPtrIncrement]);
                ipIncrement = 0;
            }

            switch (immediate.functionType()) {
                .Script => {
                    const fptr = immediate.getScriptFunctionPtr();
                    frame.* = try StackFrame.pushFrame(stack, 256, fptr.bytecodeStart, returnValueAddr);
                },
                // else => {
                //     @panic("Unsupported call function type");
                // },
            }
        },
        .Deinit => {
            const operands = bytecode.decode(Bytecode.OperandsSrcTag);
            assert(frame.registerTag(operands.src).asU8() == operands.tag);
            frame.register(operands.src).deinit(@enumFromInt(operands.tag));
            frame.setRegisterTag(operands.src, .None);
        },
        .Sync => {
            const operands = bytecode.decode(Bytecode.OperandsSync);
            assert(operands.count != 0);
            { // Since the first sync operand is within `operands`, the truncation division will correctly specify the increment amount
                const instructionPtrIncrement = operands.count / 2;
                stack.instructionPointer = @ptrCast(&stack.instructionPointer[instructionPtrIncrement]);
                ipIncrement = 0;
            }

            const QueueScriptLock = struct {
                fn queue(stackFrame: *StackFrame, syncObj: Bytecode.OperandsSync.SyncModifier) void {
                    switch (stackFrame.registerTag(syncObj.src)) {
                        .Shared => {
                            switch (syncObj.access) {
                                .Shared => {
                                    sync_queue.queueScriptSharedRefShared(&stackFrame.register(syncObj.src).shared);
                                },
                                .Exclusive => {
                                    sync_queue.queueScriptSharedRefExclusive(&stackFrame.register(syncObj.src).shared);
                                },
                            }
                        },
                        .Class => {
                            @panic("TODO implement class acquire");
                        },
                        else => {
                            @panic("Cannot lock other data types");
                        },
                    }
                }
            };

            QueueScriptLock.queue(frame, operands.firstSync);
            if (operands.count > 1) {
                const syncStart: [*]const Bytecode.OperandsSync.SyncModifier = @ptrCast(&stack.instructionPointer[1]);
                for (0..(operands.count - 1)) |i| { // Subtract 1 because the first sync object is within the initial bytecode
                    QueueScriptLock.queue(frame, syncStart[i]);
                }
            }

            // TODO maybe try lock?
            sync_queue.acquire();
        },
        .Unsync => {
            sync_queue.release();
        },
        .Cast => {
            const operands = bytecode.decode(Bytecode.OperandsCast);
            const srcTag = frame.registerTag(operands.src);
            const dstTag: ValueTag = @enumFromInt(operands.tag);
            const src = frame.register(operands.src);
            const dst = frame.register(operands.dst);

            assert(srcTag != .None);
            assert(dstTag != .None);

            frame.setRegisterTag(operands.dst, dstTag);

            switch (srcTag) {
                .Bool => {
                    switch (dstTag) {
                        .Bool => {
                            dst.boolean = src.boolean;
                        },
                        .Int => {
                            dst.int = @intFromBool(src.boolean);
                        },
                        .Float => {
                            dst.float = if (src.boolean) 1.0 else 0.0;
                        },
                        .String => {
                            dst.string = String.fromBool(src.boolean);
                        },
                        else => {
                            const message = allocPrintZ(std.heap.c_allocator, "Cannot cast Bool to {s}", .{@tagName(dstTag)}) catch unreachable;
                            @panic(message);
                        },
                    }
                },
                .Int => {
                    switch (dstTag) {
                        .Bool => {
                            dst.boolean = src.int != 0;
                        },
                        .Int => {
                            dst.int = src.int;
                        },
                        .Float => {
                            dst.float = @floatFromInt(src.int);
                        },
                        .String => {
                            dst.string = String.fromInt(src.int);
                        },
                        else => {
                            const message = allocPrintZ(std.heap.c_allocator, "Cannot cast Int to {s}", .{@tagName(dstTag)}) catch unreachable;
                            @panic(message);
                        },
                    }
                },
                .Float => {
                    switch (dstTag) {
                        .Bool => {
                            dst.boolean = src.float != 0.0;
                        },
                        .Int => {
                            const MAX_INT_AS_FLOAT: f64 = @floatFromInt(math.MAX_INT);
                            const MIN_INT_AS_FLOAT: f64 = @floatFromInt(math.MIN_INT);

                            if (src.float > MAX_INT_AS_FLOAT) {
                                const message = allocPrintZ(allocator(), "Float number [{}] is greater than the max int value of [{}]. Clamping to max int", .{ src, math.MAX_INT }) catch {
                                    @panic("Script out of memory");
                                };
                                defer allocator().free(message);

                                runtimeError(state, RuntimeError.FloatToIntOverflow, ErrorSeverity.Warning, message);
                                dst.int = math.MAX_INT;
                            } else if (src.float < MIN_INT_AS_FLOAT) {
                                const message = allocPrintZ(allocator(), "Float number [{}] is less than than the min int value of [{}]. Clamping to min int", .{ src, math.MIN_INT }) catch {
                                    @panic("Script out of memory");
                                };
                                defer allocator().free(message);

                                runtimeError(state, RuntimeError.FloatToIntOverflow, ErrorSeverity.Warning, message);
                                dst.int = math.MIN_INT;
                            } else {
                                dst.int = @intFromFloat(src.float);
                            }
                        },
                        .Float => {
                            dst.float = src.float;
                        },
                        .String => {
                            dst.string = String.fromFloat(src.float);
                        },
                        else => {
                            const message = allocPrintZ(std.heap.c_allocator, "Cannot cast Float to {s}", .{@tagName(dstTag)}) catch unreachable;
                            @panic(message);
                        },
                    }
                },
                .String => {
                    @panic("TODO string casts");
                },
                else => {
                    @panic("Unsupported cast src type");
                },
            }
        },
        .Equal => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            const result = blk: {
                switch (frame.registerTag(operands.src1)) {
                    .Bool => {
                        break :blk frame.register(operands.src1).boolean == frame.register(operands.src2).boolean;
                    },
                    .Int => {
                        break :blk frame.register(operands.src1).int == frame.register(operands.src2).int;
                    },
                    .Float => {
                        break :blk frame.register(operands.src1).float == frame.register(operands.src2).float;
                    },
                    .String => {
                        break :blk frame.register(operands.src1).string.eql(frame.register(operands.src2).string);
                    },
                    .Array => {
                        break :blk frame.register(operands.src1).array.eql(frame.register(operands.src2).array);
                    },
                    else => {
                        @panic("Unimplemented equality type");
                    },
                }
            };
            frame.register(operands.dst).boolean = result;
            frame.setRegisterTag(operands.dst, .Bool);
        },
        .NotEqual => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            const result = blk: {
                switch (frame.registerTag(operands.src1)) {
                    .Bool => {
                        break :blk frame.register(operands.src1).boolean != frame.register(operands.src2).boolean;
                    },
                    .Int => {
                        break :blk frame.register(operands.src1).int != frame.register(operands.src2).int;
                    },
                    .Float => {
                        break :blk frame.register(operands.src1).float != frame.register(operands.src2).float;
                    },
                    .String => {
                        break :blk !frame.register(operands.src1).string.eql(frame.register(operands.src2).string);
                    },
                    .Array => {
                        break :blk !frame.register(operands.src1).array.eql(frame.register(operands.src2).array);
                    },
                    else => {
                        @panic("Unimplemented equality type");
                    },
                }
            };
            frame.register(operands.dst).boolean = result;
            frame.setRegisterTag(operands.dst, .Bool);
        },
        .Less => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            const result = blk: {
                switch (frame.registerTag(operands.src1)) {
                    .Bool => {
                        break :blk @intFromBool(frame.register(operands.src1).boolean) < @intFromBool(frame.register(operands.src2).boolean);
                    },
                    .Int => {
                        break :blk frame.register(operands.src1).int < frame.register(operands.src2).int;
                    },
                    .Float => {
                        break :blk frame.register(operands.src1).float < frame.register(operands.src2).float;
                    },
                    .String => {
                        break :blk frame.register(operands.src1).string.cmp(frame.register(operands.src2).string) == .Less;
                    },
                    else => {
                        @panic("Unimplemented equality type");
                    },
                }
            };
            frame.register(operands.dst).boolean = result;
            frame.setRegisterTag(operands.dst, .Bool);
        },
        .Greater => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            const result = blk: {
                switch (frame.registerTag(operands.src1)) {
                    .Bool => {
                        break :blk @intFromBool(frame.register(operands.src1).boolean) > @intFromBool(frame.register(operands.src2).boolean);
                    },
                    .Int => {
                        break :blk frame.register(operands.src1).int > frame.register(operands.src2).int;
                    },
                    .Float => {
                        break :blk frame.register(operands.src1).float > frame.register(operands.src2).float;
                    },
                    .String => {
                        break :blk frame.register(operands.src1).string.cmp(frame.register(operands.src2).string) == .Greater;
                    },
                    else => {
                        @panic("Unimplemented equality type");
                    },
                }
            };
            frame.register(operands.dst).boolean = result;
            frame.setRegisterTag(operands.dst, .Bool);
        },
        .LessOrEqual => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            const result = blk: {
                switch (frame.registerTag(operands.src1)) {
                    .Bool => {
                        break :blk @intFromBool(frame.register(operands.src1).boolean) <= @intFromBool(frame.register(operands.src2).boolean);
                    },
                    .Int => {
                        break :blk frame.register(operands.src1).int <= frame.register(operands.src2).int;
                    },
                    .Float => {
                        break :blk frame.register(operands.src1).float <= frame.register(operands.src2).float;
                    },
                    .String => {
                        const cmp = frame.register(operands.src1).string.cmp(frame.register(operands.src2).string);
                        break :blk cmp == .Less or cmp == .Equal;
                    },
                    else => {
                        @panic("Unimplemented equality type");
                    },
                }
            };
            frame.register(operands.dst).boolean = result;
            frame.setRegisterTag(operands.dst, .Bool);
        },
        .GreaterOrEqual => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            const result = blk: {
                switch (frame.registerTag(operands.src1)) {
                    .Bool => {
                        break :blk @intFromBool(frame.register(operands.src1).boolean) >= @intFromBool(frame.register(operands.src2).boolean);
                    },
                    .Int => {
                        break :blk frame.register(operands.src1).int >= frame.register(operands.src2).int;
                    },
                    .Float => {
                        break :blk frame.register(operands.src1).float >= frame.register(operands.src2).float;
                    },
                    .String => {
                        const cmp = frame.register(operands.src1).string.cmp(frame.register(operands.src2).string);
                        break :blk cmp == .Greater or cmp == .Equal;
                    },
                    else => {
                        @panic("Unimplemented equality type");
                    },
                }
            };
            frame.register(operands.dst).boolean = result;
            frame.setRegisterTag(operands.dst, .Bool);
        },
        .BoolNot => {
            const operands = bytecode.decode(Bytecode.OperandsDstSrc);
            assert(frame.registerTag(operands.src) == .Bool);
            frame.register(operands.dst).boolean = !frame.register(operands.src).boolean;
            frame.setRegisterTag(operands.dst, .Bool);
        },
        .Add => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            switch (frame.registerTag(operands.src1)) {
                .Int => {
                    const lhs = frame.register(operands.src1).int;
                    const rhs = frame.register(operands.src2).int;

                    const temp = math.addOverflow(lhs, rhs);
                    if (temp.@"1") {
                        const message = allocPrintZ(allocator(), "Numbers lhs[{}] + rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        runtimeError(state, RuntimeError.AdditionIntegerOverflow, ErrorSeverity.Warning, message);
                    }
                    frame.register(operands.dst).int = temp.@"0";
                    frame.setRegisterTag(operands.dst, .Int);
                },
                .Float => {
                    frame.register(operands.dst).float = frame.register(operands.src1).float + frame.register(operands.src2).float;
                    frame.setRegisterTag(operands.dst, .Float);
                },
                .String => {
                    var clone = frame.register(operands.src1).string.clone();
                    clone.appendUnchecked(frame.register(operands.src2).string.toSlice());
                    frame.register(operands.dst).string = clone;
                    frame.setRegisterTag(operands.dst, .String);
                },
                else => {
                    @panic("Unimplemented add type");
                },
            }
        },
        .Subtract => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            switch (frame.registerTag(operands.src1)) {
                .Int => {
                    const lhs = frame.register(operands.src1).int;
                    const rhs = frame.register(operands.src2).int;

                    const temp = math.subOverflow(lhs, rhs);
                    if (temp.@"1") {
                        const message = allocPrintZ(allocator(), "Numbers lhs[{}] - rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        runtimeError(state, RuntimeError.SubtractionIntegerOverflow, ErrorSeverity.Warning, message);
                    }
                    frame.register(operands.dst).int = temp.@"0";
                    frame.setRegisterTag(operands.dst, .Int);
                },
                .Float => {
                    frame.register(operands.dst).float = frame.register(operands.src1).float - frame.register(operands.src2).float;
                    frame.setRegisterTag(operands.dst, .Float);
                },
                else => {
                    @panic("Unimplemented subtract type");
                },
            }
        },
        .Multiply => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            switch (frame.registerTag(operands.src1)) {
                .Int => {
                    const lhs = frame.register(operands.src1).int;
                    const rhs = frame.register(operands.src2).int;

                    const temp = math.mulOverflow(lhs, rhs);
                    if (temp.@"1") {
                        const message = allocPrintZ(allocator(), "Numbers lhs[{}] * rhs[{}]. Using wrap around result of [{}]", .{ lhs, rhs, temp.@"0" }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        runtimeError(state, RuntimeError.MultiplicationIntegerOverflow, ErrorSeverity.Warning, message);
                    }
                    frame.register(operands.dst).int = temp.@"0";
                    frame.setRegisterTag(operands.dst, .Int);
                },
                .Float => {
                    frame.register(operands.dst).float = frame.register(operands.src1).float * frame.register(operands.src2).float;
                    frame.setRegisterTag(operands.dst, .Float);
                },
                else => {
                    @panic("Unimplemented multiply type");
                },
            }
        },
        .Divide => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            switch (frame.registerTag(operands.src1)) {
                .Int => {
                    const lhs = frame.register(operands.src1).int;
                    const rhs = frame.register(operands.src2).int;

                    if (rhs == 0) {
                        const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing integer truncation division", .{ lhs, rhs }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        runtimeError(state, RuntimeError.DivideByZero, ErrorSeverity.Error, message);
                        return FatalScriptError.DivideByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
                    }

                    if (lhs == math.MIN_INT and rhs == -1) {
                        // the absolute value of MIN_INT is 1 greater than MAX_INT, thus overflow would happen.
                        // interestingly the wrap around result would just be MIN_INT.
                        const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing integer truncation division. Using wrap around result of [{}]", .{ lhs, rhs, math.MIN_INT }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        runtimeError(state, RuntimeError.DivisionIntegerOverflow, ErrorSeverity.Warning, message);
                        frame.register(operands.dst).int = math.MIN_INT; // zig doesnt have divison overflow operator
                    } else {
                        frame.register(operands.dst).int = @divTrunc(lhs, rhs);
                    }
                    frame.setRegisterTag(operands.dst, .Int);
                },
                .Float => {
                    if (frame.register(operands.src2).float == 0) {
                        const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing float division", .{
                            frame.register(operands.src1).float,
                            frame.register(operands.src2).float,
                        }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        runtimeError(state, RuntimeError.DivideByZero, ErrorSeverity.Error, message);
                        return FatalScriptError.DivideByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
                    }

                    frame.register(operands.dst).float = frame.register(operands.src1).float / frame.register(operands.src2).float;
                    frame.setRegisterTag(operands.dst, .Float);
                },
                else => {
                    @panic("Unimplemented divide type");
                },
            }
        },
        .DivideFloor => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == .Int);
            assert(frame.registerTag(operands.src2) == .Int);

            const lhs = frame.register(operands.src1).int;
            const rhs = frame.register(operands.src2).int;

            if (rhs == 0) {
                const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing integer floor division", .{ lhs, rhs }) catch {
                    @panic("Script out of memory");
                };
                defer allocator().free(message);

                runtimeError(state, RuntimeError.DivideByZero, ErrorSeverity.Error, message);
                return FatalScriptError.DivideByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
            }

            if (lhs == math.MIN_INT and rhs == -1) {
                // the absolute value of MIN_INT is 1 greater than MAX_INT, thus overflow would happen.
                // interestingly the wrap around result would just be MIN_INT.
                const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing integer floor division. Using wrap around result of [{}]", .{ lhs, rhs, math.MIN_INT }) catch {
                    @panic("Script out of memory");
                };
                defer allocator().free(message);

                runtimeError(state, RuntimeError.DivisionIntegerOverflow, ErrorSeverity.Warning, message);
                frame.register(operands.dst).int = math.MIN_INT; // zig doesnt have divison overflow operator
            } else {
                frame.register(operands.dst).int = @divFloor(lhs, rhs);
            }
            frame.setRegisterTag(operands.dst, .Int);
        },
        .Modulo => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

            const lhs = frame.register(operands.src1).int;
            const rhs = frame.register(operands.src2).int;

            if (rhs == 0) {
                const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing modulo", .{ lhs, rhs }) catch {
                    @panic("Script out of memory");
                };
                defer allocator().free(message);

                runtimeError(state, RuntimeError.ModuloByZero, ErrorSeverity.Error, message);
                return FatalScriptError.ModuloByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
            }

            frame.register(operands.dst).int = @mod(lhs, rhs);
            frame.setRegisterTag(operands.dst, .Int);
        },
        .Remainder => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == .Int);
            assert(frame.registerTag(operands.src2) == .Int);

            const lhs = frame.register(operands.src1).int;
            const rhs = frame.register(operands.src2).int;

            if (rhs == 0) {
                const message = allocPrintZ(allocator(), "Numbers lhs[{}] / rhs[{}] doing remainder", .{ lhs, rhs }) catch {
                    @panic("Script out of memory");
                };
                defer allocator().free(message);

                runtimeError(state, RuntimeError.RemainderByZero, ErrorSeverity.Error, message);
                return FatalScriptError.RemainderByZero; // TODO figure out how to free all the memory and resources allocated in the callstack
            }

            frame.register(operands.dst).int = @rem(lhs, rhs);
            frame.setRegisterTag(operands.dst, .Int);
        },
        .Power => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            assert(frame.registerTag(operands.src1) == frame.registerTag(operands.src2));

            switch (frame.registerTag(operands.src1)) {
                .Int => {
                    const base = frame.register(operands.src1).int;
                    const exp = frame.register(operands.src2).int;

                    const result = math.powOverflow(base, exp);
                    if (result) |numAndOverflow| {
                        frame.register(operands.dst).int = numAndOverflow[0];
                        frame.setRegisterTag(operands.dst, .Int);

                        if (numAndOverflow[1]) {
                            const message = allocPrintZ(allocator(), "Numbers base[{}] to the power of exp[{}]. Using wrap around result of [{}]", .{ base, exp, numAndOverflow[0] }) catch {
                                @panic("Script out of memory");
                            };
                            defer allocator().free(message);

                            runtimeError(state, RuntimeError.PowerIntegerOverflow, ErrorSeverity.Warning, message);
                        }
                    } else |_| {
                        const message = allocPrintZ(allocator(), "Numbers base[{}] to the power of exp[{}]", .{ base, exp }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        runtimeError(state, RuntimeError.ZeroToPowerOfNegative, ErrorSeverity.Error, message);
                        return FatalScriptError.ZeroToPowerOfNegative; // TODO figure out how to free all the memory and resources allocated in the callstack
                    }
                },
                .Float => {
                    // TODO handle negative base to the power of non-integer

                    const base = frame.register(operands.src1).float;
                    const exp = frame.register(operands.src2).float;

                    const result = math.powFloat(base, exp);
                    if (result) |num| {
                        frame.register(operands.dst).float = num;
                        frame.setRegisterTag(operands.dst, .Float);
                    } else |_| {
                        const message = allocPrintZ(allocator(), "Numbers base[{}] to the power of exp[{}]", .{ base, exp }) catch {
                            @panic("Script out of memory");
                        };
                        defer allocator().free(message);

                        runtimeError(state, RuntimeError.ZeroToPowerOfNegative, ErrorSeverity.Error, message);
                        return FatalScriptError.ZeroToPowerOfNegative; // TODO figure out how to free all the memory and resources allocated in the callstack
                    }
                },
                else => {
                    @panic("Unsupported type for exponent");
                },
            }
        },
        .BitwiseComplement => {
            const operands = bytecode.decode(Bytecode.OperandsDstSrc);
            frame.register(operands.dst).int = ~frame.register(operands.src).int;
            frame.setRegisterTag(operands.dst, .Int);
        },
        .BitwiseAnd => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            frame.register(operands.dst).int = frame.register(operands.src1).int & frame.register(operands.src2).int;
            frame.setRegisterTag(operands.dst, .Int);
        },
        .BitwiseOr => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            frame.register(operands.dst).int = frame.register(operands.src1).int | frame.register(operands.src2).int;
            frame.setRegisterTag(operands.dst, .Int);
        },
        .BitwiseXor => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);
            frame.register(operands.dst).int = frame.register(operands.src1).int ^ frame.register(operands.src2).int;
            frame.setRegisterTag(operands.dst, .Int);
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

                runtimeError(state, RuntimeError.InvalidBitShiftAmount, ErrorSeverity.Warning, message);
            }

            frame.register(operands.dst).int = frame.register(operands.src1).int << @intCast(frame.register(operands.src2).int & MASK);
            frame.setRegisterTag(operands.dst, .Int);
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

                runtimeError(state, RuntimeError.InvalidBitShiftAmount, ErrorSeverity.Warning, message);
            }

            frame.register(operands.dst).actualValue = frame.register(operands.src1).actualValue >> @intCast(frame.register(operands.src2).actualValue & MASK);
            frame.setRegisterTag(operands.dst, .Int);
        },
        .FloatMathExt => {
            const operands = bytecode.decode(Bytecode.OperandsMathExt);
            assert(frame.registerTag(operands.src) == .Float);

            const result: f64 = blk: {
                switch (operands.op) {
                    .Sqrt => {
                        const num = frame.register(operands.src).float;

                        if (num < 0) {
                            const message = allocPrintZ(allocator(), "Cannot get square root of negative number [{}]", .{num}) catch {
                                @panic("Script out of memory");
                            };
                            defer allocator().free(message);

                            runtimeError(state, RuntimeError.NegativeRoot, ErrorSeverity.Error, message);
                            return FatalScriptError.NegativeRoot; // TODO figure out how to free all the memory and resources allocated in the callstack
                        }
                        break :blk @sqrt(num);
                    },
                    .LogE => {
                        const num = frame.register(operands.src).float;
                        if (num <= 0) {
                            const message = allocPrintZ(allocator(), "Logarithm of value [{}] is undefined. Base e.", .{num}) catch {
                                @panic("Script out of memory");
                            };
                            defer allocator().free(message);
                            runtimeError(state, RuntimeError.LogarithmZeroOrNegative, ErrorSeverity.Error, message);
                            return FatalScriptError.LogarithmZeroOrNegative; // TODO figure out how to free all the memory and resources allocated in the callstack
                        }
                        break :blk @log(num);
                    },
                    .Log2 => {
                        const num = frame.register(operands.src).float;
                        if (num <= 0) {
                            const message = allocPrintZ(allocator(), "Logarithm of value [{}] is undefined. Base 2.", .{num}) catch {
                                @panic("Script out of memory");
                            };
                            defer allocator().free(message);
                            runtimeError(state, RuntimeError.LogarithmZeroOrNegative, ErrorSeverity.Error, message);
                            return FatalScriptError.LogarithmZeroOrNegative; // TODO figure out how to free all the memory and resources allocated in the callstack
                        }
                        break :blk @log2(num);
                    },
                    .Log10 => {
                        const num = frame.register(operands.src).float;
                        if (num <= 0) {
                            const message = allocPrintZ(allocator(), "Logarithm of value [{}] is undefined. Base 10.", .{num}) catch {
                                @panic("Script out of memory");
                            };
                            defer allocator().free(message);
                            runtimeError(state, RuntimeError.LogarithmZeroOrNegative, ErrorSeverity.Error, message);
                            return FatalScriptError.LogarithmZeroOrNegative; // TODO figure out how to free all the memory and resources allocated in the callstack
                        }
                        break :blk @log10(num);
                    },
                    .Sin => {
                        break :blk @sin(frame.register(operands.src).float);
                    },
                    .Cos => {
                        break :blk @cos(frame.register(operands.src).float);
                    },
                    .Tan => {
                        break :blk @tan(frame.register(operands.src).float);
                    },
                    .Arcsin => {
                        const num = frame.register(operands.src).float;
                        if (num > 1 or num < -1) {
                            const message = allocPrintZ(allocator(), "Arcsin of value [{}] is undefined", .{num}) catch {
                                @panic("Script out of memory");
                            };
                            defer allocator().free(message);
                            runtimeError(state, RuntimeError.ArcsinUndefined, ErrorSeverity.Error, message);
                            return FatalScriptError.ArcsinUndefined; // TODO figure out how to free all the memory and resources allocated in the callstack
                        }
                        break :blk std.math.asin(num);
                    },
                    .Arccos => {
                        const num = frame.register(operands.src).float;
                        if (num > 1 or num < -1) {
                            const message = allocPrintZ(allocator(), "Arccos of value [{}] is undefined", .{num}) catch {
                                @panic("Script out of memory");
                            };
                            defer allocator().free(message);
                            runtimeError(state, RuntimeError.ArccosUndefined, ErrorSeverity.Error, message);
                            return FatalScriptError.ArccosUndefined; // TODO figure out how to free all the memory and resources allocated in the callstack
                        }
                        break :blk std.math.acos(num);
                    },
                    .Arctan => {
                        break :blk std.math.atan(frame.register(operands.src).float);
                    },
                    // else => {
                    //     @panic("Unsupported float math extension operation");
                    // },
                }
            };
            frame.register(operands.dst).float = result;
            frame.setRegisterTag(operands.dst, .Float);
        },
        .FloatLogWithBase => {
            const operands = bytecode.decode(Bytecode.OperandsDstTwoSrc);

            const num = frame.register(operands.src1).float;
            if (num <= 0) {
                const message = allocPrintZ(allocator(), "Cannot get logarithm of negative number or 0 [{}]", .{num}) catch {
                    @panic("Script out of memory");
                };
                defer allocator().free(message);

                runtimeError(state, RuntimeError.LogarithmZeroOrNegative, ErrorSeverity.Error, message);
                return FatalScriptError.LogarithmZeroOrNegative; // TODO figure out how to free all the memory and resources allocated in the callstack
            }

            frame.register(operands.dst).float = std.math.log(f64, frame.register(operands.src2).float, num);
            frame.setRegisterTag(operands.dst, .Float);
        },
        else => {
            @panic("OpCode not implemented");
        },
    }
    stack.instructionPointer = @ptrCast(&stack.instructionPointer[ipIncrement]);
    return true;
}

pub fn runtimeError(state: *const CubicScriptState, err: RuntimeError, severity: ErrorSeverity, message: []const u8) void {
    // Only the mutex and the data it owns are modified here, so removing the const is fine.
    const contextMutex: *Mutex = @constCast(&state._contextMutex);
    contextMutex.lock();
    defer contextMutex.unlock();

    const context: *ScriptContext = @constCast(&state._context);
    context.runtimeError(state, err, severity, message);
}

// ! TESTS

test "nop" {
    const state = CubicScriptState.init(null);
    defer state.deinit();

    const instruction = Bytecode.encode(OpCode.Nop, {});

    var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
    defer _ = frame.popFrame(&threadLocalStack);

    _ = try executeOperation(state, &threadLocalStack, &frame);
}

test "load immediate" {
    {
        const state = CubicScriptState.init(null);
        defer state.deinit();

        const instruction = Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 0, .valueTag = .Bool, .immediate = 0 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(0).boolean == false);
    }
    {
        const state = CubicScriptState.init(null);
        defer state.deinit();

        const instruction = Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 0, .valueTag = .Bool, .immediate = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(0).boolean == true);
    }
    {
        const state = CubicScriptState.init(null);
        defer state.deinit();

        const instruction = Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 0, .valueTag = .Int, .immediate = -50 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(0).int == -50);
    }
    {
        const state = CubicScriptState.init(null);
        defer state.deinit();

        const instruction = Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 0, .valueTag = .Float, .immediate = 50 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(0).float == 50);
    }
}

test "return" {
    const state = CubicScriptState.init(null);
    defer state.deinit();
    { // dont return value

        const instruction = Bytecode.encode(.Return, {});

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == false);
    }
    { // return value

        const instruction = Bytecode.encode(.Return, Bytecode.OperandsOptionalReturn{ .valueTag = ValueTag.Int.asU8(), .src = 0 });

        var outVal: RawValue = undefined;
        var outTag: u8 = undefined;
        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), .{ .val = &outVal, .tag = &outTag });
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = -30;
        frame.setRegisterTag(0, .Int);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == false);
        try expect(outTag == ValueTag.Int.asU8());
        try expect(outVal.int == -30);
    }
}

test "call" {
    const state = CubicScriptState.init(null);
    defer state.deinit();
    { // No args, no return
        var fptr: Bytecode.ScriptFunctionPtr = .{};

        const instructions = [_]Bytecode{
            Bytecode.encode(.Call, Bytecode.OperandsFunctionArgs{ .argCount = 0 }), // 0
            Bytecode.encodeCallImmediateLower(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 1
            Bytecode.encodeCallImmediateUpper(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 2
            Bytecode.encode(.Return, {}), // 3
            // Function
            Bytecode.encode(.Return, {}), // 4
        };

        fptr.bytecodeStart = @ptrCast(&instructions[4]);

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, &instructions, null);
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame); // call
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[4]);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == true); // return from call
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[3]);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == false); // return from instructions
    }
    { // No args, returns an int
        var fptr: Bytecode.ScriptFunctionPtr = .{};

        const instructions = [_]Bytecode{
            Bytecode.encode(.Call, Bytecode.OperandsFunctionArgs{ .argCount = 0, .captureReturn = true, .returnDst = 0 }), // 0
            Bytecode.encodeCallImmediateLower(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 1
            Bytecode.encodeCallImmediateUpper(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 2
            Bytecode.encode(.Return, Bytecode.OperandsOptionalReturn{ .src = 0, .valueTag = ValueTag.Int.asU8() }), // 3
            // Function
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 0, .valueTag = .Int, .immediate = -5 }), // 4
            Bytecode.encode(.Return, Bytecode.OperandsOptionalReturn{ .src = 0, .valueTag = ValueTag.Int.asU8() }), // 5
        };

        fptr.bytecodeStart = @ptrCast(&instructions[4]);

        var retVal: RawValue = undefined;
        var retTag: u8 = undefined;

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, &instructions, .{ .val = &retVal, .tag = &retTag });
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame); // call
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[4]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // load immediate
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[5]);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == true); // return immediate
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[3]);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == false); // return from instructions

        try expect(retTag == ValueTag.Int.asU8());
        try expect(retVal.int == -5);
    }
    { // 1 arg, no return
        var fptr: Bytecode.ScriptFunctionPtr = .{};

        const instructions = [_]Bytecode{
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 0, .valueTag = .Int, .immediate = 1 }), // 0
            Bytecode.encode(.Call, Bytecode.OperandsFunctionArgs{ .argCount = 1 }), // 1
            Bytecode.encodeCallImmediateLower(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 2
            Bytecode.encodeCallImmediateUpper(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 3
            Bytecode.encodeFunctionArgPair(Bytecode.FunctionArg{ .modifier = .Owned, .src = 0, .valueTag = @intFromEnum(ValueTag.Int) }, null), // 4
            Bytecode.encode(.Return, {}), // 5
            // Function
            Bytecode.encode(.Return, {}), // 6
        };

        fptr.bytecodeStart = @ptrCast(&instructions[6]);

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, &instructions, null);
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame); // load immediate
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[1]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // call
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[6]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // return
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[5]);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == false); // return
    }
    { // 2 arg, no return
        var fptr: Bytecode.ScriptFunctionPtr = .{};

        const instructions = [_]Bytecode{
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 0, .valueTag = .Int, .immediate = 1 }), // 0
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 1, .valueTag = .Int, .immediate = 2 }), // 1
            Bytecode.encode(.Call, Bytecode.OperandsFunctionArgs{ .argCount = 2 }), // 2
            Bytecode.encodeCallImmediateLower(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 3
            Bytecode.encodeCallImmediateUpper(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 4
            Bytecode.encodeFunctionArgPair(
                Bytecode.FunctionArg{ .modifier = .Owned, .src = 0, .valueTag = @intFromEnum(ValueTag.Int) },
                Bytecode.FunctionArg{ .modifier = .Owned, .src = 1, .valueTag = @intFromEnum(ValueTag.Int) },
            ), // 5
            Bytecode.encode(.Return, {}), // 6
            // Function
            Bytecode.encode(.Return, {}), // 7
        };

        fptr.bytecodeStart = @ptrCast(&instructions[7]);

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, &instructions, null);
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame); // load immediate 0
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[1]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // load immediate 1
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[2]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // call
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[7]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // return
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[6]);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == false); // return
    }
    { // 3 arg, no return
        var fptr: Bytecode.ScriptFunctionPtr = .{};

        const instructions = [_]Bytecode{
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 0, .valueTag = .Int, .immediate = 1 }), // 0
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 1, .valueTag = .Int, .immediate = 2 }), // 1
            Bytecode.encode(.LoadImmediate, Bytecode.OperandsImmediate{ .dst = 2, .valueTag = .Int, .immediate = 3 }), // 2
            Bytecode.encode(.Call, Bytecode.OperandsFunctionArgs{ .argCount = 3 }), // 3
            Bytecode.encodeCallImmediateLower(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 4
            Bytecode.encodeCallImmediateUpper(Bytecode.CallImmediate.initScriptFunctionPtr(&fptr)), // 5
            Bytecode.encodeFunctionArgPair(
                Bytecode.FunctionArg{ .modifier = .Owned, .src = 0, .valueTag = @intFromEnum(ValueTag.Int) },
                Bytecode.FunctionArg{ .modifier = .Owned, .src = 1, .valueTag = @intFromEnum(ValueTag.Int) },
            ), // 6
            Bytecode.encodeFunctionArgPair(
                Bytecode.FunctionArg{ .modifier = .Owned, .src = 2, .valueTag = @intFromEnum(ValueTag.Int) },
                null,
            ), // 7
            Bytecode.encode(.Return, {}), // 8
            // Function
            Bytecode.encode(.Return, {}), // 9
        };

        fptr.bytecodeStart = @ptrCast(&instructions[9]);

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, &instructions, null);
        defer _ = frame.popFrame(&threadLocalStack);

        _ = try executeOperation(state, &threadLocalStack, &frame); // load immediate 0
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[1]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // load immediate 1
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[2]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // load immediate 2
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[3]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // call
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[9]);

        _ = try executeOperation(state, &threadLocalStack, &frame); // return
        try expect(&threadLocalStack.instructionPointer[0] == &instructions[8]);

        try expect((try executeOperation(state, &threadLocalStack, &frame)) == false); // return
    }
}

test "int comparisons" {
    const IntComparisonTester = struct {
        fn intCompare(state: *const CubicScriptState, opcode: OpCode, src1Value: i64, src2Value: i64, shouldBeTrue: bool) !void {
            const instruction = Bytecode.encode(opcode, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

            var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
            defer _ = frame.popFrame(&threadLocalStack);

            frame.register(0).int = src1Value;
            frame.setRegisterTag(0, .Int);
            frame.register(1).int = src2Value;
            frame.setRegisterTag(1, .Int);

            _ = try executeOperation(state, &threadLocalStack, &frame);

            if (shouldBeTrue) {
                try expect(frame.register(2).boolean == true);
            } else {
                try expect(frame.register(2).boolean == false);
            }
        }
    };

    {
        const state = CubicScriptState.init(null);
        defer state.deinit();

        try IntComparisonTester.intCompare(state, OpCode.Equal, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, OpCode.Equal, math.MAX_INT, 123456789, false);

        try IntComparisonTester.intCompare(state, OpCode.NotEqual, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, OpCode.NotEqual, math.MAX_INT, 123456789, true);

        try IntComparisonTester.intCompare(state, OpCode.Less, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, OpCode.Less, math.MAX_INT, 123456789, false);
        try IntComparisonTester.intCompare(state, OpCode.Less, -1, math.MAX_INT, true);

        try IntComparisonTester.intCompare(state, OpCode.Greater, math.MAX_INT, math.MAX_INT, false);
        try IntComparisonTester.intCompare(state, OpCode.Greater, math.MAX_INT, 123456789, true);
        try IntComparisonTester.intCompare(state, OpCode.Greater, -1, math.MAX_INT, false);

        try IntComparisonTester.intCompare(state, OpCode.LessOrEqual, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, OpCode.LessOrEqual, math.MAX_INT, 123456789, false);
        try IntComparisonTester.intCompare(state, OpCode.LessOrEqual, -1, math.MAX_INT, true);

        try IntComparisonTester.intCompare(state, OpCode.GreaterOrEqual, math.MAX_INT, math.MAX_INT, true);
        try IntComparisonTester.intCompare(state, OpCode.GreaterOrEqual, math.MAX_INT, 123456789, true);
        try IntComparisonTester.intCompare(state, OpCode.GreaterOrEqual, -1, math.MAX_INT, false);
    }
}

/// Used for testing to validate that certain errors happened.
fn ScriptTestingContextError(comptime ErrTag: RuntimeError) type {
    return struct {
        shouldExpectError: bool,
        didErrorHappen: bool = false,

        fn errorCallback(self: *@This(), _: *const CubicScriptState, err: RuntimeError, _: ErrorSeverity, _: [*c]const u8, _: usize) callconv(.C) void {
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

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Add, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = 10;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 1;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == 11);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.AdditionIntegerOverflow){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Add, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = math.MAX_INT;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 1;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == math.MIN_INT);
    }
}

test "int subtraction" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.SubtractionIntegerOverflow){ .shouldExpectError = false };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Subtract, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = 10;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 1;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == 9);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.SubtractionIntegerOverflow){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Subtract, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = math.MIN_INT;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 1;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == math.MAX_INT);
    }
}

test "int multiplication" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.MultiplicationIntegerOverflow){ .shouldExpectError = false };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Multiply, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = math.MAX_INT;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 1;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == math.MAX_INT);
    }
    { // validate integer overflow is reported
        var contextObject = ScriptTestingContextError(RuntimeError.MultiplicationIntegerOverflow){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Multiply, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = math.MAX_INT;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 2;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == -2);
    }
}

test "int division truncation" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = false };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Divide, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = -5;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 2;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == -2);
    }
    { // validate integer overflow
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Divide, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = math.MIN_INT;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = -1;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == math.MIN_INT);
    }
    { // validate divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.DivideByZero){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Divide, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = 1;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 0;
        frame.setRegisterTag(1, .Int);

        if (executeOperation(state, &threadLocalStack, &frame)) |_| {
            try expect(false);
        } else |err| {
            try expect(err == FatalScriptError.DivideByZero);
        }
    }
}

test "int division floor" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = false };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.DivideFloor, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = -5;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 2;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == -3);
    }
    { // validate integer overflow
        var contextObject = ScriptTestingContextError(RuntimeError.DivisionIntegerOverflow){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.DivideFloor, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = math.MIN_INT;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = -1;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == math.MIN_INT);
    }
    { // validate divide by zero
        var contextObject = ScriptTestingContextError(RuntimeError.DivideByZero){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.DivideFloor, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = 1;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 0;
        frame.setRegisterTag(1, .Int);

        if (executeOperation(state, &threadLocalStack, &frame)) |_| {
            try expect(false);
        } else |err| {
            try expect(err == FatalScriptError.DivideByZero);
        }
    }
}

test "int modulo" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.ModuloByZero){ .shouldExpectError = false };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Modulo, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = -5;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 2;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == 1);
    }
    { // validate modulo by zero
        var contextObject = ScriptTestingContextError(RuntimeError.ModuloByZero){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Modulo, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = 1;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 0;
        frame.setRegisterTag(1, .Int);

        if (executeOperation(state, &threadLocalStack, &frame)) |_| {
            try expect(false);
        } else |err| {
            try expect(err == FatalScriptError.ModuloByZero);
        }
    }
}

test "int remainder" {
    { // normal
        var contextObject = ScriptTestingContextError(RuntimeError.RemainderByZero){ .shouldExpectError = false };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Remainder, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = -5;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 2;
        frame.setRegisterTag(1, .Int);

        _ = try executeOperation(state, &threadLocalStack, &frame);

        try expect(frame.register(2).int == -1);
    }
    { // validate modulo by zero
        var contextObject = ScriptTestingContextError(RuntimeError.RemainderByZero){ .shouldExpectError = true };

        const state = CubicScriptState.init(contextObject.asContext());
        defer state.deinit();

        const instruction = Bytecode.encode(OpCode.Remainder, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 });

        var frame = try StackFrame.pushFrame(&threadLocalStack, 256, @ptrCast(&instruction), null);
        defer _ = frame.popFrame(&threadLocalStack);

        frame.register(0).int = 1;
        frame.setRegisterTag(0, .Int);
        frame.register(1).int = 0;
        frame.setRegisterTag(1, .Int);

        if (executeOperation(state, &threadLocalStack, &frame)) |_| {
            try expect(false);
        } else |err| {
            try expect(err == FatalScriptError.RemainderByZero);
        }
    }
}

// test "int power" {
//     { // normal
//         var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = false };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const src1: i64 = -5;

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, src1),
//             Bytecode.encodeImmediateUpper(i64, src1),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 2),
//             Bytecode.encodeImmediateUpper(i64, 2),
//             Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 25);
//     }
//     { // normal
//         var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = false };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const src1: i64 = -5;

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, src1),
//             Bytecode.encodeImmediateUpper(i64, src1),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, -2),
//             Bytecode.encodeImmediateUpper(i64, -2),
//             Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 0);
//     }
//     { // overflow
//         var contextObject = ScriptTestingContextError(RuntimeError.PowerIntegerOverflow){ .shouldExpectError = true };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, math.MAX_INT),
//             Bytecode.encodeImmediateUpper(i64, math.MAX_INT),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 2),
//             Bytecode.encodeImmediateUpper(i64, 2),
//             Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);
//     }
//     { // 0 to the power of negative error
//         var contextObject = ScriptTestingContextError(RuntimeError.ZeroToPowerOfNegative){ .shouldExpectError = true };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 0),
//             Bytecode.encodeImmediateUpper(i64, 0),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, -2),
//             Bytecode.encodeImmediateUpper(i64, -2),
//             Bytecode.encode(OpCode.IntPower, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         if (state.run(&instructions)) |_| {
//             try expect(false);
//         } else |err| {
//             _ = err catch {};
//         }
//     }
// }

// test "bitwise complement" {
//     {
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encode(OpCode.BitwiseComplement, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).int == -1);
//     }
//     {
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const src1: i64 = 1;

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, src1),
//             Bytecode.encodeImmediateUpper(i64, src1),
//             Bytecode.encode(OpCode.BitwiseComplement, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).int == -2);
//     }
// }

// test "bitwise and" {
//     {
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 0b011),
//             Bytecode.encodeImmediateUpper(i64, 0b011),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 0b110),
//             Bytecode.encodeImmediateUpper(i64, 0b110),
//             Bytecode.encode(OpCode.BitwiseAnd, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 0b010);
//     }
// }

// test "bitwise or" {
//     {
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 0b011),
//             Bytecode.encodeImmediateUpper(i64, 0b011),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 0b110),
//             Bytecode.encodeImmediateUpper(i64, 0b110),
//             Bytecode.encode(OpCode.BitwiseOr, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 0b111);
//     }
// }

// test "bitwise xor" {
//     {
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 0b011),
//             Bytecode.encodeImmediateUpper(i64, 0b011),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 0b110),
//             Bytecode.encodeImmediateUpper(i64, 0b110),
//             Bytecode.encode(OpCode.BitwiseXor, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 0b101);
//     }
// }

// test "bitshift left" {
//     {
//         var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, -1),
//             Bytecode.encodeImmediateUpper(i64, -1),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 1),
//             Bytecode.encodeImmediateUpper(i64, 1),
//             Bytecode.encode(OpCode.BitShiftLeft, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == -2);
//     }
//     {
//         var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, -1),
//             Bytecode.encodeImmediateUpper(i64, -1),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
//             Bytecode.encodeImmediateUpper(i64, 65),
//             Bytecode.encode(OpCode.BitShiftLeft, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == -2);
//     }
// }

// test "bitshift arithmetic right" {
//     {
//         var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 0b110),
//             Bytecode.encodeImmediateUpper(i64, 0b110),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 1),
//             Bytecode.encodeImmediateUpper(i64, 1),
//             Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 0b011);
//     }
//     { // retain sign bit
//         var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, -1),
//             Bytecode.encodeImmediateUpper(i64, -1),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 1),
//             Bytecode.encodeImmediateUpper(i64, 1),
//             Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == -1);
//     }
//     {
//         var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 0b110),
//             Bytecode.encodeImmediateUpper(i64, 0b110),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
//             Bytecode.encodeImmediateUpper(i64, 65),
//             Bytecode.encode(OpCode.BitArithmeticShiftRight, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 0b011);
//     }
// }

// test "bitshift logical right" {
//     {
//         var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 0b110),
//             Bytecode.encodeImmediateUpper(i64, 0b110),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 1),
//             Bytecode.encodeImmediateUpper(i64, 1),
//             Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 0b011);
//     }
//     { // dont retain sign bit
//         var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = false };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, -1),
//             Bytecode.encodeImmediateUpper(i64, -1),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 1),
//             Bytecode.encodeImmediateUpper(i64, 1),
//             Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == math.MAX_INT);
//     }
//     {
//         var contextObject = ScriptTestingContextError(RuntimeError.InvalidBitShiftAmount){ .shouldExpectError = true };

//         const state = CubicScriptState.init(contextObject.asContext());
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 0b110),
//             Bytecode.encodeImmediateUpper(i64, 0b110),
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 1 }),
//             Bytecode.encodeImmediateLower(i64, 65), // when masked by 0b111111, the resulting value is just 1
//             Bytecode.encodeImmediateUpper(i64, 65),
//             Bytecode.encode(OpCode.BitLogicalShiftRight, Bytecode.OperandsDstTwoSrc{ .dst = 2, .src1 = 0, .src2 = 1 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(2).int == 0b011);
//     }
// }

// test "int to bool" {
//     { // 0 -> false
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).boolean == false);
//     }
//     { // 1 -> true
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 1),
//             Bytecode.encodeImmediateUpper(i64, 1),
//             Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).boolean == true);
//     }
//     { // non-zero -> true
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 33),
//             Bytecode.encodeImmediateUpper(i64, 33),
//             Bytecode.encode(OpCode.IntToBool, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).boolean == true);
//     }
// }

// test "int to float" {
//     { // 0
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).float == 0.0);
//     }
//     { // 1
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 1),
//             Bytecode.encodeImmediateUpper(i64, 1),
//             Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).float == 1.0);
//     }
//     { // -1
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, -1),
//             Bytecode.encodeImmediateUpper(i64, -1),
//             Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).float == -1.0);
//     }
//     { // arbitrary value
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, -2398712938),
//             Bytecode.encodeImmediateUpper(i64, -2398712938),
//             Bytecode.encode(OpCode.IntToFloat, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).float == -2398712938.0);
//     }
// }

// test "int to string" {
//     { // 0
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).string.eqlSlice("0"));
//         frame.register(1).string.deinit();
//     }
//     { // 1
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, 1),
//             Bytecode.encodeImmediateUpper(i64, 1),
//             Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).string.eqlSlice("1"));
//         frame.register(1).string.deinit();
//     }
//     { // -1
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, -1),
//             Bytecode.encodeImmediateUpper(i64, -1),
//             Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).string.eqlSlice("-1"));
//         frame.register(1).string.deinit();
//     }
//     { // arbitrary value
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(i64, -2398712938),
//             Bytecode.encodeImmediateUpper(i64, -2398712938),
//             Bytecode.encode(OpCode.IntToString, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).string.eqlSlice("-2398712938"));
//         frame.register(1).string.deinit();
//     }
// }

// test "bool not" {
//     {
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadZero, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encode(OpCode.BoolNot, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).boolean == true);
//     }
//     {
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(bool, true),
//             Bytecode.encodeImmediateUpper(bool, true),
//             Bytecode.encode(OpCode.BoolNot, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).boolean == false);
//     }
// }

// test "bool to string" {
//     { // true
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(bool, true),
//             Bytecode.encodeImmediateUpper(bool, true),
//             Bytecode.encode(OpCode.BoolToString, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).string.eqlSlice("true"));
//         frame.register(1).string.deinit();
//     }
//     { // false
//         const state = CubicScriptState.init(null);
//         defer state.deinit();

//         const instructions = [_]Bytecode{
//             Bytecode.encode(OpCode.LoadImmediateLong, Bytecode.OperandsOnlyDst{ .dst = 0 }),
//             Bytecode.encodeImmediateLower(bool, false),
//             Bytecode.encodeImmediateUpper(bool, false),
//             Bytecode.encode(OpCode.BoolToString, Bytecode.OperandsDstSrc{ .dst = 1, .src = 0 }),
//         };

//         _ = try state.run(&instructions);

//         var frame = StackFrame.pushFrame(&threadLocalStack, 256, 0, null) catch unreachable;
//         defer _ = frame.popFrame(&threadLocalStack);
//         try expect(frame.register(1).string.eqlSlice("false"));
//         frame.register(1).string.deinit();
//     }
// }
