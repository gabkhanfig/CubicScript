#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#endif // WIN32 def

#include <immintrin.h>
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

static size_t calculateAvx512IterationsCount(size_t length) {
	return ((length) % 64 == 0 ?
		length :
		length + (64 - (length % 64)))
		/ 64;
}

static size_t calculateAvx2IterationsCount(size_t length) {
	return ((length) % 32 == 0 ?
		length :
		length + (32 - (length % 32)))
		/ 32;
}

bool avx512CompareEqualStringAndString(const char* buffer, const char* otherBuffer, size_t len) {
    // both are 64 byte aligned
    const size_t equal64Bitmask = ~0;
    const __m512i* thisVec = (const __m512i*)buffer;
    const __m512i* otherVec = (const __m512i*)otherBuffer;

    const size_t remainder = (len + 1) % 64; // add one for null terminator
    const size_t bytesToCheck = remainder ? ((len + 1) + (64 - remainder)) : len + 1;
    for(size_t i = 0; i < bytesToCheck; i += 64) {
        if(_mm512_cmpeq_epi8_mask(*thisVec, *otherVec) != equal64Bitmask) return false;
        thisVec++;
        otherVec++;
    }
    return true;
}

bool avx2CompareEqualStringAndString(const char* buffer, const char* otherBuffer, size_t len) {
    // both are 32 byte aligned
    const unsigned int equal32Bitmask = ~0;
    const __m256i* thisVec = (const __m256i*)buffer;
    const __m256i* otherVec = (const __m256i*)otherBuffer;

    const size_t remainder = (len + 1) % 32; // add one for null terminator
    const size_t bytesToCheck = remainder ? ((len + 1) + (32 - remainder)) : len + 1;
    for(size_t i = 0; i < bytesToCheck; i += 32) {
        if(_mm256_cmpeq_epi8_mask(*thisVec, *otherVec) != equal32Bitmask) return false;
        thisVec++;
        otherVec++;
    }
    return true;
}

bool avx512CompareEqualStringAndSlice(const char* buffer, const char* sliceBuffer, size_t len) {
    const size_t equal64Bitmask = ~0;
    const __m512i* thisVec = (const __m512i*)buffer;
    // https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html#text=_mm512_movm_epi8&ig_expand=1008,306,307,285,4083,5807,4633
    // Maybe faster than _mm512_set1_epi8 ?
    __m512i otherVec; // initializing the memory is unnecessary = _mm512_movm_epi8(0);

    size_t i = 0;
    if(len >= 64) { // This works. Is there a better way to do this though?
        for(; i <= (len - 64); i += 64) {
            memset(&otherVec, 0, 64);
            memcpy(&otherVec, sliceBuffer + i, 64);
            if (_mm512_cmpeq_epi8_mask(*thisVec, otherVec) != equal64Bitmask) {
                return false;
            }
            thisVec++;
        }
    }
     
    for(; i < len; i++) {
        if(buffer[i] != sliceBuffer[i]) return false;
    }
    return true;
}

bool avx2CompareEqualStringAndSlice(const char* buffer, const char* sliceBuffer, size_t len) {
    const unsigned int equal32Bitmask = ~0;
    const __m256i* thisVec = (const __m256i*)buffer;
    __m256i otherVec; // initializing the memory is unnecessary

    size_t i = 0;
    for(; i <= (len - 32); i += 32) {
		memcpy(&otherVec, sliceBuffer + i, 32);
		if (_mm256_cmpeq_epi8_mask(*thisVec, otherVec) != equal32Bitmask) return false;
		thisVec++;
    }


    for(; i < len; i++) {
        if(buffer[i] != sliceBuffer[i]) return false;
    }
    return true;
}

static __m256i stringHashIteration(const __m256i* vec, char num) {
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

size_t avx512FindStrSliceInString(const char* buffer, size_t length, const char* sliceBuffer, size_t sliceLength) {
    const size_t NOT_FOUND = ~0ULL;

    const __m512i firstChar = _mm512_set1_epi8(sliceBuffer[0]);
    const __m512i* vecThis = (const __m512i*)(buffer);

    const size_t iterationsToDo = calculateAvx512IterationsCount(length);
       
    for(size_t i = 0; i < iterationsToDo; i++) {
		// First, try to find the first character within the string buffer.
        size_t bitmask = _mm512_cmpeq_epi8_mask(firstChar, *vecThis);

        while(true) {
            unsigned long index;
            #if defined(_WIN32) || defined(WIN32)
            if(!_BitScanForward64(&index, bitmask)) {
                break;
            }
            #endif
            bitmask = (bitmask & ~(1ULL << index));

            const size_t actualIndex = index + (i * 64);
            if((length - index) < sliceLength) return NOT_FOUND;

            bool found = true;
            for(size_t j = 0; j < sliceLength; j++) {
                if(buffer[actualIndex + j] != sliceBuffer[j]) {
                    found = false;
                    break;
                }
            }

            if(found) {
                return actualIndex;
            }
        }

        vecThis++;
    }

    return NOT_FOUND;
}

size_t cubs_string_compute_hash_simd(const char* selfBuffer, size_t len) {
    const size_t HASH_MODIFIER = 0xc6a4a7935bd1e995ULL;
	const size_t HASH_SHIFT = 47;

    size_t h = 0;

    if (len < 16) { // SSO rep has a maximum length of 15
		h = 0 ^ (len * HASH_MODIFIER);
		const __m256i thisVec = _mm256_loadu_epi8((const void*)selfBuffer);
		const __m256i hashIter = stringHashIteration(&thisVec, (char)(len));
        const size_t* hashPtr = (const size_t*)(&hashIter);

		for (size_t i = 0; i < 4; i++) {
			h ^= hashPtr[i];
			h *= HASH_MODIFIER;
			h ^= h >> HASH_SHIFT;
		}
	}
	else {
		h = 0 ^ (len * HASH_MODIFIER);

		const size_t iterationsToDo = ((len) % 32 == 0 ?
			len :
			len + (32 - (len % 32)))
			/ 32;

            
		const __m256i* thisVec = (const __m256i*)(selfBuffer);

		for (size_t i = 0; i < iterationsToDo; i++) {
			const char num = i != (iterationsToDo - 1) ? (char)(32) : (char)((iterationsToDo * i) - len);
			//check_le(num, 32);
			const __m256i hashIter = stringHashIteration(thisVec + i, num);
            const size_t* hashPtr = (const size_t*)(&hashIter);

			for (size_t j = 0; j < 4; j++) {
			    h ^= hashPtr[i];
				h *= HASH_MODIFIER;
				h ^= h >> HASH_SHIFT;
			}
		}
	}

    h ^= h >> HASH_SHIFT;
	h *= HASH_MODIFIER;
	h ^= h >> HASH_SHIFT;
	return h;
}



