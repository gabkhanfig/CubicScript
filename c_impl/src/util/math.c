#include "math.h"

bool cubs_math_would_add_overflow(int64_t a, int64_t b)
{
    if(a >= 0) {
        if(b > (INT64_MAX) - a) {
            return true;
        }
    }else  {
        if(b < (INT64_MIN - a)) {
            return true;
        }
    }
}

bool cubs_math_would_sub_overflow(int64_t a, int64_t b)
{
    if((b > 0) && (a < (INT64_MIN + b))) {
        return true;
    }
    if ((b < 0) && (a > (INT64_MAX + b))) {
        return true;
    }
    return false;
}

bool cubs_math_would_mul_overflow(int64_t a, int64_t b) 
{
    if(a == INT64_MIN && b == -1) {
        return true;
    }
    if(a == -1 && b == INT64_MIN) {
        return true;
    }
    if(b > 0) {
        if((a > (INT64_MAX / b)) || (a < (INT64_MIN / b))) {
            return true;
        }
    }
    else if(b < 0) {
        if((a < (INT64_MAX / b)) || (a > (INT64_MIN / b))) {
            return true;
        }
    }
    return false;
}

bool cubs_math_ipow_overflow(int64_t *out, int64_t base, int64_t exp)
{
    bool didOverflow = false;
    int64_t baseLoop = base;
    int64_t expLoop = exp;
    int64_t accumulate = 1;
    while (expLoop > 1) {
        if (expLoop & 1 == 1) {
            if(cubs_math_would_mul_overflow(accumulate, baseLoop)) {
                didOverflow = true;
            }
            accumulate = accumulate * baseLoop;
        }

        expLoop >>= 1;
        {
            if(cubs_math_would_mul_overflow(baseLoop, baseLoop)) {
                didOverflow = true;
            }
            baseLoop = baseLoop * baseLoop;
        }
    }

    if (expLoop == 1) {
        if(cubs_math_would_mul_overflow(accumulate, baseLoop)) {
            didOverflow = true;
        }
        accumulate = accumulate * baseLoop;
    }
    (*out) = accumulate;
    return didOverflow;
}
