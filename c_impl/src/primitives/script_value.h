#pragma once

#ifndef __cplusplus

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#endif

typedef struct CubsTypeContext CubsTypeContext;

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
    const CubsTypeContext* context;
} CubsArray;

typedef struct CubsSet {
    /// The number of key/value pairs in the hashset.
    size_t len;
    /// Accessing this is unsafe
    void* _metadata[5];
    /// Requires equality and hash function pointers
    const CubsTypeContext* context;
} CubsSet;

typedef struct CubsMap {
    /// The number of key/value pairs in the hashmap.
    size_t len;
    /// Accessing this is unsafe
    void* _metadata[5];
    /// Requires equality and hash function pointers
    const CubsTypeContext* keyContext;
    /// Does not require equality and hash function pointers
    const CubsTypeContext* valueContext;
} CubsMap;

/// 0 / null intialization makes it a none option.
typedef struct CubsOption {
    bool isSome;
    void* _metadata[4];
    const CubsTypeContext* context;
} CubsOption;

typedef struct CubsError {
    CubsString name;
    /// Can be NULL. Must be cast to the appropriate type.
    void* metadata;
    /// Is the type of `metadata`. Can be NULL if the error has no metadata.
    const CubsTypeContext* context;
} CubsError;

typedef struct CubsResult {
    /// Accessing this is unsafe.
    void* metadata[sizeof(CubsError) / sizeof(void*)];
    bool isErr;
    /// Context of the ok value. If `NULL`, is an empty ok value.
    const CubsTypeContext* context;
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
    const CubsTypeContext* context;
} CubsUnique;

typedef struct CubsShared {
    void* _inner;
    const CubsTypeContext* context;
} CubsShared;

typedef struct CubsWeak {
    void* _inner;
    const CubsTypeContext* context;
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
