#pragma once

#include <stddef.h>
#include <stdint.h>
#include "../primitives/script_value.h"

size_t cubs_compute_hash(const CubsRawValue* value, CubsValueTag tag);

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

