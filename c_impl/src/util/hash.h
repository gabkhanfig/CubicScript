#pragma once

#include <stddef.h>
#include <stdint.h>

/// Instantiated once per program call 
size_t cubs_hash_seed();

/// Combine hash values `a` and `b`. Useful when combined with `cubs_hash_seed()` to
/// seed the hash per program instantiation.
inline static size_t cubs_combine_hash(size_t a, size_t b) {
    // c++ boost hash combine for 64 bit
    const size_t h = b + 0x517cc1b727220a95ULL + ((a) & ~(0xFC00000000000000ULL)) + ((a) >> 2);
    return h;
}

typedef struct CubsHashGroupBitmask {
    size_t value;
} CubsHashGroupBitmask;

inline static CubsHashGroupBitmask cubs_hash_group_bitmask_init(size_t hashCode) {
    const size_t BITMASK = 18446744073709551488ULL;
    const CubsHashGroupBitmask group = {.value = (hashCode & BITMASK) >> 7};
    return group;
}

typedef struct CubsHashPairBitmask {
    uint8_t value;
} CubsHashPairBitmask;

inline static CubsHashPairBitmask cubs_hash_pair_bitmask_init(size_t hashCode) {
    const size_t BITMASK = 0b01111111;
    const uint8_t SET_FLAG = 0b10000000;
    const CubsHashPairBitmask pair = {.value = ((uint8_t)(hashCode & BITMASK)) | SET_FLAG};
    return pair;
}

