pub const RuntimeError = enum(c_uint) {
    NullDereference,
    AdditionIntegerOverflow,
    SubtractionIntegerOverflow,
    MultiplicationIntegerOverflow,
    DivideByZero,
    ModuloByZero,
};

pub const Severity = enum(c_uint) {
    Warning,
    Error,
    Fatal,
};
