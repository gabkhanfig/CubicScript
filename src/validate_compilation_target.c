#include <stddef.h>

_Static_assert(sizeof(void*) == 8, "CubicScript is only compatible with 64 bit systems");
_Static_assert(sizeof(size_t) == sizeof(void*), "CubicScript requires a system with non-segmented addressing");

//! JUST IN CASE THIS IS USEFUL

// #include <stdbool.h>

// #if defined(_WIN32) || defined(WIN32)

// #define NOMINMAX
// #define WIN32_LEAN_AND_MEAN
// #include <windows.h>

// #endif // WIN32 def

// #ifdef CUBS_X86_64

// bool is_avx512f_supported() {
// #if defined(_WIN32) || defined(WIN32)
// 	return IsProcessorFeaturePresent(PF_AVX512F_INSTRUCTIONS_AVAILABLE);
// #endif
// }

// bool is_avx2_supported() {
// #if defined(_WIN32) || defined(WIN32)
// 	return IsProcessorFeaturePresent(PF_AVX2_INSTRUCTIONS_AVAILABLE);
// #endif
// }

// #endif // CUBS_X86_64