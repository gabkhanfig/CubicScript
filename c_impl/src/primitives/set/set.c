#include "set.h"
#include <assert.h>
#include <string.h>
#include "../../util/global_allocator.h"
#include "../../util/hash.h"
#include "../../util/bitwise.h"
#include "../../util/unreachable.h"

//#if __AVX2__
#include <immintrin.h>
//#endif

static const size_t GROUP_ALLOC_SIZE = 32;
static const size_t ALIGNMENT = 32;
static const size_t DATA_BITMASK = 0xFFFFFFFFFFFFULL;
static const size_t TAG_SHIFT = 48;
static const size_t TAG_BITMASK = 0xFFULL << 48;
static const size_t TYPE_SIZE_SHIFT = 56;
static const size_t TYPE_SIZE_BITMASK = 0xFFULL << 56;
static const size_t NON_DATA_BITMASK = ~(0xFFFFFFFFFFFFULL);

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

    return requiredCapacity + (sizeof(void*) * requiredCapacity);
}

static const void** group_pair_buf_start(const Group* group) {
    const void** bufStart = (const void**)&group->hashMasks[group->capacity];
    return bufStart;
}

static void** group_pair_buf_start_mut(Group* group) {
    void** bufStart = (void**)&group->hashMasks[group->capacity];
    return bufStart;
}

/// Get the memory of the key of `pair`.
static const void* pair_key(const void* pair) {
    const char* start = (const char*)pair;
    return (const void*)&(start[sizeof(size_t)]);
}

/// Get the memory of the key of `pair`.
static void* pair_key_mut(void* pair) {
    char* start = (char*)pair;
    return (void*)&(start[sizeof(size_t)]);
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
static void group_deinit(Group* self, CubsValueTag keyTag, size_t sizeOfKey) {
    if(self->pairCount != 0) {
        for(uint32_t i = 0; i < self->capacity; i++) {
            if(self->hashMasks[i] == 0) {
                continue;
            }
            
            void* pair = group_pair_buf_start_mut(self)[i];
            cubs_void_value_deinit(pair_key_mut(pair), keyTag);
            // cache'd hash code + key + value
            cubs_free((void*)pair, sizeof(size_t) + sizeOfKey, _Alignof(size_t));
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
    void** newPairStart = (void**)&((uint8_t*)mem)[pairAllocCapacity];
    size_t moveIter = 0;
    for(uint32_t i = 0; i < self->capacity; i++) {
        if(self->hashMasks[i] == 0) {
            continue;
        }

        newHashMaskStart[moveIter] = self->hashMasks[i];
        // Copy over the pointer to the pair info, transferring ownership
        newPairStart[moveIter] = group_pair_buf_start_mut(self)[i]; 
        moveIter += 1;
    }

    group_free(self);

    self->hashMasks = newHashMaskStart;
    self->capacity = pairAllocCapacity;
    return;
}

/// Returns -1 if not found
static size_t group_find(const Group* self, const void* key, CubsValueTag keyTag, CubsHashPairBitmask pairMask) {
    #if __AVX2__
    const __m256i maskVec = _mm256_set1_epi8(pairMask.value);
    
    size_t i = 0;
    while(i < self->capacity) {
        const __m256i hashMasks = *(const __m256i*)&self->hashMasks[i];
        const __m256i result = _mm256_cmpeq_epi8(maskVec, hashMasks);
        int resultMask = _mm256_movemask_epi8(result);
        while(true) { // Go through each bit
            uint32_t index;
            if(!countTrailingZeroes32(&index, resultMask)) {
                i += 32;
                break;
            }
            const size_t actualIndex = index + i;
            const void* pair = group_pair_buf_start(self)[actualIndex];
            const void* pairKey = pair_key(pair);
            /// Because of C union alignment, and the sizes and alignments of the union members, this is valid.
            if(!cubs_raw_value_eql((const CubsRawValue*)pairKey, (const CubsRawValue*)key, keyTag)) {
                resultMask = (resultMask & ~(1U << index));
                continue;
            }
            return actualIndex;
        }       
    }
    #endif
    return -1;
}

/// If the entry already exists, overrides the existing value.
static void group_insert(Group* self, void* key, CubsValueTag keyTag, size_t sizeOfKey, size_t hashCode) {
    const CubsHashPairBitmask pairMask = cubs_hash_pair_bitmask_init(hashCode);
    const size_t existingIndex = group_find(self, &key, keyTag, pairMask);
    if(existingIndex != -1) {
        cubs_void_value_deinit(key, keyTag); // don't need duplicate keys
        return;
    }

    group_ensure_total_capacity(self, self->pairCount + 1);

    #if __AVX2__
    // SIMD find first zero
    const __m256i zeroVec = _mm256_set1_epi8(0);
    size_t i = 0;
    while(i < self->capacity) {  
        const __m256i hashMasks = *(const __m256i*)&self->hashMasks[i];
        const __m256i result = _mm256_cmpeq_epi8(zeroVec, hashMasks);
        int resultMask = _mm256_movemask_epi8(result);
        
        uint32_t index;
        if(!countTrailingZeroes32(&index, resultMask)) {
            i += 32;
            continue;
        }

        const size_t actualIndex = index + i;
        void* newPair = cubs_malloc(sizeof(size_t) + sizeOfKey, _Alignof(size_t));
        *(size_t*)newPair = hashCode;
        memcpy(pair_key_mut(newPair), key, sizeOfKey);
    
        self->hashMasks[actualIndex] = pairMask.value;
        group_pair_buf_start_mut(self)[actualIndex] = newPair;

        self->pairCount += 1;
        return;
    }
    #endif
    unreachable();
}

static bool group_erase(Group* self, const void* key, CubsValueTag keyTag, size_t sizeOfKey, CubsHashPairBitmask pairMask) {
    const size_t found = group_find(self, key, keyTag, pairMask);
    if(found == -1) {
        return false;
    }

    self->hashMasks[found] = 0;
    void* pair = group_pair_buf_start_mut(self)[found];
    cubs_void_value_deinit(pair_key_mut(pair), keyTag);
    cubs_free(pair, sizeof(size_t) + sizeOfKey, _Alignof(size_t));
    self->pairCount -= 1;

    return true;
}

typedef struct {
    Group* groupsArray;
    size_t groupCountAndKeyInfo;
    size_t available;
} Metadata;

static const Metadata* as_metadata(const CubsSet* self) {
    return (const Metadata*)self->_metadata;
}

static Metadata* as_metadata_mut(CubsSet* self) {  
    return (Metadata*)self->_metadata;
}

static size_t current_group_count(const CubsSet* self) {
    const Metadata* metadata = as_metadata(self);
    return (metadata->groupCountAndKeyInfo) & DATA_BITMASK;
}

static void set_group_count(CubsSet* self, size_t newGroupCount) {
    Metadata* metadata = as_metadata_mut(self);
    metadata->groupCountAndKeyInfo = (metadata->groupCountAndKeyInfo & NON_DATA_BITMASK) | newGroupCount;
}

static void set_ensure_total_capacity(CubsSet* self, size_t minCapacity) {
    Metadata* metadata = as_metadata_mut(self);
    if(metadata->available != 0) {
        return;
    }

    const size_t currentGroupCount = current_group_count(self);
    size_t newGroupCount;
    if(currentGroupCount == 0) {
        newGroupCount = 1;
    }
    else {
        newGroupCount = current_group_count(self) * 2;
    }

    Group* newGroups = (Group*)cubs_malloc(sizeof(Group) * newGroupCount, _Alignof(Group));
    for(size_t i = 0; i < newGroupCount; i++) {
        newGroups[i] = group_init();
    }

    if(currentGroupCount == 0) {
        const size_t DEFAULT_AVAILABLE = (size_t)(((float)GROUP_ALLOC_SIZE) * 0.8f);
        metadata->groupsArray = newGroups;
        metadata->available = DEFAULT_AVAILABLE;
        set_group_count(self, newGroupCount);
    }
    else {
        const size_t availableEntries = GROUP_ALLOC_SIZE * newGroupCount;
        const size_t newAvailable = (availableEntries * 4) / 5; // * 0.8 for load factor

        for(size_t oldGroupCount = 0; oldGroupCount < currentGroupCount; oldGroupCount++) {
            Group* oldGroup = &metadata->groupsArray[oldGroupCount];
            if(oldGroup->pairCount != 0) {
                for(uint32_t hashMaskIter = 0; hashMaskIter < oldGroup->capacity; hashMaskIter++) {
                    if(oldGroup->hashMasks[hashMaskIter] == 0) {
                        continue;
                    }

                    void* pair = group_pair_buf_start_mut(oldGroup)[hashMaskIter];
                    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(*(const size_t*)pair);
                    const size_t groupIndex = groupBitmask.value % newGroupCount;

                    Group* newGroup = &newGroups[groupIndex];
                    group_ensure_total_capacity(newGroup, newGroup->pairCount + 1);
                    
                    newGroup->hashMasks[newGroup->pairCount] = oldGroup->hashMasks[hashMaskIter];
                    group_pair_buf_start_mut(newGroup)[newGroup->pairCount] = pair;
                    newGroup->pairCount += 1;
                }
            }
            
            const size_t oldGroupAllocationSize = group_allocation_size(oldGroup->capacity);
            cubs_free((void*)oldGroup->hashMasks, oldGroupAllocationSize, ALIGNMENT);
        }

        if(currentGroupCount > 0) {
            cubs_free((void*)metadata->groupsArray, sizeof(Group) * currentGroupCount, _Alignof(Group));
        }

        metadata->groupsArray = newGroups;
        metadata->available = newAvailable;
        set_group_count(self, newGroupCount);
    }
}

CubsSet cubs_set_init(CubsValueTag tag)
{
    const size_t keyTagInt = (size_t)tag;
    const size_t sizeOfKey = cubs_size_of_tagged_type(tag);
    CubsSet map = {0};
    Metadata* metadata = as_metadata_mut(&map);
    metadata->groupCountAndKeyInfo = (keyTagInt << TAG_SHIFT) | (sizeOfKey << TYPE_SIZE_SHIFT);
    return map;
}

void cubs_set_deinit(CubsSet *self)
{
    Metadata* metadata = as_metadata_mut(self);
    if(metadata->groupsArray == NULL) {
        return;
    }

    const CubsValueTag keyTag = cubs_set_tag(self);
    const size_t sizeOfKey = cubs_set_size_of_key(self);
    const size_t groupCount = current_group_count(self);

    for(size_t i = 0; i < groupCount; i++) {
        group_deinit(&metadata->groupsArray[i], keyTag, sizeOfKey);
    }

    cubs_free((void*)metadata->groupsArray, sizeof(Group) * groupCount, _Alignof(Group));
    metadata->groupsArray = NULL;
}

CubsValueTag cubs_set_tag(const CubsSet *self)
{
    const Metadata* metadata = as_metadata(self);
    const size_t masked = ((size_t)(metadata->groupCountAndKeyInfo)) & TAG_BITMASK;
    assert(masked != 0);
    return masked >> TAG_SHIFT;
}

size_t cubs_set_size_of_key(const CubsSet *self)
{
    const Metadata* metadata = as_metadata(self);
    const size_t masked = ((size_t)(metadata->groupCountAndKeyInfo)) & TYPE_SIZE_BITMASK;
    assert(masked != 0);
    return masked >> TYPE_SIZE_SHIFT;
}

bool cubs_set_contains_unchecked(const CubsSet *self, const void *key)
{
    if(self->count == 0) {
        return NULL;
    }
    const Metadata* metadata = as_metadata(self);

    const CubsValueTag keyTag = cubs_set_tag(self);
    const size_t hashCode = cubs_compute_hash((const CubsRawValue*)key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % current_group_count(self);
    const Group* group = &metadata->groupsArray[groupIndex];

    const size_t found = group_find(group, key, keyTag, cubs_hash_pair_bitmask_init(hashCode));
    return found != -1;
}

bool cubs_set_contains_raw_unchecked(const CubsSet *self, const CubsRawValue *key)
{
    return cubs_set_contains_unchecked(self, (const void*)key);
}

bool cubs_set_contains(const CubsSet *self, const CubsTaggedValue *key)
{
    assert(key->tag == cubs_set_tag(self));
    return cubs_set_contains_unchecked(self, (const void*)&key->value);
}

void cubs_set_insert_unchecked(CubsSet *self, void* key)
{
    set_ensure_total_capacity(self, self->count + 1);
    
    Metadata* metadata = as_metadata_mut(self);
    
    const CubsValueTag keyTag = cubs_set_tag(self);
    const size_t hashCode = cubs_compute_hash((const CubsRawValue*)key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % current_group_count(self);

    group_insert(&metadata->groupsArray[groupIndex], key, keyTag, cubs_set_size_of_key(self), hashCode);
    self->count += 1;
    metadata->available -= 1;
}

void cubs_set_insert_raw_unchecked(CubsSet *self, CubsRawValue key)
{
    cubs_set_insert_unchecked(self, (void*)&key);
}

void cubs_set_insert(CubsSet *self, CubsTaggedValue key)
{
    assert(key.tag == cubs_set_tag(self));
    cubs_set_insert_unchecked(self, (void*)&key.value);
}

bool cubs_set_erase_unchecked(CubsSet *self, const void *key)
{
    if(self->count == 0) {
        return false;
    }

    Metadata* metadata = as_metadata_mut(self);

    const CubsValueTag keyTag = cubs_set_tag(self);
    const size_t hashCode = cubs_compute_hash((const CubsRawValue*)key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % current_group_count(self);

    const bool result = group_erase(&metadata->groupsArray[groupIndex], key, keyTag, cubs_set_size_of_key(self), cubs_hash_pair_bitmask_init(hashCode));
    if(result) {
        self->count -= 1;      
        metadata->available += 1;
    }
    return result;
}

bool cubs_set_erase_raw_unchecked(CubsSet *self, const CubsRawValue *key)
{
    return cubs_set_erase_unchecked(self, (const void*)&key);
}

bool cubs_set_erase(CubsSet *self, const CubsTaggedValue *key)
{
    assert(key->tag == cubs_set_tag(self));
    return cubs_set_erase_unchecked(self, &key->value);
}