#pragma once

#include "../script_value.h"

/// Copies the memory at `value`.
CubsUnique cubs_unique_init_user_class(void* value, const CubsTypeContext* context);

/// Mustn't be locked
void cubs_unique_deinit(CubsUnique* self);

void cubs_unique_lock_shared(const CubsUnique* self);

bool cubs_unique_try_lock_shared(const CubsUnique* self);

void cubs_unique_unlock_shared(const CubsUnique* self);

void cubs_unique_lock_exclusive(CubsUnique* self);

bool cubs_unique_try_lock_exclusive(CubsUnique* self);

void cubs_unique_unlock_exclusive(CubsUnique* self);

/// Gets the value that this unique pointer owns.
/// Getting without also shared or exclusive locking the unique is undefined behaviour.
const void* cubs_unique_get(const CubsUnique* self);

/// Gets the value that this unique pointer owns.
/// Getting without also exclusive locking the unique is undefined behaviour.
void* cubs_unique_get_mut(CubsUnique* self);

/// Clones `self`, making a new instance. 
/// Cloning without also shared or exclusive locking the unique is undefined behaviour.
CubsUnique cubs_unique_clone(const CubsUnique* self);

// /// Equality comparison without shared or exclusive locking on `self` and `other` is undefined behaviour.
// bool cubs_unique_eql(const CubsUnique* self, const CubsUnique* other);

// /// Expects `other` is the same type that `self` contains.
// /// Equality comparison without shared or exclusive locking on `self` is undefined behaviour.
// bool cubs_unique_eql_value(const CubsUnique* self, const void* other);

// /// Hashing without shared or exclusive locking on `self` is undefined behaviour.
// size_t cubs_unique_hash(const CubsUnique* self);

/// Invalidates `self`. Calling `cubs_unique_deinit(...)` after is unnecessary, but allowed.
//void cubs_unique_take(void* out, CubsUnique* self);

//CubsWeak cubs_unique_make_weak(CubsUnique* self);