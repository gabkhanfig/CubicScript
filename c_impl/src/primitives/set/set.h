#pragma once

#include "../../c_basic_types.h"
#include "../script_value.h"

typedef struct CubsSetIter {
    const CubsSet* _set;
    const void* _nextIter;
    /// Will need to be cast to the appropriate type
    const void* key;
} CubsSetIter;

typedef struct CubsSetReverseIter {
    const CubsSet* _set;
    const void* _nextIter;
    /// Will need to be cast to the appropriate type
    const void* key;
} CubsSetReverseIter;

//CubsSet cubs_set_init_primitive(CubsValueTag tag);

/// Does not allocate any memory, just zeroes and sets the context.
CubsSet cubs_set_init(const CubsTypeContext* context);

void cubs_set_deinit(CubsSet* self);

CubsSet cubs_set_clone(const CubsSet* self);

bool cubs_set_contains(const CubsSet* self, const void* key);

void cubs_set_insert(CubsSet* self, void* key);

/// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
/// and returns false if the entry doesn't exist.
bool cubs_set_erase(CubsSet* self, const void* key);

bool cubs_set_eql(const CubsSet* self, const CubsSet* other);

size_t cubs_set_hash(const CubsSet* self);

CubsSetIter cubs_set_iter_begin(const CubsSet* self);

/// For C++ interop
CubsSetIter cubs_set_iter_end(const CubsSet* self);

bool cubs_set_iter_next(CubsSetIter* iter);

CubsSetReverseIter cubs_set_reverse_iter_begin(const CubsSet* self);

/// For C++ interop
CubsSetReverseIter cubs_set_reverse_iter_end(const CubsSet* self);

bool cubs_set_reverse_iter_next(CubsSetReverseIter* iter);