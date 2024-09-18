#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool _cubs_simd_index_of_first_zero_8bit_32wide_aligned(size_t* out, const uint8_t* alignedPtr);

bool _cubs_simd_index_of_first_zero_8bit_16wide_aligned(size_t* out, const uint8_t* alignedPtr);

uint32_t _cubs_simd_cmpeq_mask_8bit_32wide_aligned(uint8_t value, const uint8_t* alignedCompare);

uint16_t _cubs_simd_cmpeq_mask_8bit_16wide_aligned(uint8_t value, const uint8_t* alignedCompare);

bool _cubs_simd_cmpeq_strings(const char* buffer, const char* otherBuffer, size_t len);

bool _cubs_simd_cmpeq_string_slice(const char* buffer, const char* slicePtr, size_t sliceLen);

size_t _cubs_simd_string_hash_sso(const char* ssoBuffer, size_t len);

size_t _cubs_simd_string_hash_heap(const char* heapBuffer, size_t len);