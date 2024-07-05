#include "set.h"
#include <assert.h>
#include "../../util/global_allocator.h"
#include <string.h>
#include "../../util/panic.h"
#include "../../util/unreachable.h"
#include <stdio.h>
#include "../../util/hash.h"
#include "../../util/bitwise.h"
#include "../string/string.h"
#include "../primitives_context.h"
#include "../../util/simd.h"

static const size_t GROUP_ALLOC_SIZE = 32;
static const size_t ALIGNMENT = 32;
static const size_t DATA_BITMASK = 0xFFFFFFFFFFFFULL;
static const size_t TAG_SHIFT = 48;
static const size_t TAG_BITMASK = 0xFFULL << 48;
static const size_t TYPE_SIZE_SHIFT = 56;
static const size_t TYPE_SIZE_BITMASK = 0xFFULL << 56;
static const size_t NON_DATA_BITMASK = ~(0xFFFFFFFFFFFFULL);

typedef struct KeyHeader KeyHeader;

typedef struct KeyHeader {
    size_t hashCode;
    KeyHeader* iterBefore;
    KeyHeader* iterAfter;
} KeyHeader;

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

static const KeyHeader** group_key_buf_start(const Group* group) {
    const KeyHeader** bufStart = (const KeyHeader**)&group->hashMasks[group->capacity];
    return bufStart;
}

static KeyHeader** group_key_buf_start_mut(Group* group) {
    KeyHeader** bufStart = (KeyHeader**)&group->hashMasks[group->capacity];
    return bufStart;
}

/// Get the memory of the key of the header.
static const void* key_of_header(const KeyHeader* header) {
    return (const void*)(&header[1]);
}

/// Get the memory of the key of the header.
static void* key_of_header_mut(KeyHeader* header) {
    return (void*)(&header[1]);
}

static void key_header_deinit(KeyHeader* header, const CubsStructContext* keyContext, KeyHeader** iterFirst, KeyHeader** iterLast) {
    // Change iterator doubly-linked list
    KeyHeader* before = header->iterBefore;
    KeyHeader* after = header->iterAfter;
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
    
    if(keyContext->destructor != NULL) {
        keyContext->destructor(key_of_header_mut(header));
    }

    cubs_free((void*)header, sizeof(KeyHeader) + keyContext->powOf8Size, _Alignof(size_t));
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
static void group_deinit(Group* self, const CubsStructContext* keyContext, KeyHeader** iterFirst, KeyHeader** iterLast) {
    if(self->pairCount != 0) {
        for(uint32_t i = 0; i < self->capacity; i++) {
            if(self->hashMasks[i] == 0) {
                continue;
            }
            
            key_header_deinit(group_key_buf_start_mut(self)[i], keyContext, iterFirst, iterLast);
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
        newPairStart[moveIter] = group_key_buf_start_mut(self)[i]; 
        moveIter += 1;
    }

    group_free(self);

    self->hashMasks = newHashMaskStart;
    self->capacity = pairAllocCapacity;
    return;
}

/// Returns -1 if not found
static size_t group_find(const Group* self, const void* key, const CubsStructContext* keyContext, CubsHashPairBitmask pairMask) {   
    size_t i = 0;
    while(i < self->capacity) {
        uint32_t resultMask = _cubs_simd_cmpeq_mask_8bit_32wide_aligned(pairMask.value, &self->hashMasks[i]);
        while(true) { // check each bit
            uint32_t index;
            if(!countTrailingZeroes32(&index, resultMask)) {
                i += 32;
                break;
            }

            const size_t actualIndex = index + i;
            const void* pair = group_key_buf_start(self)[actualIndex];
            const void* pairKey = key_of_header(pair);
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
static void group_insert(Group* self, void* key, const CubsStructContext* keyContext, size_t hashCode, KeyHeader** iterFirst, KeyHeader** iterLast) {
    #if _DEBUG
    if(*iterLast != NULL) {
        assert((*iterLast)->iterAfter == NULL);
    }
    #endif
    
    const CubsHashPairBitmask pairMask = cubs_hash_pair_bitmask_init(hashCode);
    const size_t existingIndex = group_find(self, &key, keyContext, pairMask);
    
    if(existingIndex != -1) {
        if(keyContext->destructor != NULL) {
            keyContext->destructor(key);  // don't need duplicate keys
        }
        return;
    }

    group_ensure_total_capacity(self, self->pairCount + 1);
  
    size_t i = 0;
    while(i < self->capacity) {
        size_t index;
        if(!_cubs_simd_index_of_first_zero_8bit_32wide_aligned(&index, &self->hashMasks[i])) {
            i += 32;
            continue;
        }

        KeyHeader* newPair = (KeyHeader*)cubs_malloc(sizeof(KeyHeader) + keyContext->powOf8Size, _Alignof(size_t));
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

        memcpy(key_of_header_mut(newPair), key, keyContext->sizeOfType);
    
        const size_t actualIndex = index + i;
        self->hashMasks[actualIndex] = pairMask.value;
        group_key_buf_start_mut(self)[actualIndex] = newPair;

        self->pairCount += 1;
        return;
    }

    unreachable();
}

static bool group_erase(Group* self, const void* key, const CubsStructContext* keyContext, CubsHashPairBitmask pairMask, KeyHeader** iterFirst, KeyHeader** iterLast) {
    const size_t found = group_find(self, key, keyContext, pairMask);
    if(found == -1) {
        return false;
    }

    self->hashMasks[found] = 0;
    KeyHeader* pair = group_key_buf_start_mut(self)[found];
    key_header_deinit(pair, keyContext, iterFirst, iterLast);
    self->pairCount -= 1;

    return true;
}

typedef struct {
    Group* groupsArray;
    size_t groupCount;
    size_t available;
    KeyHeader* iterFirst;
    KeyHeader* iterLast;
} Metadata;

/// May return NULL
static const Metadata* map_metadata(const CubsSet* self) {
    return (const Metadata*)&self->_metadata;
}

/// May return NULL
static Metadata* map_metadata_mut(CubsSet* self) {
    return (Metadata*)&self->_metadata;
}

static void map_ensure_total_capacity(CubsSet* self) {
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

                    KeyHeader* pair = group_key_buf_start_mut(oldGroup)[hashMaskIter];
                    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(pair->hashCode);
                    const size_t groupIndex = groupBitmask.value % newGroupCount;

                    Group* newGroup = &newGroups[groupIndex];
                    group_ensure_total_capacity(newGroup, newGroup->pairCount + 1);
                        
                    newGroup->hashMasks[newGroup->pairCount] = oldGroup->hashMasks[hashMaskIter];
                    group_key_buf_start_mut(newGroup)[newGroup->pairCount] = pair; // Move pair to new group
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

CubsSet cubs_set_init_primitive(CubsValueTag tag)
{
    assert(tag != cubsValueTagUserClass && "Use cubs_set_init_user_class for user defined classes");

    return cubs_set_init_user_struct(cubs_primitive_context_for_tag(tag));
}

CubsSet cubs_set_init_user_struct(const CubsStructContext *context)
{
    assert(context->eql != NULL && "Map's keyContext must contain a valid equality function pointer");
    assert(context->hash != NULL && "Map's keyContext must contain a valid hashing function pointer");
    const CubsSet out = {.len = 0, ._metadata = {0}, .context = context};
    return out;
}

void cubs_set_deinit(CubsSet *self)
{
    Metadata* metadata = map_metadata_mut(self);
    if(metadata->groupsArray == NULL) {
        return;
    }

    for(size_t i = 0; i < metadata->groupCount; i++) {
        group_deinit(&metadata->groupsArray[i], self->context, &metadata->iterFirst, &metadata->iterLast);
    }

    cubs_free((void*)metadata->groupsArray, sizeof(Group) * metadata->groupCount, _Alignof(Group));
    metadata->groupsArray = NULL;
}

CubsSet cubs_set_clone(const CubsSet *self)
{
    if(self->len == 0) {
        const CubsSet map = {.len = 0, ._metadata = {0}, .context = self->context};
        return map;
    }

    const Metadata* selfMetadata = map_metadata(self);
    const size_t newGroupCount = selfMetadata->groupCount; // there probably is a more optimal way to do this

    Group* newGroups = (Group*)cubs_malloc(sizeof(Group) * newGroupCount, _Alignof(Group));
    for(size_t i = 0; i < newGroupCount; i++) {
        newGroups[i] = group_init();
    }

    CubsSet newSelf = cubs_set_init_user_struct(self->context);
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

    void* keyTempStorage = cubs_malloc(self->context->sizeOfType, _Alignof(size_t));

    CubsSetIter iter = cubs_set_iter_begin(self);
    size_t hashCode = ((KeyHeader*)iter._nextIter)->hashCode;
    while(cubs_set_iter_next(&iter)) {   
        const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
        const size_t groupIndex = groupBitmask.value % newMetadata->groupCount;
    
        self->context->clone(keyTempStorage, iter.key);

        group_insert(&newMetadata->groupsArray[groupIndex], keyTempStorage, self->context, hashCode, &newMetadata->iterFirst, &newMetadata->iterLast); 
    }

    cubs_free(keyTempStorage, self->context->sizeOfType, _Alignof(size_t));

    return newSelf;
}

bool cubs_set_contains(const CubsSet* self, const void* key)
{
    if(self->len == 0) {
        return NULL;
    }
    const Metadata* metadata = map_metadata(self);

    assert(self->context->hash != NULL);
    const size_t hashCode = self->context->hash(key);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;
    const Group* group = &metadata->groupsArray[groupIndex];

    const size_t found = group_find(group, key, self->context, cubs_hash_pair_bitmask_init(hashCode));
    return found != -1;
}

void cubs_set_insert(CubsSet *self, void* key)
{
    map_ensure_total_capacity(self);
    
    Metadata* metadata = map_metadata_mut(self);
    
    assert(self->context->hash != NULL);
    const size_t hashCode = self->context->hash(key);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;

    group_insert(&metadata->groupsArray[groupIndex], key, self->context, hashCode, &metadata->iterFirst, &metadata->iterLast);
    self->len += 1;
    metadata->available -= 1;
}

bool cubs_set_erase(CubsSet *self, const void *key)
{
    if(self->len == 0) {
        return false;
    }

    Metadata* metadata = map_metadata_mut(self);

    assert(self->context->hash != NULL);
    const size_t hashCode = self->context->hash(key);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % metadata->groupCount;

    const bool result = group_erase(&metadata->groupsArray[groupIndex], key, self->context, cubs_hash_pair_bitmask_init(hashCode), &metadata->iterFirst, &metadata->iterLast);
    if(result) {
        self->len -= 1;
        metadata->available += 1; 
    }
    return result;
}

bool cubs_set_eql(const CubsSet *self, const CubsSet *other)
{   
    assert(self->context->sizeOfType == other->context->sizeOfType);
    assert(self->context->eql != NULL);
    assert(other->context->eql != NULL);
    assert(self->context->eql == other->context->eql);

    if(self->len != other->len) {
        return false;
    }

    CubsSetIter selfIter = cubs_set_iter_begin(self);
    CubsSetIter otherIter = cubs_set_iter_begin(other);

    while(true) {
        bool selfNext = cubs_set_iter_next(&selfIter);
        bool otherNext = cubs_set_iter_next(&otherIter);

        assert(selfNext == otherNext);

        // Went through all elements
        if(selfNext == false) {
            return true;
        }

        if(self->context->eql(selfIter.key, otherIter.key) == false) {
            return false;
        }
    }
}

size_t cubs_set_hash(const CubsSet *self)
{
    assert(self->context->hash != NULL);

    CubsSetIter selfIter = cubs_set_iter_begin(self);
    
    const size_t globalHashSeed = cubs_hash_seed();
    size_t h = globalHashSeed;

    while(cubs_set_iter_next(&selfIter)) {
        const size_t hashedKey = self->context->hash(selfIter.key);
        h = cubs_combine_hash(hashedKey, h);
    }

    return h;
}

CubsSetIter cubs_set_iter_begin(const CubsSet* self)
{
    const Metadata* metadata = map_metadata(self);
    const CubsSetIter iter = {
        ._set = self,
        ._nextIter = (const void*)metadata->iterFirst, // If `iterFirst == NULL`, means an 0 length iterator
        .key = NULL, 
    };
    return iter;
}

CubsSetIter cubs_set_iter_end(const CubsSet *self)
{
    const CubsSetIter iter = {
        ._set = self,
        ._nextIter = NULL,
        .key = NULL,
    };
    return iter;
}

bool cubs_set_iter_next(CubsSetIter *iter)
{
    if(iter->_nextIter == NULL) {
        iter->key = NULL; // For C++
        return false;
    }

    const Metadata* metadata = map_metadata(iter->_set);
    KeyHeader* currentPair = ((KeyHeader*)iter->_nextIter);
    if(currentPair == metadata->iterLast) {
        const CubsSetIter newIter = {
            ._set = iter->_set,
            ._nextIter = NULL,
            .key = key_of_header(currentPair),
        };
        *iter = newIter;
    } else {
        assert(currentPair->iterAfter != NULL);
        const CubsSetIter newIter = {
            ._set = iter->_set,
            ._nextIter = (const void*)currentPair->iterAfter,
            .key = key_of_header(currentPair),
        };
        *iter = newIter;
    }    
    return true;
}

CubsSetReverseIter cubs_set_reverse_iter_begin(const CubsSet *self)
{
    const Metadata* metadata = map_metadata(self);
    const CubsSetReverseIter iter = {
        ._set = self,
        ._nextIter = (const void*)metadata->iterLast, // If `iterLast == NULL`, means an 0 length iterator
        .key = NULL, 
    };
    return iter;
}

CubsSetReverseIter cubs_set_reverse_iter_end(const CubsSet *self)
{
    const CubsSetReverseIter iter = {
        ._set = self,
        ._nextIter = NULL,
        .key = NULL,
    };
    return iter;
}

bool cubs_set_reverse_iter_next(CubsSetReverseIter *iter)
{
    if(iter->_nextIter == NULL) {
        iter->key = NULL; // For C++
        return false;
    }

    const Metadata* metadata = map_metadata(iter->_set);
    KeyHeader* currentPair = ((KeyHeader*)iter->_nextIter);
    if(currentPair == metadata->iterFirst) {
        const CubsSetReverseIter newIter = {
            ._set = iter->_set,
            ._nextIter = NULL,
            .key = key_of_header(currentPair),
        };
        *iter = newIter;
    } else {
        assert(currentPair->iterBefore != NULL);
        const CubsSetReverseIter newIter = {
            ._set = iter->_set,
            ._nextIter = (const void*)currentPair->iterBefore,
            .key = key_of_header(currentPair),
        };
        *iter = newIter;
    }    
    return true;
}