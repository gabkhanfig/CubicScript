pub const RuntimeError = enum(c_int) {
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
};

pub const Severity = enum(c_int) {
    /// Script execution will continue.
    Warning = 0,
    /// Script execution cannot continue.
    Error = 1,
};

pub const FatalScriptError = error{
    StackOverflow,
    NullDereference,
    DivideByZero,
    ModuloByZero,
    RemainderByZero,
    ZeroToPowerOfNegative,
    NegativeRoot,
    LogarithmZeroOrNegative,
    ArcsinUndefined,
    ArccosUndefined,
};
