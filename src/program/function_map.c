#include "function_map.h"
#include "../interpreter/function_definition.h"
#include "protected_arena.h"
#include <string.h>
#include "../util/hash.h"
#include "../util/simd.h"
#include "../util/bitwise.h"
#include "../util/panic.h"
#include "../util/unreachable.h"
#include <stdio.h>

static const size_t GROUP_ALLOC_SIZE = 16;
static const size_t ALIGNMENT = 16;

typedef struct {
    size_t hashCode;
    CubsStringSlice name;
    CubsScriptFunctionPtr* function;
} Pair;

// TODO support unqualified function name lookup

typedef struct FunctionMapQualifiedGroup {
    /// The actual pairs start at `&hashMasks[capacity]`
    uint8_t* hashMasks;
    uint32_t pairCount;
    uint32_t capacity;
    // Use uint32_t to save 8 bytes in total. If a map has more than 4.29 billion entires in a single group,
    // then the load balancing and/or hashing implementation is poor.
    // uint16_t is not viable here because of forced alignment and padding.
} FunctionMapQualifiedGroup;

static size_t group_allocation_size(size_t requiredCapacity) {
    assert(requiredCapacity % ALIGNMENT == 0);

    return requiredCapacity + (sizeof(Pair) * requiredCapacity);
}

static const Pair* qualified_group_pair_buf_start(const FunctionMapQualifiedGroup* group) {
    const Pair* bufStart = (const Pair*)&group->hashMasks[group->capacity];
    return bufStart;
}

static Pair* qualified_group_pair_buf_start_mut(FunctionMapQualifiedGroup* group) {
    Pair* bufStart = (Pair*)&group->hashMasks[group->capacity];
    return bufStart;
}

static FunctionMapQualifiedGroup qualified_group_init(ProtectedArena* arena) {
    const size_t initialAllocationSize = group_allocation_size(GROUP_ALLOC_SIZE);
    void* mem = cubs_protected_arena_malloc(arena, initialAllocationSize, ALIGNMENT);
    memset(mem, 0, initialAllocationSize);

    const FunctionMapQualifiedGroup group = {.hashMasks = (uint8_t*)mem, .capacity = (uint32_t)GROUP_ALLOC_SIZE, .pairCount = 0};
    return group;
}

static void qualified_group_deinit(FunctionMapQualifiedGroup* self, ProtectedArena* arena) {
    const size_t currentAllocationSize = group_allocation_size(self->capacity);
    cubs_protected_arena_free(arena, (void*)self->hashMasks);
}

static void qualified_group_ensure_total_capacity(FunctionMapQualifiedGroup* self, ProtectedArena* arena, size_t minCapacity) {
    if(minCapacity <= self->capacity) {
        return;
    }

    const size_t remainder = minCapacity % ALIGNMENT;
    const size_t pairAllocCapacity = minCapacity + (ALIGNMENT - remainder);
    const size_t mallocCapacity =  group_allocation_size(pairAllocCapacity);

    void* mem = cubs_protected_arena_malloc(arena, mallocCapacity, ALIGNMENT);
    memset(mem, 0, mallocCapacity);

    uint8_t* newHashMaskStart = (uint8_t*)mem;
    Pair* newPairStart = (Pair*)&((uint8_t*)mem)[pairAllocCapacity];
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
static size_t qualified_group_find(const FunctionMapQualifiedGroup* self, CubsStringSlice name, CubsHashPairBitmask pairMask) {   
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
            Pair pair = qualified_group_pair_buf_start(self)[actualIndex];
            if((name.len != pair.name.len) || (strcmp(name.str, pair.name.str) != 0)) {        
                resultMask = (resultMask & ~(1U << index));
                continue;
            }
            return actualIndex;
        }
    }

    return -1;
}

static void map_ensure_total_capacity(FunctionMap* self, ProtectedArena* arena) {
    if(self->allFunctionsCount == self->allFunctionsCapacity) {
        const size_t newCapacity = self->allFunctionsCapacity == 0 ? 16 : self->allFunctionsCapacity << 1;
        CubsScriptFunctionPtr** newArray = (CubsScriptFunctionPtr**)cubs_protected_arena_malloc(
            arena, 
            sizeof(CubsScriptFunctionPtr*) * newCapacity, 
            _Alignof(CubsScriptFunctionPtr*)
        );
        if(self->allFunctions != NULL) {
            memcpy((void*)newArray, (const void*)self->allFunctions, self->allFunctionsCount);
            cubs_protected_arena_free(arena, (void*)self->allFunctions);
        }
        self->allFunctions = newArray;
        self->allFunctionsCapacity = newCapacity;
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

    FunctionMapQualifiedGroup* newGroups = (FunctionMapQualifiedGroup*)cubs_protected_arena_malloc(arena, sizeof(FunctionMapQualifiedGroup) * newGroupCount, _Alignof(FunctionMapQualifiedGroup));
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
            FunctionMapQualifiedGroup* oldGroup = &self->qualifiedGroups[oldGroupCount];
            if(oldGroup->pairCount != 0) {
                for(uint32_t hashMaskIter = 0; hashMaskIter < oldGroup->capacity; hashMaskIter++) {
                    if(oldGroup->hashMasks[hashMaskIter] == 0) {
                        continue;
                    }

                    Pair pair = qualified_group_pair_buf_start_mut(oldGroup)[hashMaskIter];
                    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(pair.hashCode);
                    const size_t groupIndex = groupBitmask.value % newGroupCount;

                    FunctionMapQualifiedGroup* newGroup = &newGroups[groupIndex];
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

/// The entry must not already exist
static void qualified_group_insert(FunctionMapQualifiedGroup* self, ProtectedArena* arena, Pair pair) {
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

const CubsScriptFunctionPtr *cubs_function_map_find(const FunctionMap *self, CubsStringSlice fullyQualifiedName)
{
    if(self->allFunctionsCount == 0) {
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
    const FunctionMapQualifiedGroup* group = &self->qualifiedGroups[groupIndex];

    const size_t found = qualified_group_find(group, fullyQualifiedName, cubs_hash_pair_bitmask_init(hashCode));
    if(found == -1) {
        return NULL;
    }

    return qualified_group_pair_buf_start(group)[found].function;
}

void cubs_function_map_insert(FunctionMap *self, ProtectedArena* arena, CubsScriptFunctionPtr* function)
{
    map_ensure_total_capacity(self, arena);

    CubsStringSlice fullyQualifiedName = cubs_string_as_slice(&function->fullyQualifiedName);
    
    const size_t hashCode = bytes_hash((const void*)fullyQualifiedName.str, fullyQualifiedName.len);
    const CubsHashGroupBitmask groupBitmask = cubs_hash_group_bitmask_init(hashCode);
    const size_t groupIndex = groupBitmask.value % self->qualifiedGroupCount;
    FunctionMapQualifiedGroup* group = &self->qualifiedGroups[groupIndex];

    const Pair pair = {.hashCode = hashCode, .name = fullyQualifiedName, .function = function};
    qualified_group_insert(group, arena, pair);
    self->allFunctions[self->allFunctionsCount] = function;
    self->allFunctionsCount += 1;
    self->available -= 1;
}
