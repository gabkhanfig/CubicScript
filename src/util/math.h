#pragma once

#include <stdbool.h>
#include <stdint.h>

/// Checks if the addition of `a + b` would resulting in an integer overflow
bool cubs_math_would_add_overflow(int64_t a, int64_t b);

/// Checks if the addition of `a - b` would resulting in an integer overflow
bool cubs_math_would_sub_overflow(int64_t a, int64_t b);

/// Checks if the addition of `a * b` would resulting in an integer overflow
bool cubs_math_would_mul_overflow(int64_t a, int64_t b);

/// Computes the integer power of `base` and `exp`, returning if integer overflow occurred and a wrapped around result is used.
///
/// If both of the following conditions are true, an assertion is executed:
/// - `base == 0`
/// - `exp < 0`
bool cubs_math_ipow_overflow(int64_t* out, int64_t base, int64_t exp);