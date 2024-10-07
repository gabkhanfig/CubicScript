#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <assert.h>

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#endif // WIN32 def

// https://en.wikipedia.org/wiki/Find_first_set

inline static bool countTrailingZeroes32(uint32_t* out, uint32_t mask) {
#if defined(_WIN32) || defined(WIN32)
    _Static_assert(sizeof(uint32_t) == sizeof(unsigned long), "On Win32, uint32_t should have the same size as unsigned long");
    return _BitScanForward((unsigned long*)out, mask);
#elif __GNUC__
    if(mask == 0) {
        return false;
    }
    *out = (uint32_t)__builtin_ctz(mask);
    return true;
#else
_Static_assert(false, "count trailing zeroes 32 bit not implemented")
#endif
}

inline static bool countTrailingZeroes64(uint32_t* out, uint64_t mask) {
#if defined(_WIN32) || defined(WIN32)
    _Static_assert(sizeof(uint64_t) == sizeof(unsigned long long), "On Win32, uint64_t should have the same size as unsigned long long");
    return _BitScanForward64((unsigned long*)out, mask);
#elif __GNUC__
    if(mask == 0) {
        return false;
    }
    *out = (uint32_t)__builtin_ctzll(mask);
    return true;
#else
_Static_assert(false, "count trailing zeroes 64 bit not implemented")
#endif
}