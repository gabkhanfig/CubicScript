pub const RuntimeError = enum(c_int) {
    NullDereference,
    AdditionIntegerOverflow,
    SubtractionIntegerOverflow,
    MultiplicationIntegerOverflow,
    DivideByZero,
    ModuloByZero,
};

pub const Severity = enum(c_int) {
    Warning,
    Error,
    Fatal,
};
