pub const RuntimeError = enum(c_int) {
    NullDereference = 0,
    AdditionIntegerOverflow = 1,
    SubtractionIntegerOverflow = 2,
    MultiplicationIntegerOverflow = 3,
    DivisionIntegerOverflow = 4,
    DivideByZero = 5,
    ModuloByZero = 6,
    RemainderByZero = 7,
    PowerIntegerOverflow = 8,
    ZeroToPowerOfNegative = 9,
    InvalidBitShiftAmount = 10,
    FloatToIntOverflow = 11,
};

pub const Severity = enum(c_int) {
    /// Script execution will continue.
    Warning = 0,
    /// Script execution cannot continue.
    Error = 1,
};
