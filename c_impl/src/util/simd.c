#include "simd.h"
#include <assert.h>
#include "bitwise.h"
#include "../primitives/string/string.h"
#include "hash.h"
#include <string.h>

#if __AVX2__
#include <immintrin.h>
#elif __ARM_NEON__
#include <arm_neon.h>
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
    #elif __ARM_NEON__
    uint32_t resultMask = 0;
    for(int i = 0; i < 2; i++) {
        const uint8x16_t zeroVec = {0};
        const uint8x16_t buf = *(const uint8x16_t*)(&alignedPtr[i * 16]);
        const uint8x16_t result = vceqq_u8(zeroVec, buf);
        for(int n = 0; n < 16; n++) { // TODO non scalar mask
            const int offset = (i * 16) + n;
            const bool isSet = (bool)(((const uint8_t*)&result)[n]);
            resultMask |= (((uint32_t)isSet) << offset); 
        }
    } 
    uint32_t index;
    if(!countTrailingZeroes32(&index, resultMask)) {
        return false;
    }
    *out = (size_t)index;
    return true;
    #else
    for(size_t i = 0; i < 32; i++) {
        if(alignedPtr[i] == 0) {
            *out = i;
            return true;
        }
    }
    return false;
    #endif
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
    uint32_t out = 0;
    for(size_t i = 0; i < 32; i++) {
        if(alignedCompare[i] == value) {
            out |= (1U << i);
        }
    }
    return out;
    #endif
}

bool _cubs_simd_cmpeq_strings(const char *buffer, const char *otherBuffer, size_t len)
{
    assert_aligned(buffer, 32);
    assert_aligned(otherBuffer, 32);

    #if __AVX2__
    const __m256i* thisVec = (const __m256i*)buffer;
    const __m256i* otherVec = (const __m256i*)otherBuffer;

    const size_t remainder = (len + 1) % 32; // add one for null terminator
    const size_t bytesToCheck = remainder ? ((len + 1) + (32 - remainder)) : len + 1;
    for(size_t i = 0; i < bytesToCheck; i += 32) {
        // _mm256_cmpeq_epi8_mask is an AVX512 extension
        const __m256i result = _mm256_cmpeq_epi8(*thisVec, *otherVec);
        const int mask = _mm256_movemask_epi8(result);
        if(mask == (int)~0) {
        thisVec++;
        otherVec++;
        continue;
        }
        return false;
    }
    return true;
    #else
    for(size_t i = 0; i < len; i++) {
        if(buffer[i] != otherBuffer[i]) return false;
    }
    return true;
    #endif
}

bool _cubs_simd_cmpeq_string_slice(const char *buffer, const char *slicePtr, size_t sliceLen)
{
    assert_aligned(buffer, 32);
   
    #if __AVX2__

    const __m256i* thisVec = (const __m256i*)buffer;
    __m256i otherVec; // initializing the memory is unnecessary

    size_t i = 0;
    if(sliceLen >= 32) {
        for(; i <= (sliceLen - 32); i += 32) {
        memcpy(&otherVec, slicePtr + i, 32);
        const __m256i result = _mm256_cmpeq_epi8(*thisVec, otherVec);
        const int mask = _mm256_movemask_epi8(result);
        if(mask == (int)~0) {
            thisVec++;
            continue;
        }
        return false;
        }
    }
    
    for(; i < sliceLen; i++) {
        if(buffer[i] != slicePtr[i]) return false;
    }
    return true;
    #else
    for(size_t i = 0; i < sliceLen; i++) {
        if(buffer[i] != slicePtr[i]) return false;
    }
    return true;
    #endif
}

#if __AVX2__
static __m256i string_hash_iteration(const __m256i* vec, char num) {
	// in the case of SSO, will ignore the 
	const __m256i seed = _mm256_set1_epi64x(0);
	const __m256i indices = _mm256_set_epi8(31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);
	const __m256i numVec = _mm256_set1_epi8(num);

	// Checks if num is greater than each value of indices.
	// Mask is 0xFF if greater than, and 0x00 otherwise. 
	const __m256i mask = _mm256_cmpgt_epi8(numVec, indices);
	const __m256i partial = _mm256_and_si256(*vec, mask);
	return _mm256_add_epi8(partial, numVec);
}
#else
//_Static_assert(false, "string hash not implemented for target architecture");
#endif


#define HASH_INIT() \
const size_t HASH_MODIFIER = cubs_hash_seed();\
const size_t HASH_SHIFT = 47;\
\
size_t h = 0;\
h = 0 ^ (len * HASH_MODIFIER)\

#define HASH_MERGE() \
do {\
    for (size_t i = 0; i < 4; i++) {\
        h ^= m256i_u64[i];\
        h *= HASH_MODIFIER;\
        h ^= h >> HASH_SHIFT;\
    }\
} while(false)

#define HASH_END() \
h ^= h >> HASH_SHIFT;\
h *= HASH_MODIFIER;\
h ^= h >> HASH_SHIFT

#include <stdio.h>

size_t _cubs_simd_string_hash_sso(const char *ssoBuffer, size_t len)
{
    HASH_INIT();

    #if __AVX2__

    __m256i thisVec = {0};
    memcpy((void*)&thisVec, (const void*)ssoBuffer, len);
	const __m256i hashIter = string_hash_iteration(&thisVec, (char)len);
    
    const uint64_t* m256i_u64 = (const uint64_t*)&hashIter;

    HASH_MERGE();

    #else
    // TODO actual hash
    h = cubs_combine_hash(h, len);
    for(size_t i = 0; i < len; i++) {
        const size_t modify = (size_t)ssoBuffer[i];
        h = cubs_combine_hash(modify << (8 * (i & 7)), h);
    }
    #endif
	
    HASH_END();

    return h;
}

size_t _cubs_simd_string_hash_heap(const char *heapBuffer, size_t len)
{
    assert_aligned(heapBuffer, 32);

    HASH_INIT();

    #if __AVX2__

    const size_t iterationsToDo = ((len) % 32 == 0 ?
		len :
		len + (32 - (len % 32))) / 32;

	for (size_t i = 0; i < iterationsToDo; i++) {
		const __m256i* thisVec = (const __m256i*)(heapBuffer);
		const char num = i != (iterationsToDo - 1) ? (char)(32) : (char)((iterationsToDo * i) - len);
		const __m256i hashIter = string_hash_iteration(thisVec + i, num);
        const uint64_t* m256i_u64 = (const uint64_t*)&hashIter;

		HASH_MERGE();
	}

    #else
    // TODO actual hash
    h = cubs_combine_hash(h, len);
    for(size_t i = 0; i < len; i++) {
        const size_t modify = (size_t)heapBuffer[i];
        h = cubs_combine_hash(modify << (8 * (i & 7)), h);
    }
    #endif

    HASH_END();
    return h;
}
