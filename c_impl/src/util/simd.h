#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool _cubs_simd_index_of_first_zero_8bit_32wide_aligned(size_t* out, const uint8_t* alignedPtr);

uint32_t _cubs_simd_cmpeq_mask_8bit_32wide_aligned(uint8_t value, const uint8_t* alignedCompare);