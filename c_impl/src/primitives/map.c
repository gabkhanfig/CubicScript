#include "map.h"
#include <assert.h>
#include "../util/global_allocator.h"
#include <string.h>
#include "../util/panic.h"
#include "../util/unreachable.h"
#include <stdio.h>
#include "../util/hash.h"

//#if __AVX2__
#include <immintrin.h>
//#endif

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#endif // WIN32 def

static const size_t PTR_BITMASK = 0xFFFFFFFFFFFFULL;
static const size_t KEY_TAG_SHIFT = 48;
static const size_t KEY_TAG_BITMASK = 0xFFULL << 48;
static const size_t VALUE_TAG_SHIFT = 56;
static const size_t VALUE_TAG_BITMASK = 0xFFULL << 56;
static const size_t BOTH_TAGS_BITMASK = ~(0xFFFFFFFFFFFFULL);
static const size_t GROUP_ALLOC_SIZE = 32;
static const size_t ALIGNMENT = 32;

typedef struct {
    CubsRawValue key;
    CubsRawValue value;
    size_t hash;
} HashPair;

typedef struct {
    /// The actual pairs start at `&hashMasks[capacity]`
    uint8_t* hashMasks;
    uint32_t pairCount; 
    uint32_t capacity;
    // Use uint32_t to save 8 bytes in total. If a map has more than 4.29 billion entires in a single group,
    // then the load balancing and/or hashing implementation is poor.
    // uint16_t is not viable here because of forced alignment and padding.
} Group;

static size_t group_allocation_size(size_t requiredCapacity) {
    assert(requiredCapacity % 32 == 0);

    return requiredCapacity + (sizeof(HashPair*) * requiredCapacity);
}

static const HashPair* group_pair_at(const Group* group, size_t index) {
    const HashPair** bufStart = (const HashPair**)&group->hashMasks[group->capacity];
    return bufStart[index];
}

static HashPair* group_pair_at_mut(Group* group, size_t index) {
    HashPair** bufStart = (HashPair**)&group->hashMasks[group->capacity];
    return bufStart[index];
}

static HashPair** group_pair_buf_start(Group* group) {
    HashPair** bufStart = (HashPair**)&group->hashMasks[group->capacity];
    return bufStart;
}

static Group group_init() {
    const size_t initialAllocationSize = group_allocation_size(GROUP_ALLOC_SIZE);
    void* mem = cubs_malloc(initialAllocationSize, ALIGNMENT);
    memset(mem, 0, initialAllocationSize);

    const Group group = {.hashMasks = (uint8_t*)mem, .capacity = GROUP_ALLOC_SIZE, .pairCount = 0};
    return group;
}

/// Free the group memory without deinitializing the pairs
static void group_free(Group* self) {
    const size_t currentAllocationSize = group_allocation_size(self->capacity);
    cubs_free((void*)self->hashMasks, currentAllocationSize, ALIGNMENT);
    #if _DEBUG
    self->hashMasks = NULL;
    self->capacity = 0;
    #endif
}

/// Deinitialize the pairs, and free the group
static void group_deinit(Group* self, CubsValueTag keyTag, CubsValueTag valueTag) {
    if(self->pairCount != 0) {
        for(uint32_t i = 0; i < self->capacity; i++) {
            if(self->hashMasks[i] == 0) {
                continue;
            }
            
            HashPair* pair = group_pair_at_mut(self, i);
            cubs_raw_value_deinit(&pair->key, keyTag);
            cubs_raw_value_deinit(&pair->value, valueTag);
            cubs_free((void*)pair, sizeof(HashPair), _Alignof(HashPair));
        }
    }

    group_free(self);
}

static void group_ensure_total_capacity(Group* self, size_t minCapacity) {
    if(minCapacity <= self->capacity) {
        return;
    }

    const size_t remainder = minCapacity % 32;
    const size_t pairAllocCapacity = minCapacity + (32 - remainder);
    const size_t mallocCapacity =  group_allocation_size(pairAllocCapacity);

    void* mem = cubs_malloc(mallocCapacity, ALIGNMENT);
    memset(mem, 0, mallocCapacity);

    uint8_t* newHashMaskStart = (uint8_t*)mem;
    HashPair** newPairStart = (HashPair**)&((uint8_t*)mem)[pairAllocCapacity];
    size_t moveIter = 0;
    for(uint32_t i = 0; i < self->capacity; i++) {
        if(self->hashMasks[i] == 0) {
            continue;
        }

        newHashMaskStart[moveIter] = self->hashMasks[i];
        newPairStart[moveIter] = group_pair_at_mut(self, i);
        moveIter += 1;
    }

    group_free(self);

    self->hashMasks = newHashMaskStart;
    self->capacity = pairAllocCapacity;
    return;
}

/// Returns -1 if not found
static size_t group_find(const Group* self, const CubsRawValue* key, CubsValueTag keyTag, CubsHashPairBitmask pairMask) {
    const __m256i maskVec = _mm256_set1_epi8(pairMask.value);
    
    size_t i = 0;
    while(i < self->capacity) {
        const __m256i hashMasks = *(const __m256i*)&self->hashMasks[i];
        const __m256i result = _mm256_cmpeq_epi8(maskVec, hashMasks);
        int resultMask = _mm256_movemask_epi8(result);
        while(true) { // Go through each bit
            unsigned long index;
            #if defined(_WIN32) || defined(WIN32)
            if(!_BitScanForward(&index, resultMask)) {
                i += 32;
                break;
            }
            #endif // WIN32
            const size_t actualIndex = index + i;
            const HashPair* pair = group_pair_at(self, actualIndex);
            if(!cubs_raw_value_eql(&pair->key, key, keyTag)) {
                resultMask = (resultMask & ~(1U << index));
                continue;
            }
            return actualIndex;
        }       
    }
    return -1;
}

/// If the entry already exists, overrides the existing value.
static void group_insert(Group* self, CubsRawValue key, CubsRawValue value, CubsValueTag keyTag, CubsValueTag valueTag, size_t hashCode) {
    const CubsHashPairBitmask pairMask = cubs_hash_pair_bitmask_init(hashCode);
    const size_t existingIndex = group_find(self, &key, keyTag, pairMask);
    if(existingIndex != -1) {
        HashPair* pair = group_pair_at_mut(self, existingIndex);
        cubs_raw_value_deinit(&pair->value, valueTag);
        pair->value = value;

        cubs_raw_value_deinit(&key, keyTag); // don't need duplicate keys
        return;
    }

    group_ensure_total_capacity(self, self->pairCount + 1);

    // SIMD find first zero
    const __m256i zeroVec = _mm256_set1_epi8(0);
    size_t i = 0;
    while(i < self->capacity) {  
        const __m256i hashMasks = *(const __m256i*)&self->hashMasks[i];
        const __m256i result = _mm256_cmpeq_epi8(zeroVec, hashMasks);
        int resultMask = _mm256_movemask_epi8(result);
        
        unsigned long index;
        #if defined(_WIN32) || defined(WIN32)
        if(!_BitScanForward(&index, resultMask)) {
            i += 32;
            continue;
        }
        #endif // WIN32

        const size_t actualIndex = index + i;
        const HashPair _newPairData = {.key = key, .value = value, .hash = hashCode};
        HashPair* newPair = (HashPair*)cubs_malloc(sizeof(HashPair), _Alignof(HashPair));
        *newPair = _newPairData;

        self->hashMasks[actualIndex] = pairMask.value;
        group_pair_buf_start(self)[actualIndex] = newPair;

        self->pairCount += 1;
        return;
    }
    unreachable();
}

static bool group_erase(Group* self, const CubsRawValue* key, CubsValueTag keyTag, CubsValueTag valueTag, CubsHashPairBitmask pairMask) {
    const size_t found = group_find(self, key, keyTag, pairMask);
    if(found == -1) {
        return false;
    }

    self->hashMasks[found] = 0;
    HashPair* pair = group_pair_at_mut(self, found);
    cubs_raw_value_deinit(&pair->key, keyTag);
    cubs_raw_value_deinit(&pair->value, valueTag);
    cubs_free(pair, sizeof(HashPair), _Alignof(HashPair));
    self->pairCount -= 1;

    return true;
}

typedef struct {
    Group* groupsArray;
    size_t groupCount;
    size_t entryCount;
} Inner;

static const Inner* as_inner(const CubsMap* self) {  
    const size_t mask = ((size_t)(self->_inner)) & PTR_BITMASK;
    const Inner* inner = (const Inner*)(const void*)mask;
    return inner;
}

static Inner* as_inner_mut(CubsMap* self) {  
    const size_t mask = ((size_t)(self->_inner)) & PTR_BITMASK;
    Inner* inner = (Inner*)(void*)mask;
    return inner;
}

static void map_ensure_total_capacity(CubsMap* self, size_t minCapacity) {
    bool shouldReallocate = false;
    {
        const Inner* tempInner = as_inner(self);
        if(tempInner != NULL) {
            // TODO proper load factor
            if((minCapacity / GROUP_ALLOC_SIZE) > tempInner->groupCount) {
                shouldReallocate = true;
            }
        }
        else {
            shouldReallocate = true;
        }
    }
    if(!shouldReallocate) {
        return;
    }

    
    size_t newGroupCount = 1;
    if(minCapacity > GROUP_ALLOC_SIZE) {
        newGroupCount = minCapacity / (GROUP_ALLOC_SIZE / 4);
    }

    Group* newGroups = (Group*)cubs_malloc(sizeof(Group) * newGroupCount, _Alignof(Group));
    for(size_t i = 0; i < newGroupCount; i++) {
        newGroups[i] = group_init();
    }

    Inner* inner = as_inner_mut(self);
    if(inner == NULL) {
        Inner* newInner = (Inner*)cubs_malloc(sizeof(Inner), _Alignof(Inner));
        const Inner newInnerData = {.groupsArray = newGroups, .groupCount = newGroupCount, .entryCount = 0};
        *newInner = newInnerData;
        self->_inner = (void*)((((size_t)self->_inner) & BOTH_TAGS_BITMASK) | (size_t)newInner);
    }
    else {
        for(size_t oldGroupCount = 0; oldGroupCount < inner->groupCount; oldGroupCount++) {
            Group* oldGroup = &inner->groupsArray[oldGroupCount];
            if(oldGroup->pairCount != 0) {
                for(uint32_t hashMaskIter = 0; hashMaskIter < oldGroup->capacity; hashMaskIter++) {
                    if(oldGroup->hashMasks[hashMaskIter] == 0) {
                        continue;
                    }

                    HashPair* pair = group_pair_at_mut(oldGroup, hashMaskIter);
                    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(pair->hash);
                    const size_t groupIndex = groupBitmask.value % newGroupCount;

                    Group* newGroup = &newGroups[groupIndex];
                    group_ensure_total_capacity(newGroup, newGroup->pairCount + 1);
                    
                    newGroup->hashMasks[newGroup->pairCount] = oldGroup->hashMasks[hashMaskIter];
                    group_pair_buf_start(newGroup)[newGroup->pairCount] = pair;
                    newGroup->pairCount += 1;
                }
            }
            
            const size_t oldGroupAllocationSize = group_allocation_size(oldGroup->capacity);
            cubs_free((void*)oldGroup->hashMasks, oldGroupAllocationSize, ALIGNMENT);
        }

        if(inner->groupCount > 0) {
            cubs_free((void*)inner->groupsArray, sizeof(Group) * inner->groupCount, _Alignof(Group));
        }

        inner->groupsArray = newGroups;
        inner->groupCount = newGroupCount;
    }
}

CubsMap cubs_map_init(CubsValueTag keyTag, CubsValueTag valueTag)
{
    const size_t keyTagInt = (size_t)keyTag;
    const size_t valueTagInt = (size_t)valueTag;
    const CubsMap map = {._inner = (void*)((keyTagInt << KEY_TAG_SHIFT) | (valueTagInt << VALUE_TAG_SHIFT))};
    return map;
}

void cubs_map_deinit(CubsMap *self)
{
    Inner* inner = as_inner_mut(self);
    if(inner == NULL) {
        return;
    }

    const CubsValueTag keyTag = cubs_map_key_tag(self);
    const CubsValueTag valueTag = cubs_map_value_tag(self);

    for(size_t i = 0; i < inner->groupCount; i++) {
        group_deinit(&inner->groupsArray[i], keyTag, valueTag);
    }

    cubs_free((void*)inner->groupsArray, sizeof(Group) * inner->groupCount, _Alignof(Group));
    cubs_free((void*)inner, sizeof(Inner), _Alignof(Inner));
    self->_inner = NULL;
}

CubsValueTag cubs_map_key_tag(const CubsMap *self)
{
    const size_t masked = ((size_t)(self->_inner)) & KEY_TAG_BITMASK;
    return masked >> KEY_TAG_SHIFT;
}

CubsValueTag cubs_map_value_tag(const CubsMap *self)
{
    const size_t masked = ((size_t)(self->_inner)) & VALUE_TAG_BITMASK;
    return masked >> VALUE_TAG_SHIFT;
}

size_t cubs_map_size(const CubsMap *self)
{
    const Inner* inner = as_inner(self);
    if(inner == NULL) {
        return 0;
    }
    return inner->entryCount;
}

const CubsRawValue *cubs_map_find_unchecked(const CubsMap *self, const CubsRawValue *key)
{
    const Inner* inner = as_inner(self);
    if(inner == NULL) {
        return NULL;
    }

    
    
    const CubsValueTag keyTag = cubs_map_key_tag(self);
    const size_t hashCode = cubs_compute_hash(key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % inner->groupCount;
    const Group* group = &inner->groupsArray[groupIndex];

    const size_t found = group_find(group, key, keyTag, cubs_hash_pair_bitmask_init(hashCode));
    if(found == -1) {
        return NULL;
    }

    return &group_pair_at(group, found)->value;
}

const CubsRawValue *cubs_map_find(const CubsMap *self, const CubsTaggedValue *key)
{
    assert(key->tag == cubs_map_key_tag(self));
    return cubs_map_find_unchecked(self, &key->value);
}

CubsRawValue *cubs_map_find_mut_unchecked(CubsMap *self, const CubsRawValue *key)
{
    Inner* inner = as_inner_mut(self);
    if(inner == NULL) {
        return NULL;
    }

    const CubsValueTag keyTag = cubs_map_key_tag(self);
    const size_t hashCode = cubs_compute_hash(key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % inner->groupCount;
    Group* group = &inner->groupsArray[groupIndex];

    const size_t found = group_find(group, key, keyTag, cubs_hash_pair_bitmask_init(hashCode));
    if(found == -1) {
        return NULL;
    }

    return &group_pair_at_mut(group, found)->value;
}

CubsRawValue *cubs_map_find_mut(CubsMap *self, const CubsTaggedValue *key)
{
    assert(key->tag == cubs_map_key_tag(self));
    return cubs_map_find_mut_unchecked(self, &key->value);
}

void cubs_map_insert_unchecked(CubsMap *self, CubsRawValue key, CubsRawValue value)
{
    const size_t currentSize = cubs_map_size(self);
    map_ensure_total_capacity(self, currentSize + 1);

    Inner* inner = as_inner_mut(self); // Won't be NULL
    
    const CubsValueTag keyTag = cubs_map_key_tag(self);
    const CubsValueTag valueTag = cubs_map_value_tag(self);
    const size_t hashCode = cubs_compute_hash(&key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % inner->groupCount;

    group_insert(&inner->groupsArray[groupIndex], key, value, keyTag, valueTag, hashCode);
    inner->entryCount += 1;
}

void cubs_map_insert(CubsMap *self, CubsTaggedValue key, CubsTaggedValue value)
{
    assert(key.tag == cubs_map_key_tag(self));
    assert(value.tag == cubs_map_value_tag(self));
    cubs_map_insert_unchecked(self, key.value, value.value);
}
