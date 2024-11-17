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

inline static size_t bytes_hash(const void* ptr, size_t len) {
    // murmurHash64A
    const size_t seed = cubs_hash_seed();
    const uint64_t m = 0xc6a4a7935bd1e995LLU;
    const int r = 47;

    uint64_t h = seed ^ (len * m);

    const uint64_t * data = (const uint64_t *)ptr;
    const uint64_t * end = (len >> 3) + data;

    while(data != end)
    {
        uint64_t k = *data++;

        k *= m; 
        k ^= k >> r; 
        k *= m; 
        
        h ^= k;
        h *= m; 
    }

    const unsigned char * data2 = (const unsigned char *)data;

    switch(len & 7)
    {
    case 7: h ^= (uint64_t)(data2[6]) << 48;
    case 6: h ^= (uint64_t)(data2[5]) << 40;
    case 5: h ^= (uint64_t)(data2[4]) << 32;
    case 4: h ^= (uint64_t)(data2[3]) << 24;
    case 3: h ^= (uint64_t)(data2[2]) << 16;
    case 2: h ^= (uint64_t)(data2[1]) << 8;
    case 1: h ^= (uint64_t)(data2[0]);
            h *= m;
    };
    
    h ^= h >> r;
    h *= m;
    h ^= h >> r;

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

