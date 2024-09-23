#pragma once

#include "../../c_basic_types.h"

struct CubsTypeContext;

typedef struct CubsMap {
    /// The number of key/value pairs in the hashmap.
    size_t len;
    /// Accessing this is unsafe
    void* _metadata[5];
    /// Requires equality and hash function pointers
    const struct CubsTypeContext* keyContext;
    /// Does not require equality and hash function pointers
    const struct CubsTypeContext* valueContext;
} CubsMap;

typedef struct CubsMapConstIter {
    const CubsMap* _map;
    const void* _nextIter;
    /// Will need to be cast to the appropriate type
    const void* key;
    /// Will need to be cast to the appropriate type
    const void* value;
} CubsMapConstIter;

typedef struct CubsMapMutIter {
    CubsMap* _map;
    void* _nextIter;
    /// Will need to be cast to the appropriate type.
    /// Is immutable because modifiying the keys in a hashmap will completely mess up the way it's fetched.
    const void* key;   
    /// Will need to be cast to the appropriate type
    void* value;
} CubsMapMutIter;

typedef struct CubsMapReverseConstIter {
    const CubsMap* _map;
    const void* _nextIter;
    /// Will need to be cast to the appropriate type
    const void* key;
    /// Will need to be cast to the appropriate type
    const void* value;
} CubsMapReverseConstIter;

typedef struct CubsMapReverseMutIter {
    CubsMap* _map;
    void* _nextIter;
    /// Will need to be cast to the appropriate type.
    /// Is immutable because modifiying the keys in a hashmap will completely mess up the way it's fetched.
    const void* key;   
    /// Will need to be cast to the appropriate type
    void* value;
} CubsMapReverseMutIter;

#ifdef __cplusplus
extern "C" {
#endif

//CubsMap cubs_map_init_primitives(CubsValueTag keyTag, CubsValueTag valueTag);

CubsMap cubs_map_init(const struct CubsTypeContext* keyContext, const struct CubsTypeContext* valueContext);

void cubs_map_deinit(CubsMap* self);

CubsMap cubs_map_clone(const CubsMap* self);

/// Find `key` within the map `self`. If it doesn't exist, returns `NULL`, otherwise
/// returns an immutable reference to the value in the key/value pair.
/// Assumes that `key` is the correct type that this map holds.
/// The return type must be cast to the appropriate type.
/// Mutation operations on this map may make the returned memory invalid.
const void* cubs_map_find(const CubsMap* self, const void* key);

/// Find `key` within the map `self`. If it doesn't exist, returns `NULL`, otherwise
/// returns a mutable reference to the value in the key/value pair.
/// Assumes that `key` is the correct type that this map holds.
/// The return type must be cast to the appropriate type.
/// Mutation operations on this map may make the returned memory invalid.
void* cubs_map_find_mut(CubsMap* self, const void* key);

void cubs_map_insert(CubsMap* self, void* key, void* value);

/// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
/// and returns false if the entry doesn't exist.
/// Assumes that `key` is the correct type that this map holds.
bool cubs_map_erase(CubsMap* self, const void* key);

bool cubs_map_eql(const CubsMap* self, const CubsMap* other);

size_t cubs_map_hash(const CubsMap* self);

CubsMapConstIter cubs_map_const_iter_begin(const CubsMap* self);

/// For C++ interop
CubsMapConstIter cubs_map_const_iter_end(const CubsMap* self);

bool cubs_map_const_iter_next(CubsMapConstIter* iter);

CubsMapMutIter cubs_map_mut_iter_begin(CubsMap* self);

/// For C++ interop
CubsMapMutIter cubs_map_mut_iter_end(CubsMap* self);

bool cubs_map_mut_iter_next(CubsMapMutIter* iter);

CubsMapReverseConstIter cubs_map_reverse_const_iter_begin(const CubsMap* self);

/// For C++ interop
CubsMapReverseConstIter cubs_map_reverse_const_iter_end(const CubsMap* self);

bool cubs_map_reverse_const_iter_next(CubsMapReverseConstIter* iter);

CubsMapReverseMutIter cubs_map_reverse_mut_iter_begin(CubsMap* self);

/// For C++ interop
CubsMapReverseMutIter cubs_map_reverse_mut_iter_end(CubsMap* self);

bool cubs_map_reverse_mut_iter_next(CubsMapReverseMutIter* iter);

#ifdef __cplusplus
} // extern "C"
#endif
