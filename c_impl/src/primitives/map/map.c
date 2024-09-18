#include "map.h"
#include <assert.h>
#include "../../platform/mem.h"
#include <string.h>
#include "../../util/panic.h"
#include "../../util/unreachable.h"
#include <stdio.h>
#include "../../util/hash.h"
#include "../../util/bitwise.h"
#include "../string/string.h"
#include "../primitives_context.h"
#include "../../util/simd.h"
#include "../../util/context_size_round.h"

static const size_t GROUP_ALLOC_SIZE = 32;
static const size_t ALIGNMENT = 32;

typedef struct PairHeader PairHeader;

typedef struct PairHeader {
    size_t hashCode;
    PairHeader* iterBefore;
    PairHeader* iterAfter;
} PairHeader;

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

static const PairHeader** group_pair_buf_start(const Group* group) {
    const PairHeader** bufStart = (const PairHeader**)&group->hashMasks[group->capacity];
    return bufStart;
}

static PairHeader** group_pair_buf_start_mut(Group* group) {
    PairHeader** bufStart = (PairHeader**)&group->hashMasks[group->capacity];
    return bufStart;
}

/// Get the memory of the key of `pair`.
static const void* pair_key(const PairHeader* pair) {
    return (const void*)(&pair[1]);
}

/// Get the memory of the key of `pair`.
static void* pair_key_mut(PairHeader* pair) {
    return (void*)(&pair[1]);
}

/// Get the memory of the value of `pair`.
static const void* pair_value(const PairHeader* pair, size_t powOf8Size) {
    const char* keyByteStart = (const char*)(&pair[1]);
    return (const void*)&(keyByteStart[powOf8Size]);
}

/// Get the memory of the value of `pair`.
static void* pair_value_mut(PairHeader* pair, size_t powOf8Size) {
    char* keyByteStart = (char*)(&pair[1]);
    return (void*)&(keyByteStart[powOf8Size]);
}

static void pair_deinit(PairHeader* pair, const CubsTypeContext* keyContext, const CubsTypeContext* valueContext, PairHeader** iterFirst, PairHeader** iterLast) {
    // Change iterator doubly-linked list
    PairHeader* before = pair->iterBefore;
    PairHeader* after = pair->iterAfter;
    if(before != NULL) { // If isn't first iter element
        before->iterAfter = after; // If after is NULL this is still correct
    } else {
        *iterFirst = after; // If after is NULL this is still correct
    }
    if(after != NULL) { // If isn't last iter element
        after->iterBefore = before; // If before is NULL this is still correct
    } else {
        *iterLast = before;
    }

    const size_t keyRound8Size = ROUND_SIZE_TO_MULTIPLE_OF_8(keyContext->sizeOfType);
    const size_t valueRound8Size = ROUND_SIZE_TO_MULTIPLE_OF_8(valueContext->sizeOfType);
    
    if(keyContext->destructor != NULL) {
        keyContext->destructor(pair_key_mut(pair));
    }
    if(valueContext->destructor != NULL) {
        valueContext->destructor(pair_value_mut(pair, keyRound8Size));
    }

    cubs_free((void*)pair, sizeof(PairHeader) + keyRound8Size + valueRound8Size, _Alignof(size_t));
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
}

/// Deinitialize the pairs, and free the group
static void group_deinit(Group* self, const CubsTypeContext* keyContext, const CubsTypeContext* valueContext, PairHeader** iterFirst, PairHeader** iterLast) {
    if(self->pairCount != 0) {
        for(uint32_t i = 0; i < self->capacity; i++) {
            if(self->hashMasks[i] == 0) {
                continue;
            }
            
            pair_deinit(group_pair_buf_start_mut(self)[i], keyContext, valueContext, iterFirst, iterLast);
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
static size_t group_find(const Group* self, const void* key, const CubsTypeContext* keyContext, CubsHashPairBitmask pairMask) {   
    uint32_t i = 0;
    while(i < self->capacity) {
        uint32_t resultMask = _cubs_simd_cmpeq_mask_8bit_32wide_aligned(pairMask.value, &self->hashMasks[i]);
        while(true) { // check each bit
            uint32_t index;
            if(!countTrailingZeroes32(&index, resultMask)) {
                i += 32;
                break;
            }

            const size_t actualIndex = index + i;
            const void* pair = group_pair_buf_start(self)[actualIndex];
            const void* pairKey = pair_key(pair);
            assert(keyContext->eql != NULL);
            /// Because of C union alignment, and the sizes and alignments of the union members, this is valid.
            if(!keyContext->eql(pairKey, key)) {
                resultMask = (resultMask & ~(1U << index));
                continue;
            }
            return actualIndex;
        }
    }

    return -1;
}

/// If the entry already exists, overrides the existing value.
static void group_insert(Group* self, void* key, void* value, const CubsTypeContext* keyContext, const CubsTypeContext* valueContext, size_t hashCode, PairHeader** iterFirst, PairHeader** iterLast) {
    #if _DEBUG
    if(*iterLast != NULL) {
        assert((*iterLast)->iterAfter == NULL);
    }
    #endif
    
    const CubsHashPairBitmask pairMask = cubs_hash_pair_bitmask_init(hashCode);
    const size_t existingIndex = group_find(self, &key, keyContext, pairMask);
    
    if(existingIndex != -1) {
        void* pair = group_pair_buf_start_mut(self)[existingIndex];
        void* pairValue = pair_value_mut(pair, keyContext->sizeOfType);
        if(valueContext->destructor != NULL) {
            valueContext->destructor(pairValue);
        }
        memcpy(pairValue, value, valueContext->sizeOfType);

        if(keyContext->destructor != NULL) {
            keyContext->destructor(key);  // don't need duplicate keys
        }
        return;
    }

    group_ensure_total_capacity(self, self->pairCount + 1);
  
    uint32_t i = 0;
    while(i < self->capacity) {
        size_t index;
        if(!_cubs_simd_index_of_first_zero_8bit_32wide_aligned(&index, &self->hashMasks[i])) {
            i += 32;
            continue;
        }

        const size_t keyRound8Size = ROUND_SIZE_TO_MULTIPLE_OF_8(keyContext->sizeOfType);
        const size_t valueRound8Size = ROUND_SIZE_TO_MULTIPLE_OF_8(valueContext->sizeOfType);

        PairHeader* newPair = (PairHeader*)cubs_malloc(sizeof(PairHeader) + keyRound8Size + valueRound8Size, _Alignof(size_t));
        newPair->hashCode = hashCode;
        newPair->iterBefore = *iterLast;
        newPair->iterAfter = NULL;

        if(*iterFirst == NULL) { // This is the first element in the map
            *iterFirst = newPair;
        }
        if(*iterLast == NULL) {
            *iterLast = newPair;
        } else {
            (*iterLast)->iterAfter = newPair;
            (*iterLast) = newPair;
        }


        memcpy(pair_key_mut(newPair), key, keyContext->sizeOfType);
        memcpy(pair_value_mut(newPair, keyRound8Size), value, valueContext->sizeOfType);
    
        const size_t actualIndex = index + i;
        self->hashMasks[actualIndex] = pairMask.value;
        group_pair_buf_start_mut(self)[actualIndex] = newPair;

        self->pairCount += 1;
        return;
    }

    unreachable();
}

static bool group_erase(Group* self, const void* key, const CubsTypeContext* keyContext, const CubsTypeContext* valueContext, CubsHashPairBitmask pairMask, PairHeader** iterFirst, PairHeader** iterLast) {
    const size_t found = group_find(self, key, keyContext, pairMask);
    if(found == -1) {
        return false;
    }

    self->hashMasks[found] = 0;
    PairHeader* pair = group_pair_buf_start_mut(self)[found];
    pair_deinit(pair, keyContext, valueContext, iterFirst, iterLast);
    self->pairCount -= 1;

    return true;
}

typedef struct {
    Group* groupsArray;
    size_t groupCount;
    size_t available;
    PairHeader* iterFirst;
    PairHeader* iterLast;
} Metadata;

/// May return NULL
static const Metadata* map_metadata(const CubsMap* self) {
    return (const Metadata*)&self->_metadata;
}

/// May return NULL
static Metadata* map_metadata_mut(CubsMap* self) {
    return (Metadata*)&self->_metadata;
}

static void map_ensure_total_capacity(CubsMap* self) {
    Metadata* metadata = map_metadata_mut(self);

    size_t newGroupCount;
    {
        if(metadata->groupCount == 0) {
            newGroupCount = 1;
        } else {
            if(metadata->available != 0) {
                return;
            }
            assert(metadata->groupCount != 0);
            newGroupCount = metadata->groupCount << 1;
        }
    }

    Group* newGroups = (Group*)cubs_malloc(sizeof(Group) * newGroupCount, _Alignof(Group));
    for(size_t i = 0; i < newGroupCount; i++) {
        newGroups[i] = group_init();
    }

    if(metadata->groupCount == 0) {
        const size_t DEFAULT_AVAILABLE = (size_t)(((float)GROUP_ALLOC_SIZE) * 0.8f);
        const Metadata newMetadata = {.available = DEFAULT_AVAILABLE, .groupCount = newGroupCount, .iterFirst = NULL, .iterLast = NULL, .groupsArray = newGroups};
        *metadata = newMetadata;
        return;
    } else {
        const size_t availableEntries = GROUP_ALLOC_SIZE * newGroupCount;
        const size_t newAvailable = (availableEntries * 4) / 5; // * 0.8 for load factor

        for(size_t oldGroupCount = 0; oldGroupCount < metadata->groupCount; oldGroupCount++) {
            Group* oldGroup = &metadata->groupsArray[oldGroupCount];
            if(oldGroup->pairCount != 0) {
                for(uint32_t hashMaskIter = 0; hashMaskIter < oldGroup->capacity; hashMaskIter++) {
                    if(oldGroup->hashMasks[hashMaskIter] == 0) {
                        continue;
                    }

                    PairHeader* pair = group_pair_buf_start_mut(oldGroup)[hashMaskIter];
                    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(pair->hashCode);
                    const size_t groupIndex = groupBitmask.value % newGroupCount;

                    Group* newGroup = &newGroups[groupIndex];
                    group_ensure_total_capacity(newGroup, newGroup->pairCount + 1);
                        
                    newGroup->hashMasks[newGroup->pairCount] = oldGroup->hashMasks[hashMaskIter];
                    group_pair_buf_start_mut(newGroup)[newGroup->pairCount] = pair; // Move pair to new group
                    newGroup->pairCount += 1;
                }
            }

            group_free(oldGroup);
        }

        if(metadata->groupCount > 0) {
            cubs_free((void*)metadata->groupsArray, sizeof(Group) * metadata->groupCount, _Alignof(Group));
        }     

        const Metadata newMetadata = {.available = newAvailable, .groupCount = newGroupCount, .iterFirst = metadata->iterFirst, .iterLast = metadata->iterLast, .groupsArray = newGroups};    
        *metadata = newMetadata;     
    }
}

// CubsMap cubs_map_init_primitives(CubsValueTag keyTag, CubsValueTag valueTag)
// {
//     assert(keyTag != cubsValueTagUserClass && "Use cubs_map_init_user_struct for user defined structs");
//     assert(valueTag != cubsValueTagUserClass && "Use cubs_map_init_user_struct for user defined structs");

//     return cubs_map_init_user_struct(cubs_primitive_context_for_tag(keyTag), cubs_primitive_context_for_tag(valueTag));
// }

CubsMap cubs_map_init(const CubsTypeContext *keyContext, const CubsTypeContext *valueContext)
{
    assert(keyContext != NULL);
    assert(valueContext != NULL);
    assert(keyContext->eql != NULL && "Map's keyContext must contain a valid equality function pointer");
    assert(keyContext->hash != NULL && "Map's keyContext must contain a valid hashing function pointer");
    const CubsMap out = {.len = 0, ._metadata = {0}, .keyContext = keyContext, .valueContext = valueContext};
    return out;
}

void cubs_map_deinit(CubsMap *self)
{
    Metadata* metadata = map_metadata_mut(self);
    if(metadata->groupsArray == NULL) {
        return;
    }

    for(size_t i = 0; i < metadata->groupCount; i++) {
        group_deinit(&metadata->groupsArray[i], self->keyContext, self->valueContext, &metadata->iterFirst, &metadata->iterLast);
    }

    cubs_free((void*)metadata->groupsArray, sizeof(Group) * metadata->groupCount, _Alignof(Group));
    metadata->groupsArray = NULL;
}

CubsMap cubs_map_clone(const CubsMap *self)
{
    if(self->len == 0) {
        const CubsMap map = {.len = 0, ._metadata = {0}, .keyContext = self->keyContext, .valueContext = self->valueContext};
        return map;
    }

    const Metadata* selfMetadata = map_metadata(self);
    const size_t newGroupCount = selfMetadata->groupCount; // there probably is a more optimal way to do this

    Group* newGroups = (Group*)cubs_malloc(sizeof(Group) * newGroupCount, _Alignof(Group));
    for(size_t i = 0; i < newGroupCount; i++) {
        newGroups[i] = group_init();
    }

    CubsMap newSelf = cubs_map_init(self->keyContext, self->valueContext);
    newSelf.len = self->len;
    const Metadata newMetadataData = {
        .available = ((GROUP_ALLOC_SIZE * newGroupCount * 4) / 5) - self->len, // * 0.8 for load factor
        .groupCount = newGroupCount,
        .groupsArray = newGroups,
        .iterFirst = NULL,
        .iterLast = NULL,
    };
    Metadata* newMetadata = map_metadata_mut(&newSelf);
    *newMetadata = newMetadataData;

    void* keyTempStorage = cubs_malloc(self->keyContext->sizeOfType, _Alignof(size_t));
    void* valueTempStorage = cubs_malloc(self->valueContext->sizeOfType, _Alignof(size_t));

    CubsMapConstIter iter = cubs_map_const_iter_begin(self);
    size_t hashCode = ((PairHeader*)iter._nextIter)->hashCode;
    while(cubs_map_const_iter_next(&iter)) {   
        const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
        const size_t groupIndex = groupBitmask.value % newMetadata->groupCount;
    
        self->keyContext->clone(keyTempStorage, iter.key);
        self->valueContext->clone(valueTempStorage, iter.value);

        group_insert(&newMetadata->groupsArray[groupIndex], keyTempStorage, valueTempStorage, self->keyContext, self->valueContext, hashCode, &newMetadata->iterFirst, &newMetadata->iterLast); 
    }

    cubs_free(keyTempStorage, self->keyContext->sizeOfType, _Alignof(size_t));
    cubs_free(valueTempStorage, self->valueContext->sizeOfType, _Alignof(size_t));

    return newSelf;
}

const void* cubs_map_find(const CubsMap *self, const void *key)
{
    if(self->len == 0) {
        return NULL;
    }
    const Metadata* metadata = map_metadata(self);

    assert(self->keyContext->hash != NULL);
    const size_t hashCode = self->keyContext->hash(key);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;
    const Group* group = &metadata->groupsArray[groupIndex];

    const size_t found = group_find(group, key, self->keyContext, cubs_hash_pair_bitmask_init(hashCode));
    if(found == -1) {
        return NULL;
    }

    const size_t round8Size = ROUND_SIZE_TO_MULTIPLE_OF_8(self->keyContext->sizeOfType);

    return pair_value(group_pair_buf_start(group)[found], round8Size);
}

void* cubs_map_find_mut(CubsMap *self, const void *key)
{
    if(self->len == 0) {
        return NULL;
    }
    Metadata* metadata = map_metadata_mut(self);

    assert(self->keyContext->hash != NULL);
    const size_t hashCode = self->keyContext->hash(key);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;
    Group* group = &metadata->groupsArray[groupIndex];

    const size_t found = group_find(group, key, self->keyContext, cubs_hash_pair_bitmask_init(hashCode));
    if(found == -1) {
        return NULL;
    }

    const size_t round8Size = ROUND_SIZE_TO_MULTIPLE_OF_8(self->keyContext->sizeOfType);

    return pair_value_mut(group_pair_buf_start_mut(group)[found], round8Size);
}

void cubs_map_insert(CubsMap *self, void* key, void* value)
{
    map_ensure_total_capacity(self);
    
    Metadata* metadata = map_metadata_mut(self);
    
    assert(self->keyContext->hash != NULL);
    const size_t hashCode = self->keyContext->hash(key);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;

    group_insert(&metadata->groupsArray[groupIndex], key, value, self->keyContext, self->valueContext, hashCode, &metadata->iterFirst, &metadata->iterLast);
    self->len += 1;
    metadata->available -= 1;
}

bool cubs_map_erase(CubsMap *self, const void *key)
{
    if(self->len == 0) {
        return false;
    }

    Metadata* metadata = map_metadata_mut(self);

    assert(self->keyContext->hash != NULL);
    const size_t hashCode = self->keyContext->hash(key);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;

    const bool result = group_erase(&metadata->groupsArray[groupIndex], key, self->keyContext, self->valueContext, cubs_hash_pair_bitmask_init(hashCode), &metadata->iterFirst, &metadata->iterLast);
    if(result) {
        self->len -= 1;
        metadata->available += 1; 
    }
    return result;
}

bool cubs_map_eql(const CubsMap *self, const CubsMap *other)
{   
    assert(self->keyContext->sizeOfType == other->keyContext->sizeOfType);
    assert(self->keyContext->eql != NULL);
    assert(other->keyContext->eql != NULL);
    assert(self->keyContext->eql == other->keyContext->eql);

    assert(self->valueContext->sizeOfType == other->valueContext->sizeOfType);
    assert(self->valueContext->eql != NULL);
    assert(other->valueContext->eql != NULL);
    assert(self->valueContext->eql == other->valueContext->eql);

    if(self->len != other->len) {
        return false;
    }

    CubsMapConstIter selfIter = cubs_map_const_iter_begin(self);
    CubsMapConstIter otherIter = cubs_map_const_iter_begin(other);

    while(true) {
        bool selfNext = cubs_map_const_iter_next(&selfIter);
        bool otherNext = cubs_map_const_iter_next(&otherIter);

        assert(selfNext == otherNext);

        // Went through all elements
        if(selfNext == false) {
            return true;
        }

        if(self->keyContext->eql(selfIter.key, otherIter.key) == false) {
            return false;
        }
        if(self->valueContext->eql(selfIter.value, otherIter.value) == false) {
            return false;
        }
    }
}

size_t cubs_map_hash(const CubsMap *self)
{
    assert(self->keyContext->hash != NULL);
    assert(self->valueContext->hash != NULL);

    CubsMapConstIter selfIter = cubs_map_const_iter_begin(self);
    
    const size_t globalHashSeed = cubs_hash_seed();
    size_t h = globalHashSeed;

    while(cubs_map_const_iter_next(&selfIter)) {
        const size_t hashedKey = self->keyContext->hash(selfIter.key);
        const size_t hashedValue = self->valueContext->hash(selfIter.value);
        const size_t combinedHash = cubs_combine_hash(hashedKey, hashedValue);
        h = cubs_combine_hash(combinedHash, h);
    }

    return h;
}

CubsMapConstIter cubs_map_const_iter_begin(const CubsMap* self)
{
    const Metadata* metadata = map_metadata(self);
    const CubsMapConstIter iter = {
        ._map = self,
        ._nextIter = (const void*)metadata->iterFirst, // If `iterFirst == NULL`, means an 0 length iterator
        .key = NULL, 
        .value = NULL,
    };
    return iter;
}

CubsMapConstIter cubs_map_const_iter_end(const CubsMap *self)
{
    const CubsMapConstIter iter = {
        ._map = self,
        ._nextIter = NULL,
        .key = NULL,
        .value = NULL,
    };
    return iter;
}

bool cubs_map_const_iter_next(CubsMapConstIter *iter)
{
    if(iter->_nextIter == NULL) {
        iter->key = NULL; // For C++
        iter->value = NULL;
        return false;
    }

    const Metadata* metadata = map_metadata(iter->_map);
    PairHeader* currentPair = ((PairHeader*)iter->_nextIter);
    if(currentPair == metadata->iterLast) {
        const CubsMapConstIter newIter = {
            ._map = iter->_map,
            ._nextIter = NULL,
            .key = pair_key(currentPair),
            .value = pair_value(currentPair, iter->_map->keyContext->sizeOfType),
        };
        *iter = newIter;
    } else {
        assert(currentPair->iterAfter != NULL);
        const CubsMapConstIter newIter = {
            ._map = iter->_map,
            ._nextIter = (const void*)currentPair->iterAfter,
            .key = pair_key(currentPair),
            .value = pair_value(currentPair, iter->_map->keyContext->sizeOfType),
        };
        *iter = newIter;
    }    
    return true;
}

CubsMapMutIter cubs_map_mut_iter_begin(CubsMap *self)
{
    Metadata* metadata = map_metadata_mut(self);
    const CubsMapMutIter iter = {
        ._map = self,
        ._nextIter = (void*)metadata->iterFirst, // If `iterFirst == NULL`, means an 0 length iterator
        .key = NULL, 
        .value = NULL,
    };
    return iter;
}

CubsMapMutIter cubs_map_mut_iter_end(CubsMap *self)
{
    const CubsMapMutIter iter = {
        ._map = self,
        ._nextIter = NULL,
        .key = NULL,
        .value = NULL,
    };
    return iter;
}

bool cubs_map_mut_iter_next(CubsMapMutIter *iter)
{
    if(iter->_nextIter == NULL) {
        iter->key = NULL; // For C++
        iter->value = NULL;
        return false;
    }
    
    const size_t round8Size = ROUND_SIZE_TO_MULTIPLE_OF_8(iter->_map->keyContext->sizeOfType);

    Metadata* metadata = map_metadata_mut(iter->_map);
    PairHeader* currentPair = ((PairHeader*)iter->_nextIter);
    if(currentPair == metadata->iterLast) {
        const CubsMapMutIter newIter = {
            ._map = iter->_map,
            ._nextIter = NULL,
            .key = pair_key(currentPair),
            .value = pair_value_mut(currentPair, round8Size),
        };
        *iter = newIter;
    } else {
        assert(currentPair->iterAfter != NULL);
        const CubsMapMutIter newIter = {
            ._map = iter->_map,
            ._nextIter = (void*)currentPair->iterAfter,
            .key = pair_key(currentPair),
            .value = pair_value_mut(currentPair, round8Size),
        };
        *iter = newIter;
    }    
    return true;
}

CubsMapReverseConstIter cubs_map_reverse_const_iter_begin(const CubsMap *self)
{
    const Metadata* metadata = map_metadata(self);
    const CubsMapReverseConstIter iter = {
        ._map = self,
        ._nextIter = (const void*)metadata->iterLast, // If `iterLast == NULL`, means an 0 length iterator
        .key = NULL, 
        .value = NULL,
    };
    return iter;
}

CubsMapReverseConstIter cubs_map_reverse_const_iter_end(const CubsMap *self)
{
    const CubsMapReverseConstIter iter = {
        ._map = self,
        ._nextIter = NULL,
        .key = NULL,
        .value = NULL,
    };
    return iter;
}

bool cubs_map_reverse_const_iter_next(CubsMapReverseConstIter *iter)
{
    if(iter->_nextIter == NULL) {
        iter->key = NULL; // For C++
        iter->value = NULL;
        return false;
    }

    const Metadata* metadata = map_metadata(iter->_map);
    PairHeader* currentPair = ((PairHeader*)iter->_nextIter);
    if(currentPair == metadata->iterFirst) {
        const CubsMapReverseConstIter newIter = {
            ._map = iter->_map,
            ._nextIter = NULL,
            .key = pair_key(currentPair),
            .value = pair_value(currentPair, iter->_map->keyContext->sizeOfType),
        };
        *iter = newIter;
    } else {
        assert(currentPair->iterBefore != NULL);
        const CubsMapReverseConstIter newIter = {
            ._map = iter->_map,
            ._nextIter = (const void*)currentPair->iterBefore,
            .key = pair_key(currentPair),
            .value = pair_value(currentPair, iter->_map->keyContext->sizeOfType),
        };
        *iter = newIter;
    }    
    return true;
}

CubsMapReverseMutIter cubs_map_reverse_mut_iter_begin(CubsMap* self) {
    Metadata* metadata = map_metadata_mut(self);
    const CubsMapReverseMutIter iter = {
        ._map = self,
        ._nextIter = (void*)metadata->iterLast, // If `iterLast == NULL`, means an 0 length iterator
        .key = NULL, 
        .value = NULL,
    };
    return iter;
}

CubsMapReverseMutIter cubs_map_reverse_mut_iter_end(CubsMap* self) {
    const CubsMapReverseMutIter iter = {
        ._map = self,
        ._nextIter = NULL,
        .key = NULL,
        .value = NULL,
    };
    return iter;
}

bool cubs_map_reverse_mut_iter_next(CubsMapReverseMutIter* iter) {
    if(iter->_nextIter == NULL) {
        iter->key = NULL; // For C++
        iter->value = NULL;
        return false;
    }

    const size_t round8Size = ROUND_SIZE_TO_MULTIPLE_OF_8(iter->_map->keyContext->sizeOfType);

    Metadata* metadata = map_metadata_mut(iter->_map);
    PairHeader* currentPair = ((PairHeader*)iter->_nextIter);
    if(currentPair == metadata->iterFirst) {
        const CubsMapReverseMutIter newIter = {
            ._map = iter->_map,
            ._nextIter = NULL,
            .key = pair_key(currentPair),
            .value = pair_value_mut(currentPair, round8Size),
        };
        *iter = newIter;
    } else {
        assert(currentPair->iterBefore != NULL);
        const CubsMapReverseMutIter newIter = {
            ._map = iter->_map,
            ._nextIter = (void*)currentPair->iterBefore,
            .key = pair_key(currentPair),
            .value = pair_value_mut(currentPair, round8Size),
        };
        *iter = newIter;
    }    
    return true;
}