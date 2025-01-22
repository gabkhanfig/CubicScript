#ifndef STRING_SLICE_POINTER_MAP_H
#define STRING_SLICE_POINTER_MAP_H

#include <assert.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include "../primitives/string/string_slice.h"
#include "protected_arena.h"
#include "../util/hash.h"
#include "../util/simd.h"
#include "../util/bitwise.h"
#include "../util/panic.h"
#include "../util/unreachable.h"

static const size_t GROUP_ALLOC_SIZE = 16;
static const size_t ALIGNMENT = 16;

typedef struct _GenericPair {
    size_t hashCode;
    CubsStringSlice name;
    void* object;
} _GenericPair;

typedef struct _GenericQualifiedGroup {
    /// The actual pairs start at `&hashMasks[capacity]`
    uint8_t* hashMasks;
    uint32_t pairCount;
    uint32_t capacity;
    // Use uint32_t to save 8 bytes in total. If a map has more than 4.29 billion entires in a single group,
    // then the load balancing and/or hashing implementation is poor.
    // uint16_t is not viable here because of forced alignment and padding.
} _GenericQualifiedGroup;

/// Cannot use strcmp because the slices may not be null terminated
static inline bool string_slices_eql(CubsStringSlice s1, CubsStringSlice s2) {
    if(s1.len != s2.len) {
        return false;
    }

    for(size_t i = 0; i < s1.len; i++) {
        if(s1.str[i] != s2.str[i]) {
            return false;
        }
    }
    return true;
}

static inline size_t group_allocation_size(size_t requiredCapacity) {
    assert(requiredCapacity % ALIGNMENT == 0);

    return requiredCapacity + (sizeof(_GenericPair) * requiredCapacity);
}

static inline const _GenericPair* qualified_group_pair_buf_start(const _GenericQualifiedGroup* group) {
    const _GenericPair* bufStart = (const _GenericPair*)&group->hashMasks[group->capacity];
    return bufStart;
}

static inline _GenericPair* qualified_group_pair_buf_start_mut(_GenericQualifiedGroup* group) {
    _GenericPair* bufStart = (_GenericPair*)&group->hashMasks[group->capacity];
    return bufStart;
}

static inline _GenericQualifiedGroup qualified_group_init(ProtectedArena* arena) {
    const size_t initialAllocationSize = group_allocation_size(GROUP_ALLOC_SIZE);
    void* mem = cubs_protected_arena_malloc(arena, initialAllocationSize, ALIGNMENT);
    memset(mem, 0, initialAllocationSize);

    _GenericQualifiedGroup group;
    group.hashMasks = (uint8_t*)mem;
    group.capacity = (uint32_t)GROUP_ALLOC_SIZE;
    group.pairCount = 0;
    return group;
}

static inline void qualified_group_deinit(_GenericQualifiedGroup* self, ProtectedArena* arena) {
    const size_t currentAllocationSize = group_allocation_size(self->capacity);
    cubs_protected_arena_free(arena, (void*)self->hashMasks);
}

static inline void qualified_group_ensure_total_capacity(_GenericQualifiedGroup* self, ProtectedArena* arena, size_t minCapacity) {
    if(minCapacity <= self->capacity) {
        return;
    }

    const size_t remainder = minCapacity % ALIGNMENT;
    const size_t pairAllocCapacity = minCapacity + (ALIGNMENT - remainder);
    const size_t mallocCapacity =  group_allocation_size(pairAllocCapacity);

    void* mem = cubs_protected_arena_malloc(arena, mallocCapacity, ALIGNMENT);
    memset(mem, 0, mallocCapacity);

    uint8_t* newHashMaskStart = (uint8_t*)mem;
    _GenericPair* newPairStart = (_GenericPair*)&((uint8_t*)mem)[pairAllocCapacity];
    size_t moveIter = 0;
    for(uint32_t i = 0; i < self->capacity; i++) {
        if(self->hashMasks[i] == 0) {
            continue;
        }


        newHashMaskStart[moveIter] = self->hashMasks[i];
        // Copy over the pointer to the pair info, transferring ownership
        newPairStart[moveIter] = qualified_group_pair_buf_start_mut(self)[i];
        moveIter += 1;
    }

    qualified_group_deinit(self, arena);

    self->hashMasks = newHashMaskStart;
    self->capacity = (uint32_t)pairAllocCapacity;
    return;
}

/// Returns -1 if not found
static inline size_t qualified_group_find(const _GenericQualifiedGroup* self, CubsStringSlice name, CubsHashPairBitmask pairMask) {   
    uint32_t i = 0;
    while(i < self->capacity) {
        uint16_t resultMask = _cubs_simd_cmpeq_mask_8bit_16wide_aligned(pairMask.value, &self->hashMasks[i]);
        while(true) { // check each bit
            uint32_t index;
            if(!countTrailingZeroes32(&index, (uint32_t)resultMask)) {
                i += 16;
                break;
            }

            const size_t actualIndex = index + i;
            _GenericPair pair = qualified_group_pair_buf_start(self)[actualIndex];
            if((name.len != pair.name.len) || !string_slices_eql(name, pair.name)) {        
                resultMask = (resultMask & ~(1U << index));
                continue;
            }
            return actualIndex;
        }
    }

    return -1;
}

/// The entry must not already exist
static inline void qualified_group_insert(_GenericQualifiedGroup* self, ProtectedArena* arena, _GenericPair pair) {
    const CubsHashPairBitmask pairMask = cubs_hash_pair_bitmask_init(pair.hashCode);

    #if _DEBUG
    {
        const size_t existingIndex = qualified_group_find(self, pair.name, pairMask);
    
        if(existingIndex != -1) {
            fprintf(stderr, "Duplicate functions found: %s\n", pair.name.str);
            cubs_panic("Duplicate functions found\n");
        }
    }    
    #endif
        
    qualified_group_ensure_total_capacity(self, arena, self->pairCount + 1);
  
    uint32_t i = 0;
    while(i < self->capacity) {
        size_t index;
        if(!_cubs_simd_index_of_first_zero_8bit_16wide_aligned(&index, &self->hashMasks[i])) {
            i += 16;
            continue;
        }
    
        const size_t actualIndex = index + i;
        self->hashMasks[actualIndex] = pairMask.value;
        qualified_group_pair_buf_start_mut(self)[actualIndex] = pair;

        self->pairCount += 1;
        return;
    }

    unreachable();
}

typedef struct _GenericStringSlicePointerMap {
    /// An array holding all elements. Is valid to `self.elements[self.count - 1]`
    void** elements;
    size_t count;
    size_t capacity;
    struct _GenericQualifiedGroup* qualifiedGroups;
    size_t qualifiedGroupCount;
    size_t available;
} _GenericStringSlicePointerMap;

static inline void generic_map_ensure_total_capacity(_GenericStringSlicePointerMap* self, ProtectedArena* arena) {
    if(self->count == self->capacity) {
        const size_t newCapacity = self->capacity == 0 ? 16 : self->capacity << 1;

        const size_t ARRAY_ALIGNMENT = 8; // _Alignof(void*)
        void** newArray = (void**)cubs_protected_arena_malloc(
            arena, sizeof(void*) * newCapacity, ARRAY_ALIGNMENT);
        if(self->elements != NULL) {
            memcpy((void*)newArray, (const void*)self->elements, self->count);
            cubs_protected_arena_free(arena, (void*)self->elements);
        }
        self->elements = newArray;
        self->capacity = newCapacity;
    }

    size_t newGroupCount;
    {
        if(self->qualifiedGroupCount == 0) {
            newGroupCount = 1;
        } else {
            if(self->available != 0) {
                return;
            }
            assert(self->qualifiedGroupCount != 0);
            newGroupCount = self->qualifiedGroupCount << 1;
        }
    }

    const size_t GROUPS_ARRAY_ALIGNMENT = 8;
    _GenericQualifiedGroup* newGroups = (_GenericQualifiedGroup*)cubs_protected_arena_malloc(
        arena, sizeof(_GenericQualifiedGroup) * newGroupCount, GROUPS_ARRAY_ALIGNMENT);
    for(size_t i = 0; i < newGroupCount; i++) {
        newGroups[i] = qualified_group_init(arena);
    }

    if(self->qualifiedGroupCount == 0) {
        const size_t DEFAULT_AVAILABLE = (size_t)(((float)GROUP_ALLOC_SIZE) * 0.8f);
        self->available = DEFAULT_AVAILABLE;
        self->qualifiedGroups = newGroups;
        self->qualifiedGroupCount = newGroupCount;
        return;
    } else {
        const size_t availableEntries = GROUP_ALLOC_SIZE * newGroupCount;
        const size_t newAvailable = (availableEntries * 4) / 5; // * 0.8 for load factor

        for(size_t oldGroupCount = 0; oldGroupCount < self->qualifiedGroupCount; oldGroupCount++) {
            _GenericQualifiedGroup* oldGroup = &self->qualifiedGroups[oldGroupCount];
            if(oldGroup->pairCount != 0) {
                for(uint32_t hashMaskIter = 0; hashMaskIter < oldGroup->capacity; hashMaskIter++) {
                    if(oldGroup->hashMasks[hashMaskIter] == 0) {
                        continue;
                    }

                    _GenericPair pair = qualified_group_pair_buf_start_mut(oldGroup)[hashMaskIter];
                    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(pair.hashCode);
                    const size_t groupIndex = groupBitmask.value % newGroupCount;

                    _GenericQualifiedGroup* newGroup = &newGroups[groupIndex];
                    qualified_group_ensure_total_capacity(newGroup, arena, newGroup->pairCount + 1);
                        
                    newGroup->hashMasks[newGroup->pairCount] = oldGroup->hashMasks[hashMaskIter];
                    qualified_group_pair_buf_start_mut(newGroup)[newGroup->pairCount] = pair; // Move pair to new group
                    newGroup->pairCount += 1;
                }
            }

            qualified_group_deinit(oldGroup, arena);
        }

        if(self->qualifiedGroupCount > 0) {
            cubs_protected_arena_free(arena, (void*)self->qualifiedGroups);
        }     

        
        self->available = newAvailable;
        self->qualifiedGroups = newGroups;
        self->qualifiedGroupCount = newGroupCount;
    }
}

static inline const void* generic_string_pointer_map_find(const _GenericStringSlicePointerMap *self, CubsStringSlice fullyQualifiedName)
{
    if(self->count == 0) {
        return NULL;
    }

    #if _DEBUG
    if(fullyQualifiedName.len != 0) {
        assert(fullyQualifiedName.str != NULL);
    }
    #endif
    const size_t hashCode = bytes_hash((const void*)fullyQualifiedName.str, fullyQualifiedName.len);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % self->qualifiedGroupCount;
    const _GenericQualifiedGroup* group = &self->qualifiedGroups[groupIndex];

    const size_t found = qualified_group_find(group, fullyQualifiedName, cubs_hash_pair_bitmask_init(hashCode));
    if(found == -1) {
        return NULL;
    }

    return qualified_group_pair_buf_start(group)[found].object;
}

static inline void* generic_string_pointer_map_find_mut(_GenericStringSlicePointerMap *self, CubsStringSlice fullyQualifiedName)
{
    if(self->count == 0) {
        return NULL;
    }

    #if _DEBUG
    if(fullyQualifiedName.len != 0) {
        assert(fullyQualifiedName.str != NULL);
    }
    #endif
    const size_t hashCode = bytes_hash((const void*)fullyQualifiedName.str, fullyQualifiedName.len);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % self->qualifiedGroupCount;
    _GenericQualifiedGroup* group = &self->qualifiedGroups[groupIndex];

    const size_t found = qualified_group_find(group, fullyQualifiedName, cubs_hash_pair_bitmask_init(hashCode));
    if(found == -1) {
        return NULL;
    }

    return qualified_group_pair_buf_start_mut(group)[found].object;
}

static inline void generic_string_pointer_map_insert(
    _GenericStringSlicePointerMap* self, ProtectedArena* arena, CubsStringSlice fullyQualifiedName, void* object
) {
    generic_map_ensure_total_capacity(self, arena);

    const size_t hashCode = bytes_hash((const void*)fullyQualifiedName.str, fullyQualifiedName.len);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % self->qualifiedGroupCount;
    _GenericQualifiedGroup* group = &self->qualifiedGroups[groupIndex];

    _GenericPair pair;
    pair.hashCode = hashCode;
    pair.name = fullyQualifiedName;
    pair.object = object;

    qualified_group_insert(group, arena, pair);
    self->elements[self->count] = object;
    self->count += 1;
    self->available -= 1;
}

#endif

