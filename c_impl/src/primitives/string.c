#include "string.h"
#include "../util/atomic_ref_count.h"
#include <assert.h>
#include "../util/global_allocator.h"
#include <string.h>
#include <stdint.h>
#include "../util/panic.h"

#define STRING_ALIGN 32

const size_t FLAG_BIT = 1ULL << 63;
const CubsString EMPTY_STRING = {0};

static bool is_valid_utf8(CubsStringSlice slice) {
  const uint8_t asciiZeroBit = 0b10000000;
  const uint8_t trailingBytesBitmask = 0b11000000;
  const uint8_t trailingBytesCodePoint = 0b10000000;
  const uint8_t twoByteCodePoint = 0b11000000;
  const uint8_t twoByteBitmask = 0b11100000;
  const uint8_t threeByteCodePoint = 0b11100000;
  const uint8_t threeByteBitmask = 0b11110000;
  const uint8_t fourByteCodePoint = 0b11110000;
  const uint8_t fourByteBitmask = 0b11111000;

  size_t i = 0;
  while (i < slice.len) {
    const char c = slice.str[i];
    if (c == 0) {
      return false;
    }
    else if ((c & asciiZeroBit) == 0) {
      i += 1;
    }
    else if ((c & twoByteBitmask) == twoByteCodePoint) {
      if ((slice.str[i + 1] & trailingBytesBitmask) != trailingBytesCodePoint) {
        return false;
      }
      i += 2;
    }
    else if ((c & threeByteBitmask) == threeByteCodePoint) {
      if ((slice.str[i + 1] & trailingBytesBitmask) != trailingBytesCodePoint) {
        return false;
      }
      if ((slice.str[i + 2] & trailingBytesBitmask) != trailingBytesCodePoint) {
        return false;
      }
      i += 3;
    }
    else if ((c & fourByteBitmask) == fourByteCodePoint) {
      if ((slice.str[i + 1] & trailingBytesBitmask) != trailingBytesCodePoint) {
        return false;
      }
      if ((slice.str[i + 2] & trailingBytesBitmask) != trailingBytesCodePoint) {
        return false;
      }
      if ((slice.str[i + 3] & trailingBytesBitmask) != trailingBytesCodePoint) {
        return false;
      }
      i += 4;
    }
    else {
      return false;
    }
  }
  return true;
}

typedef struct Inner {
    AtomicRefCount refCount;
    size_t len;
    size_t allocSize;
    size_t _padding;
} Inner;

static Inner* inner_init_slice(CubsStringSlice slice) {
  const remainder = slice.len % 32;
  const requiredStringAllocation = slice.len + (32 - remainder); // allocate 32 byte chunks for AVX2
  const size_t allocSize = sizeof(Inner) + requiredStringAllocation;
  
  Inner* self = cubs_malloc(allocSize, STRING_ALIGN);
  memset((void*)self, 0, allocSize);
  atomic_ref_count_init(&self->refCount);
  self->len = slice.len;
  self->allocSize = allocSize;

  char* stringBufferStart = ((char*)self) + sizeof(Inner);
  memcpy((void*)stringBufferStart, (void*)slice.str, slice.len);
  return self;
}

static void inner_increment_ref_count(Inner* self) {
  atomic_ref_count_add_ref(&self->refCount);
}

static void inner_decrement_ref_count(Inner* self) {
  if (!atomic_ref_count_remove_ref(&self->refCount)) {
    return;
  }
  cubs_free(self, self->allocSize, STRING_ALIGN);
}

static const Inner* as_inner(const CubsString* self) {
  assert(self->_inner != NULL);
  return (const Inner*)self->_inner;
}

static Inner* as_inner_mut(CubsString* self) {
  assert(self->_inner != NULL);
  return (Inner*)self->_inner;
}

CubsStringError cubs_string_init(CubsString* stringToInit, CubsStringSlice slice)
{
  if (is_valid_utf8(slice)) {
    (*stringToInit) = cubs_string_init_unchecked(slice);
    return cubsStringErrorNone;
  }
  else {
    return cubsStringErrorInvalidUtf8;
  }
}

CubsString cubs_string_init_unchecked(CubsStringSlice slice)
{
  if(slice.len == 0) { 
    return EMPTY_STRING;
  }
#if _DEBUG
  for (size_t i = 0; i < slice.len; i++) {
    assert((slice.str[i] != '\0') && "String null terminator found before provided len");
  }
#endif
  CubsString s;
  s._inner = (void*)inner_init_slice(slice);
  return s;
}

void cubs_string_deinit(CubsString* self)
{
  if (self->_inner == NULL) {
    return;
  }
  Inner* inner = (Inner*)self->_inner;
  self->_inner = NULL;
  inner_decrement_ref_count(inner);
}

CubsString cubs_string_clone(const CubsString* self)
{
  if (self->_inner == NULL) {
    return EMPTY_STRING;
  }
  CubsString tempCopy = (*self);
  Inner* inner = as_inner_mut(&tempCopy);
  inner_increment_ref_count(inner);
  return tempCopy;
}

size_t cubs_string_len(const CubsString* self)
{
  if (self->_inner == NULL) {
    return 0;
  }
  else {
    const Inner* inner = as_inner(self);
    return inner->len;
  }
}
