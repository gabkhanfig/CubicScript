#pragma once

typedef enum CubsProgramRuntimeError {
    cubsProgramRuntimeErrorNone = 0,
    cubsProgramRuntimeErrorNullDereference = 1,
    cubsProgramRuntimeErrorIncrementIntegerOverflow = 2,
    cubsProgramRuntimeErrorAdditionIntegerOverflow = 3,
    cubsProgramRuntimeErrorSubtractionIntegerOverflow = 4,
    cubsProgramRuntimeErrorMultiplicationIntegerOverflow = 5,
    cubsProgramRuntimeErrorDivisionIntegerOverflow = 6,
    cubsProgramRuntimeErrorDivideByZero = 7,
    cubsProgramRuntimeErrorModuloByZero = 8,
    cubsProgramRuntimeErrorRemainderByZero = 9,
    cubsProgramRuntimeErrorPowerIntegerOverflow = 10,
    cubsProgramRuntimeErrorZeroToPowerOfNegative = 11,
    cubsProgramRuntimeErrorInvalidBitShiftAmount = 12,
    cubsProgramRuntimeErrorFloatToIntOverflow = 13,
    cubsProgramRuntimeErrorNegativeRoot = 14,
    cubsProgramRuntimeErrorLogarithmZeroOrNegative = 15,
    cubsProgramRuntimeErrorArcsinUndefined = 16,
    cubsProgramRuntimeErrorArccosUndefined = 17,
    cubsProgramRuntimeErrorHyperbolicArccosUndefined = 18,
    cubsProgramRuntimeErrorHyperbolicArctanUndefined = 19,

    _CUBS_PROGRAM_RUNTIME_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsProgramRuntimeError;