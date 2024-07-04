#include "simd.h"
#include <assert.h>
#include "bitwise.h"

#if __AVX2__
#include <immintrin.h>
#endif

#define assert_aligned(ptr, alignment) assert((((uintptr_t)ptr) % alignment == 0) && "Pointer not properly aligned");

bool _cubs_simd_index_of_first_zero_8bit_32wide_aligned(size_t *out, const uint8_t *alignedPtr)
{
    assert_aligned(alignedPtr, 32);

    #if __AVX2__
    const __m256i zeroVec = _mm256_set1_epi8(0);
    const __m256i buf = *(const __m256i*)alignedPtr;
    const __m256i result = _mm256_cmpeq_epi8(zeroVec, buf);
    int resultMask = _mm256_movemask_epi8(result);
    uint32_t index;
    if(!countTrailingZeroes32(&index, resultMask)) {
        return false;
    }
    *out = (size_t)index;
    return true;
    #else
    _Static_assert(false, "first zero not implemented for target architecture");
    #endif
    return false;
}

uint32_t _cubs_simd_cmpeq_mask_8bit_32wide_aligned(uint8_t value, const uint8_t *alignedCompare)
{
    assert_aligned(alignedCompare, 32);

    #if __AVX2__
    const __m256i valueToFind = _mm256_set1_epi8(value);
    const __m256i bufferToSearch = *(const __m256i*)alignedCompare;
    const __m256i result = _mm256_cmpeq_epi8(valueToFind, bufferToSearch);
    int mask = _mm256_movemask_epi8(result);
    return (uint32_t)mask;
    #else
    _Static_assert(false, "cmpeq mask not implemented for target architecture");
    #endif
}
