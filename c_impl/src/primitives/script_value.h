#pragma once

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include "value_tag.h"

typedef void (*CubsStructOnDeinit)(void* self);
typedef void (*CubsStructCloneFn)(void* dst, const void* self);
typedef bool (*CubsStructEqlFn)(const void* self, const void* other);
typedef size_t (*CubsStructHashFn)(const void* self);
/// Is both RTTI, and a VTable for certain *optional* functionality, such as on-deinitialization,
/// comparison operations, hashing, etc.
/// # Script Classes
/// When making a context for a script compatible class
/// - `onDeinit` -> `cubs_class_opaque_deinit(...)`
/// - `eql` -> `cubs_class_opaque_eql(...)`
/// - `hash` -> `cubs_class_opaque_hash(...)`
typedef struct CubsStructContext {
    /// In bytes. Will be rounded up to 8 for the interpreter where appropriate
    size_t sizeOfType;
    /// For user defined structs, use `cubsValueTagUserStruct`
    CubsValueTag tag;
    /// Can be NULL
    CubsStructOnDeinit onDeinit;
    /// Can be NULL
    CubsStructCloneFn clone;
    /// Can be NULL
    CubsStructEqlFn eql;
    /// Can be NULL
    CubsStructHashFn hash;
    /// Can be NULL, only used for debugging purposes
    const char* name;
    /// Is the length of `name`. Can be 0. Only used for debugging purposes
    size_t nameLength;
} CubsStructContext;

/// 0 / null intialization makes it an empty string.
typedef struct CubsString {
    /// Reading this is safe. Writing is unsafe.
    size_t len;
    /// Accessing this is unsafe
    void* _metadata[3];
} CubsString;

typedef struct CubsArray {
    /// Reading this is safe. Writing is unsafe.
    size_t len;
    /// This *can* be read or written to, but it must be cast to the correct type depending on the array's tag.
    /// It guaranteed to be valid for `((T*)_buf)[len - 1]` where T is the type of `cubs_array_tag(...)`.
    void* buf;
    /// Accessing this is unsafe
    size_t capacity;
    const CubsStructContext* context;
} CubsArray;

typedef struct CubsSet {
    /// The number of key/value pairs in the hashset.
    size_t count;
    /// Accessing this is unsafe
    void* _metadata[3];
} CubsSet;

typedef struct CubsMap {
    /// The number of key/value pairs in the hashmap.
    size_t len;
    /// Accessing this is unsafe
    void* _metadata[5];
    /// Requires equality and hash function pointers
    const CubsStructContext* keyContext;
    /// Does not require equality and hash function pointers
    const CubsStructContext* valueContext;
} CubsMap;

/// 0 / null intialization makes it a none option.
typedef struct CubsOption {
    /// Reading this is safe. Writing is unsafe.
    CubsValueTag tag;
    /// Reading this is safe. Writing is unsafe.
    bool isSome;
    /// Reading this is safe. Writing is unsafe.
    uint8_t sizeOfType;
    /// Accessing this is unsafe
    void* metadata[4];
} CubsOption;

typedef struct CubsError {
    /// Accessing this is unsafe.
    void* metadata;
    /// Reading and writing to this is safe.
    CubsString name;
} CubsError;

typedef struct CubsResult {
    /// Accessing this is unsafe.
    void* metadata[5];
} CubsResult;

typedef struct CubsOwnedInterface {
  void* _inner;
} CubsOwnedInterface;

typedef struct CubsInterfaceRef {
  void* _inner;
} CubsInterfaceRef;

typedef struct CubsConstRef {
  void* _inner;
} CubsConstRef;

typedef struct CubsMutRef {
  void* _inner;
} CubsMutRef;

typedef struct CubsUnique {
  void* _inner;
} CubsUnique;

typedef struct CubsShared {
  void* _inner;
} CubsShared;

typedef struct CubsWeak {
  void* _inner;
} CubsWeak;

typedef struct CubsFunctionPtr {
  void* _inner;
} CubsFunctionPtr;

typedef struct CubsVec2i {
  int64_t x;
  int64_t y;
} CubsVec2i;

typedef struct CubsVec3i {
  int64_t x;
  int64_t y;
  int64_t z;
} CubsVec3i;

typedef struct CubsVec4i {
  int64_t x;
  int64_t y;
  int64_t z;
  int64_t w;
} CubsVec4i;

typedef struct CubsVec2f {
  double x;
  double y;
} CubsVec2f;

typedef struct CubsVec3f {
  double x;
  double y;
  double z;
} CubsVec3f;

typedef struct CubsVec4f {
  double x;
  double y;
  double z;
  double w;
} CubsVec4f;

typedef struct CubsMat3 {
  void* _inner;
} CubsMat3;

typedef struct CubsMat4 {
  void* _inner;
} CubsMat4;

void cubs_class_opaque_deinit(void* self);

bool cubs_class_opaque_eql(const void* self, const void* other);

size_t cubs_class_opaque_hash(const void* self);

typedef union CubsRawValue {
    bool boolean;
    int64_t intNum;
    double floatNum;
    CubsString string;
    CubsArray arr;
    CubsSet set;
    CubsMap map;
    CubsOption option;
} CubsRawValue;

/// It is safe to call this function multiple times on the same object, since all primitives handle double deinitialization.
void cubs_raw_value_deinit(CubsRawValue* self, CubsValueTag tag);

void cubs_void_value_deinit(void* value, CubsValueTag tag);

CubsRawValue cubs_raw_value_clone(const CubsRawValue* self, CubsValueTag tag);

bool cubs_raw_value_eql(const CubsRawValue* self, const CubsRawValue* other, CubsValueTag tag);

typedef struct CubsTaggedValue {
    CubsRawValue value;
    CubsValueTag tag;
} CubsTaggedValue;

/// It is safe to call this function multiple times on the same object, since all primitives handle double deinitialization.
void cubs_tagged_value_deinit(CubsTaggedValue* self);

CubsTaggedValue cubs_tagged_value_clone(const CubsTaggedValue* self);

bool cubs_tagged_value_eql(const CubsTaggedValue* self, const CubsTaggedValue* other);

size_t cubs_size_of_tagged_type(CubsValueTag tag);

