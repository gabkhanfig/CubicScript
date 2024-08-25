#pragma once

typedef enum CubsFunctionPtrType {
    cubsFunctionPtrTypeC = 0,
    cubsFunctionPtrTypeScript = 1,
    /// Ensure at least 4 bytes
    _CUBS_FUNCTION_PTR_TYPE_MAX_VALUE = 0x7FFFFFFF,
} CubsFunctionPtrType;

typedef struct CubsFunctionPtr {
  const void* _inner;
  CubsFunctionPtrType funcType;
} CubsFunctionPtr;

