#pragma once

typedef enum CubsProgramRuntimeError {
    cubsProgramRuntimeErrorNone = 0,
    cubsProgramRuntimeErrorNullDereference = 1,
    cubsProgramRuntimeErrorAdditionIntegerOverflow = 2,
    cubsProgramRuntimeErrorSubtractionIntegerOverflow = 3,
    cubsProgramRuntimeErrorMultiplicationIntegerOverflow = 4,
    cubsProgramRuntimeErrorDivisionIntegerOverflow = 5,
    cubsProgramRuntimeErrorDivideByZero = 6,
    cubsProgramRuntimeErrorModuloByZero = 7,
    cubsProgramRuntimeErrorRemainderByZero = 8,
    cubsProgramRuntimeErrorPowerIntegerOverflow = 9,
    cubsProgramRuntimeErrorZeroToPowerOfNegative = 10,
    cubsProgramRuntimeErrorInvalidBitShiftAmount = 11,
    cubsProgramRuntimeErrorFloatToIntOverflow = 12,
    cubsProgramRuntimeErrorNegativeRoot = 13,
    cubsProgramRuntimeErrorLogarithmZeroOrNegative = 14,
    cubsProgramRuntimeErrorArcsinUndefined = 15,
    cubsProgramRuntimeErrorArccosUndefined = 16,
    cubsProgramRuntimeErrorHyperbolicArccosUndefined = 17,
    cubsProgramRuntimeErrorHyperbolicArctanUndefined = 18,

    _CUBS_PROGRAM_RUNTIME_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsProgramRuntimeError;