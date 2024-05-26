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

static const size_t PTR_BITMASK = 0xFFFFFFFFFFFFULL;
static const size_t KEY_TAG_SHIFT = 48;
static const size_t KEY_TAG_BITMASK = ~0xFFFFFFFFFFFFULL;
static const size_t GROUP_ALLOC_SIZE = 32;
static const size_t ALIGNMENT = 32;

typedef struct {
    CubsRawValue key;
    size_t hash;
} HashEntry;

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

    return requiredCapacity + (sizeof(HashEntry*) * requiredCapacity);
}

static const HashEntry** group_pair_buf_start(const Group* group) {
    const HashEntry** bufStart = (const HashEntry**)&group->hashMasks[group->capacity];
    return bufStart;
}

static HashEntry** group_pair_buf_start_mut(Group* group) {
    HashEntry** bufStart = (HashEntry**)&group->hashMasks[group->capacity];
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
static void group_deinit(Group* self, CubsValueTag keyTag) {
    if(self->pairCount != 0) {
        for(uint32_t i = 0; i < self->capacity; i++) {
            if(self->hashMasks[i] == 0) {
                continue;
            }
            
            HashEntry* pair = group_pair_buf_start_mut(self)[i];
            cubs_raw_value_deinit(&pair->key, keyTag);
            cubs_free((void*)pair, sizeof(HashEntry), _Alignof(HashEntry));
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
    HashEntry** newPairStart = (HashEntry**)&((uint8_t*)mem)[pairAllocCapacity];
    size_t moveIter = 0;
    for(uint32_t i = 0; i < self->capacity; i++) {
        if(self->hashMasks[i] == 0) {
            continue;
        }

        newHashMaskStart[moveIter] = self->hashMasks[i];
        newPairStart[moveIter] = group_pair_buf_start_mut(self)[i];
        moveIter += 1;
    }

    group_free(self);

    self->hashMasks = newHashMaskStart;
    self->capacity = pairAllocCapacity;
    return;
}

/// Returns -1 if not found
static size_t group_find(const Group* self, const CubsRawValue* key, CubsValueTag keyTag, CubsHashPairBitmask pairMask) {
    //#if __AVX2__
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
            const HashEntry* pair = group_pair_buf_start(self)[actualIndex];
            if(!cubs_raw_value_eql(&pair->key, key, keyTag)) {
                resultMask = (resultMask & ~(1U << index));
                continue;
            }
            return actualIndex;
        }       
    }
    //#endif
    return -1;
}

/// If the entry already exists, overrides the existing value.
static void group_insert(Group* self, CubsRawValue key, CubsValueTag keyTag, size_t hashCode) {
    const CubsHashPairBitmask pairMask = cubs_hash_pair_bitmask_init(hashCode);
    const size_t existingIndex = group_find(self, &key, keyTag, pairMask);
    if(existingIndex != -1) {
        cubs_raw_value_deinit(&key, keyTag); // don't need duplicate keys
        return;
    }

    group_ensure_total_capacity(self, self->pairCount + 1);

    //#if __AVX2__
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
        const HashEntry _newPairData = {.key = key, .hash = hashCode};
        HashEntry* newPair = (HashEntry*)cubs_malloc(sizeof(HashEntry), _Alignof(HashEntry));
        *newPair = _newPairData;

        self->hashMasks[actualIndex] = pairMask.value;
        group_pair_buf_start(self)[actualIndex] = newPair;

        self->pairCount += 1;
        return;
    }
    //#else
    unreachable();
    //#endif
}

static bool group_erase(Group* self, const CubsRawValue* key, CubsValueTag keyTag, CubsHashPairBitmask pairMask) {
    const size_t found = group_find(self, key, keyTag, pairMask);
    if(found == -1) {
        return false;
    }

    self->hashMasks[found] = 0;
    HashEntry* pair = group_pair_buf_start_mut(self)[found];
    cubs_raw_value_deinit(&pair->key, keyTag);
    cubs_free(pair, sizeof(HashEntry), _Alignof(HashEntry));
    self->pairCount -= 1;

    return true;
}

typedef struct {
    size_t entryCount;
    size_t groupCount;
} Metadata;
_Static_assert(_Alignof(Group) == _Alignof(Metadata), "Group must have same alignment as metadata");

/// Can return NULL if there are no groups
static Metadata* metadata_ptr(CubsSet* self) {
    const size_t mask = ((size_t)(self->_inner)) & PTR_BITMASK;
    return (Metadata*)mask;
}

static Metadata set_metadata(const CubsSet* self) {
    const size_t mask = ((size_t)(self->_inner)) & PTR_BITMASK;
    if(mask == 0) {
        const Metadata empty = {.entryCount = 0, .groupCount = 0};
        return empty;
    }
    return *(const Metadata*)(mask);
}

/// @return The array of groups
static const Group* set_groups(const CubsSet* self) {
    const size_t mask = ((size_t)(self->_inner)) & PTR_BITMASK;
    const Metadata* metadataPtr = (const Metadata*)(mask);
    return (const Group*)(&metadataPtr[1]);
}

/// @return The array of groups
static Group* set_groups_mut( CubsSet* self) {
    const size_t mask = ((size_t)(self->_inner)) & PTR_BITMASK;
    Metadata* metadataPtr = (Metadata*)(mask);
    return (Group*)(&metadataPtr[1]);
}

static void set_ensure_total_capacity(CubsSet* self, size_t minCapacity) {
    const Metadata oldMetadata = set_metadata(self);

    bool shouldReallocate = false;
    {
        if(oldMetadata.entryCount == 0) {
            shouldReallocate = true;
        }
        if((minCapacity / GROUP_ALLOC_SIZE) > oldMetadata.groupCount) {
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

    void* newMem = cubs_malloc(sizeof(Metadata) + (sizeof(Group) * newGroupCount), _Alignof(Group));
    const Metadata _newMetadataData = {.entryCount = oldMetadata.entryCount, .groupCount = newGroupCount};
    Metadata* newMetadata = (Metadata*)newMem;
    *newMetadata = _newMetadataData;

    Group* newGroups = (Group*)&newMetadata[1];
    for(size_t i = 0; i < newGroupCount; i++) {
        newGroups[i] = group_init();
    }
    if(oldMetadata.groupCount == 0) {
        self->_inner = (void*)((((size_t)self->_inner) & KEY_TAG_BITMASK) | (size_t)newMem);
        return;
    }

    Group* oldGroups = set_groups_mut(self);
    for(size_t oldGroupCount = 0; oldGroupCount < oldMetadata.groupCount; oldGroupCount++) {
        Group* oldGroup = &oldGroups[oldGroupCount];
        if(oldGroup->pairCount != 0) {
            for(uint32_t hashMaskIter = 0; hashMaskIter < oldGroup->capacity; hashMaskIter++) {
                if(oldGroup->hashMasks[hashMaskIter] == 0) {
                    continue;
                }

                HashEntry* pair = group_pair_buf_start_mut(oldGroup)[hashMaskIter];
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

    if(oldMetadata.groupCount > 0) {      
        void* memToFree = (void*)(((size_t)(self->_inner)) & PTR_BITMASK);
        cubs_free(memToFree, sizeof(Metadata) + (sizeof(Group) * oldMetadata.groupCount), _Alignof(Group));
    }
    
    self->_inner = (void*)((((size_t)self->_inner) & KEY_TAG_BITMASK) | (size_t)newMem);
}

CubsSet cubs_set_init(CubsValueTag keyTag)
{
    const size_t keyTagInt = (size_t)keyTag;
    const CubsSet set = {._inner = (void*)(keyTagInt << KEY_TAG_SHIFT)};
    return set;
}

void cubs_set_deinit(CubsSet *self)
{
    const Metadata metadata = set_metadata(self);
    if(metadata.groupCount == 0) {
        return;
    }

    const CubsValueTag keyTag = cubs_set_tag(self);
    Group* groups = set_groups_mut(self);
    for(size_t i = 0; i < metadata.groupCount; i++) {
        Group* group = &groups[i];
        group_deinit(group, keyTag);
    }
  
    void* memToFree = (void*)(((size_t)(self->_inner)) & PTR_BITMASK);
    cubs_free(memToFree, sizeof(Metadata) + (sizeof(Group) * metadata.groupCount), _Alignof(Group));
    self->_inner = NULL;
}

CubsValueTag cubs_set_tag(const CubsSet *self)
{
    const size_t masked = ((size_t)(self->_inner)) & KEY_TAG_BITMASK;
    return masked >> KEY_TAG_SHIFT;
}

size_t cubs_set_size(const CubsSet *self)
{
    return set_metadata(self).entryCount;
}

bool cubs_set_contains_unchecked(const CubsSet *self, const CubsRawValue *key)
{
    const Metadata metadata = set_metadata(self);
    if(metadata.entryCount == 0) {
        return false;
    }
    
    const CubsValueTag keyTag = cubs_set_tag(self);
    const size_t hashCode = cubs_compute_hash(key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata.groupCount;
    const Group* group = &(set_groups(self)[groupIndex]);

    const size_t found = group_find(group, key, keyTag, cubs_hash_pair_bitmask_init(hashCode));
    return found != -1;
}

bool cubs_set_contains(const CubsSet *self, const CubsTaggedValue *key)
{
    assert(key->tag == cubs_set_tag(self));
    return cubs_set_contains_unchecked(self, &key->value);
}

void cubs_set_insert_unchecked(CubsSet *self, CubsRawValue key)
{
    const size_t currentSize = cubs_set_size(self);
    set_ensure_total_capacity(self, currentSize + 1);

    Metadata* metadata = metadata_ptr(self); // guaranteed to be non-null here.
    
    const CubsValueTag keyTag = cubs_set_tag(self);
    const size_t hashCode = cubs_compute_hash(&key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;

    group_insert(&(set_groups_mut(self)[groupIndex]), key, keyTag, hashCode);
    metadata->entryCount += 1;
}

void cubs_set_insert(CubsSet *self, CubsTaggedValue key)
{
    assert(key.tag == cubs_set_tag(self));
    cubs_set_insert_unchecked(self, key.value);
}

bool cubs_set_erase_unchecked(CubsSet *self, const CubsRawValue *key)
{
    const size_t currentSize = cubs_set_size(self);
    if(currentSize == 0) {
        return false;
    }

    Metadata* metadata = metadata_ptr(self);  // guaranteed to be non-null because of the above check

    const CubsValueTag keyTag = cubs_set_tag(self);
    const size_t hashCode = cubs_compute_hash(key, keyTag);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;

    const bool result = group_erase(&(set_groups_mut(self)[groupIndex]), key, keyTag, cubs_hash_pair_bitmask_init(hashCode));
    metadata->entryCount -= (size_t)result;  
    return result;
}

bool cubs_set_erase(CubsSet *self, const CubsTaggedValue *key)
{
    assert(key->tag == cubs_set_tag(self));
    return cubs_set_erase_unchecked(self, &key->value);
}
