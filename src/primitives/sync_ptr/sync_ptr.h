#pragma once

#include "../../c_basic_types.h"

struct CubsTypeContext;

typedef struct CubsUnique {
    void* _inner;
    const struct CubsTypeContext* context;
} CubsUnique;

typedef struct CubsShared {
    void* _inner;
    const struct CubsTypeContext* context;
} CubsShared;

typedef struct CubsWeak {
    void* _inner;
    const struct CubsTypeContext* context;
} CubsWeak;

#ifdef __cplusplus
extern "C" {
#endif

/// Copies the memory at `value`.
CubsUnique cubs_unique_init(void* value, const struct CubsTypeContext* context);

/// Mustn't be locked
void cubs_unique_deinit(CubsUnique* self);

/// Does not require locking.
CubsWeak cubs_unique_make_weak(const CubsUnique* self);

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

/// Copies the memory at `value`.
CubsShared cubs_shared_init(void* value, const struct CubsTypeContext* context);

/// Mustn't be locked
void cubs_shared_deinit(CubsShared* self);

/// Does not require locking.
CubsWeak cubs_shared_make_weak(const CubsShared* self);

void cubs_shared_lock_shared(const CubsShared* self);

bool cubs_shared_try_lock_shared(const CubsShared* self);

void cubs_shared_unlock_shared(const CubsShared* self);

void cubs_shared_lock_exclusive(CubsShared* self);

bool cubs_shared_try_lock_exclusive(CubsShared* self);

void cubs_shared_unlock_exclusive(CubsShared* self);

/// Gets the value that this shared pointer owns.
/// Getting without also shared or exclusive locking the shared is undefined behaviour.
const void* cubs_shared_get(const CubsShared* self);

/// Gets the value that this shared pointer owns.
/// Getting without also exclusive locking the shared is undefined behaviour.
void* cubs_shared_get_mut(CubsShared* self);

/// Clones `self`, incrementing the ref count. Does not need to be locked.
CubsShared cubs_shared_clone(const CubsShared* self);

/// Checks if `self` and `other` point to the same shared object. If the two
/// have the same value, but different shared objects, this returns false.
bool cubs_shared_eql(const CubsShared* self, const CubsShared* other);

/// Mustn't be locked
void cubs_weak_deinit(CubsWeak* self);

void cubs_weak_lock_shared(const CubsWeak* self);

bool cubs_weak_try_lock_shared(const CubsWeak* self);

void cubs_weak_unlock_shared(const CubsWeak* self);

void cubs_weak_lock_exclusive(CubsWeak* self);

bool cubs_weak_try_lock_exclusive(CubsWeak* self);

void cubs_weak_unlock_exclusive(CubsWeak* self);

/// Checks if `self` is references expired data. Requires `self` to be locked.
/// This can occur when either a unique ptr instance was deinitialized, or a shared ptr has all it's strong
/// references deinitialized.
/// Getting without also shared or exclusive locking the weak is undefined behaviour.
bool cubs_weak_expired(const CubsWeak* self);

/// Gets the value that this weak pointer references.
/// Getting without also shared or exclusive locking the weak is undefined behaviour.
/// # Debug Asserts
/// `assert(!cubs_weak_expired(self));`
const void* cubs_weak_get(const CubsWeak* self);

/// Gets the value that this shared pointer owns.
/// Getting without also exclusive locking the weak is undefined behaviour.
/// # Debug Asserts
/// `assert(!cubs_weak_expired(self));`
void* cubs_weak_get_mut(CubsWeak* self);

/// Clones `self`, incrementing the ref count. Does not need to be locked.
CubsWeak cubs_weak_clone(const CubsWeak* self);

/// Checks if `self` and `other` hold the same weak reference. If the two
/// have the same value, but different weak references, this returns false.
bool cubs_weak_eql(const CubsWeak* self, const CubsWeak* other);

#ifdef __cplusplus
} // extern "C"
#endif
