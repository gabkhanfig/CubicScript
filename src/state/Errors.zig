pub const RuntimeError = enum(c_int) {
    NullDereference,
    AdditionIntegerOverflow,
    SubtractionIntegerOverflow,
    MultiplicationIntegerOverflow,
    DivisionIntegerOverflow,
    DivideByZero,
    ModuloByZero,
    RemainderByZero,
    PowerIntegerOverflow,
    ZeroToPowerOfNegative,
    InvalidBitShiftAmount,
};

pub const Severity = enum(c_int) {
    Warning,
    Error,
    Fatal,
};
