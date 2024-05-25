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
#endif // WIN32 def
}

inline static bool countTrailingZeroes64(uint32_t* out, uint64_t mask) {
#if defined(_WIN32) || defined(WIN32)
    _Static_assert(sizeof(uint32_t) == sizeof(unsigned long), "On Win32, uint32_t should have the same size as unsigned long");
    return _BitScanForward64((unsigned long*)out, mask);
#endif // WIN32 def
}