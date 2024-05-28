#pragma once

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include "value_tag.h"

/*
It's kinda weird to define the structs here and their implementions in other files, but it makes it convenient for passing around
raw values due to silly C shenanigans.
*/

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
  void* _buf;
  /// Accessing this is unsafe
  size_t _metadata;
} CubsArray;

typedef struct CubsSet {
  void* _inner;
} CubsSet;

typedef struct CubsMap {
  void* _inner;
} CubsMap;

/// 0 / null intialization makes it a none option.
typedef struct CubsOption {
  void* _inner;
} CubsOption;

typedef struct CubsResult {
  void* _inner;
} CubsResult;

typedef struct CubsClass {
  void* _inner;
} CubsClass;

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
  void* _inner;
} CubsVec2i;

typedef struct CubsVec3i {
  void* _inner;
} CubsVec3i;

typedef struct CubsVec4i {
  void* _inner;
} CubsVec4i;

typedef struct CubsVec2f {
  void* _inner;
} CubsVec2f;

typedef struct CubsVec3f {
  void* _inner;
} CubsVec3f;

typedef struct CubsVec4f {
  void* _inner;
} CubsVec4f;

typedef struct CubsMat3 {
  void* _inner;
} CubsMat3;

typedef struct CubsMat4 {
  void* _inner;
} CubsMat4;

typedef union CubsRawValue {
    bool boolean;
    int64_t intNum;
    double floatNum;
    CubsString string;
    CubsArray arr;
    CubsSet set;
    CubsMap map;
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

