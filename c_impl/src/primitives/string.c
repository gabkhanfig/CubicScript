#include "string.h"
#include "../util/atomic_ref_count.h"
#include <assert.h>
#include "../util/global_allocator.h"
#include <string.h>
#include <stdint.h>
#include "../util/panic.h"
#include <immintrin.h>
#include <stdio.h>
#include "../util/unreachable.h"

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

#if _DEBUG
#define VALIDATE_SLICE(stringSlice) do { \
  assert(is_valid_utf8(stringSlice)); \
  for (size_t _sliceIter = 0; _sliceIter < stringSlice.len; _sliceIter++) { \
    assert((stringSlice.str[_sliceIter] != '\0') && "String null terminator found before provided len"); \
  } \
} while(false);
#else
#define VALIDATE_SLICE(stringSlice)
#endif

typedef struct Inner {
    AtomicRefCount refCount;
    size_t len;
    size_t allocSize;
    size_t _padding;
} Inner;

/// @param requiredLen Does not include null terminator
static Inner* inner_init_zeroed(size_t requiredLen) {
  const size_t remainder = (requiredLen + 1) % 32;
  const size_t requiredStringAllocation = (requiredLen + 1) + (32 - remainder); // allocate 32 byte chunks for AVX2
  const size_t allocSize = sizeof(Inner) + requiredStringAllocation;

  Inner* self = cubs_malloc(allocSize, STRING_ALIGN);
  memset((void*)self, 0, allocSize);
  atomic_ref_count_init(&self->refCount);
  self->len = requiredLen;
  self->allocSize = allocSize;

  return self;
}

static Inner* inner_init_slice(CubsStringSlice slice) {
  Inner* self = inner_init_zeroed(slice.len);

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

static const char* buf_start(const CubsString* self) {
  assert(self->_inner != NULL);
  return (const char*)(as_inner(self) + 1); // buffer starts at the memory immediately after inner
}

static char* buf_start_mut(CubsString* self) {
  assert(self->_inner != NULL);
  return (char*)(as_inner_mut(self) + 1); // buffer starts at the memory immediately after inner
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
  VALIDATE_SLICE(slice);
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

CubsStringSlice cubs_string_as_slice(const CubsString *self)
{
  CubsStringSlice slice;
  if(self->_inner == NULL) {
    slice.str = NULL;
    slice.len = 0;
  } else {
    slice.str = buf_start(self);
    slice.len = as_inner(self)->len;
  }
  return slice;
}

static bool simd_compare_equal_string_and_string(const char* buffer, const char* otherBuffer, size_t len) {
  #if __AVX2__
  assert((((size_t)buffer) % 32 == 0) && "String buffer must be 32 byte aligned");
  assert((((size_t)otherBuffer) % 32 == 0) && "String buffer must be 32 byte aligned");

  const __m256i* thisVec = (const __m256i*)buffer;
  const __m256i* otherVec = (const __m256i*)otherBuffer;

  const size_t remainder = (len + 1) % 32; // add one for null terminator
  const size_t bytesToCheck = remainder ? ((len + 1) + (32 - remainder)) : len + 1;
  for(size_t i = 0; i < bytesToCheck; i += 32) {
    // _mm256_cmpeq_epi8_mask is an AVX512 extension
    const __m256i result = _mm256_cmpeq_epi8(*thisVec, *otherVec);
    const int mask = _mm256_movemask_epi8(result);
    if(mask == (int)~0) {
      thisVec++;
      otherVec++;
      continue;
    }
    return false;
  }
  return true;
  #endif
}

bool cubs_string_eql(const CubsString *self, const CubsString *other)
{
  if(self->_inner == other->_inner) {
    return true;
  }

  if(self->_inner == NULL) {
    return cubs_string_len(other) == 0;
  } 

  const size_t selfLen = cubs_string_len(self);
  if (other->_inner == NULL) {
    return selfLen == 0;
  }

  return simd_compare_equal_string_and_string(buf_start(self), buf_start(other), selfLen);
}

/// Expects that the length of buffer is equal to `slice.len`.
static bool simd_compare_equal_string_and_slice(const char* buffer, const CubsStringSlice slice) {
  #if __AVX2__
  assert((((size_t)buffer) % 32 == 0) && "String buffer must be 32 byte aligned");

  const __m256i* thisVec = (const __m256i*)buffer;
  __m256i otherVec; // initializing the memory is unnecessary

  size_t i = 0;
  if(slice.len >= 32) {
    for(; i <= (slice.len - 32); i += 32) {
      memcpy(&otherVec, slice.str + i, 32);
      const __m256i result = _mm256_cmpeq_epi8(*thisVec, otherVec);
      const int mask = _mm256_movemask_epi8(result);
      if(mask == (int)~0) {
        thisVec++;
        continue;
      }
      return false;
    }
  }
  
  for(; i < slice.len; i++) {
    if(buffer[i] != slice.str[i]) return false;
  }
  return true;
  #endif
}

bool cubs_string_eql_slice(const CubsString *self, CubsStringSlice slice)
{
  if(self->_inner == NULL) {
    return slice.len == 0;
  }

  const size_t selfLen = cubs_string_len(self);
  if(selfLen != slice.len) {
    return false;
  }

  return simd_compare_equal_string_and_slice(buf_start(self), slice);
}

CubsOrdering cubs_string_cmp(const CubsString *self, const CubsString *other)
{
  if(self->_inner == other->_inner) {
    return cubsOrderingEqual;
  }

  const CubsStringSlice selfSlice = cubs_string_as_slice(self);
  const CubsStringSlice otherSlice = cubs_string_as_slice(other);

  if(selfSlice.len == otherSlice.len) {
    for(size_t i = 0; i < selfSlice.len; i++) {
      const char selfChar = selfSlice.str[i];
      const char otherChar = otherSlice.str[i];
      if (selfChar == otherChar) {
        continue;
      } else if (selfChar < otherChar) {
        return cubsOrderingLess;
      } else {
        return cubsOrderingGreater;
      }
    }
  }
  else {
    const size_t lengthToCheck = selfSlice.len > otherSlice.len ? selfSlice.len : otherSlice.len;
    for(size_t i = 0; i < lengthToCheck; i++) {
      char selfChar = '\0';
      if(i < selfSlice.len) {
        selfChar = selfSlice.str[i];
      }

      char otherChar = '\0';
      if(i < otherSlice.len) {
        otherChar = otherSlice.str[i];
      }
      if (selfChar == otherChar) {
        continue;
      } else if (selfChar < otherChar) {
        return cubsOrderingLess;
      } else {
        return cubsOrderingGreater;
      }
    }
  } 
  return cubsOrderingEqual;
}

size_t cubs_string_hash(const CubsString *self)
{
  #if __AVX2__
  const size_t HASH_MODIFIER = 0xc6a4a7935bd1e995ULL;
	const size_t HASH_SHIFT = 47;

  size_t h = 0;
  const size_t len = cubs_string_len(self);
  const size_t iterationsToDo = ((len) % 32 == 0 ? len : len + (32 - (len % 32))) / 32;

  if(iterationsToDo > 0) {
    const __m256i* thisVec = (const __m256i*)buf_start(self);
   
    const __m256i seed = _mm256_set1_epi64x(0);
    const __m256i indices = _mm256_set_epi8(31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);
      
    for(size_t i = 0; i < iterationsToDo; i++) {
      const char num = i != (iterationsToDo - 1) ? (char)(32) : (char)((iterationsToDo * i) - len);

      // in the case of SSO, will ignore the 
      const __m256i numVec = _mm256_set1_epi8(num);

      // Checks if num is greater than each value of indices.
      // Mask is 0xFF if greater than, and 0x00 otherwise. 
      const __m256i mask = _mm256_cmpgt_epi8(numVec, indices);
      const __m256i partial = _mm256_and_si256(thisVec[i], mask);
      const __m256i hashIter = _mm256_add_epi8(partial, numVec);

      const size_t* hashPtr = (const size_t*)(&hashIter);
			for (size_t j = 0; j < 4; j++) {
			  h ^= hashPtr[i];
				h *= HASH_MODIFIER;
				h ^= h >> HASH_SHIFT;
			}
    }
  }

  h ^= h >> HASH_SHIFT;
	h *= HASH_MODIFIER;
	h ^= h >> HASH_SHIFT;
	return h;
  #endif
}

static size_t index_of_pos_linear(CubsStringSlice self, CubsStringSlice slice, size_t startIndex) {
  size_t i = startIndex;
  const size_t end = self.len - slice.len;
  for(; i <= end; i++) {
    bool foundEqual = true;
    for(size_t strEqlIter = 0; strEqlIter < slice.len; strEqlIter++) {
      if(self.str[i + strEqlIter] != slice.str[strEqlIter]) {
        foundEqual = false;
        break;
      }
    }
    if(foundEqual) {
      return i;
    }
  }
  return CUBS_STRING_N_POS;
}

static size_t index_of_pos_scalar(CubsStringSlice self, CubsStringSlice slice, size_t startIndex) {
  return CUBS_STRING_N_POS;
}

size_t cubs_string_find(const CubsString *self, CubsStringSlice slice, size_t startIndex)
{
  const CubsStringSlice selfSlice = cubs_string_as_slice(self);
  if((slice.len > selfSlice.len) || (startIndex + slice.len >= selfSlice.len)) {
    return CUBS_STRING_N_POS;
  }
  if((startIndex > selfSlice.len) || (slice.len == 0)) {
    return CUBS_STRING_N_POS;
  }

  // if(slice.len < 2) {
  //   if(slice.len == 0) { 
  //     return startIndex;
  //   }
  //   return index_of_pos_scalar(cubs_string_as_slice(self), slice, startIndex);
  // }
  // else {
    return index_of_pos_linear(cubs_string_as_slice(self), slice, startIndex);
  //}
}

size_t cubs_string_rfind(const CubsString *self, CubsStringSlice slice, size_t startIndex)
{
  const CubsStringSlice selfSlice = cubs_string_as_slice(self);
  /// startIndex - slice.len may overflow. This is fine.
  if((slice.len > selfSlice.len) || (startIndex - slice.len >= selfSlice.len)) {
    return CUBS_STRING_N_POS;
  }
  if((startIndex > selfSlice.len) || (slice.len == 0)) {
    return CUBS_STRING_N_POS;
  }

  size_t i = startIndex - slice.len;
  while(true) {
    bool foundEqual = true;
    for(size_t strEqlIter = 0; strEqlIter < slice.len; strEqlIter++) {
      if(selfSlice.str[i + strEqlIter] != slice.str[strEqlIter]) {
        foundEqual = false;
        break;
      }
    }
    if(foundEqual) {
      return i;
    }
    
    if(i == 0) {
      return CUBS_STRING_N_POS;
    }
    i -= 1;
  }
}

static CubsString concat_valid_slices(CubsStringSlice lhs, CubsStringSlice rhs) {
  const size_t requiredLen = lhs.len + rhs.len;

  Inner* inner = inner_init_zeroed(requiredLen);

  char* stringBufferStart = ((char*)inner) + sizeof(Inner);
  memcpy((void*)stringBufferStart, (void*)lhs.str, lhs.len);
  memcpy((void*)(stringBufferStart + lhs.len), (void*)rhs.str, rhs.len);

  CubsString s;
  s._inner = (void*)inner;
  return s;
}

CubsString cubs_string_concat(const CubsString* self, const CubsString* other)
{
  return concat_valid_slices(cubs_string_as_slice(self), cubs_string_as_slice(other));
}

CubsStringError cubs_string_concat_slice(CubsString *out, const CubsString *self, CubsStringSlice slice)
{
  if (is_valid_utf8(slice)) {
    (*out) = concat_valid_slices(cubs_string_as_slice(self), slice);
    return cubsStringErrorNone;
  }
  else {
    return cubsStringErrorInvalidUtf8;
  }
}

CubsString cubs_string_concat_slice_unchecked(const CubsString *self, CubsStringSlice slice)
{
  VALIDATE_SLICE(slice);
  return concat_valid_slices(cubs_string_as_slice(self), slice);
}

typedef struct _PredefinedStringInner {
  _Alignas(32) Inner inner;
  _Alignas(32) char buf[32];
} PredefinedStringInner;

/// NOTE DO NOT MAKE THIS CONST because it will cause segmentation faults
PredefinedStringInner TRUE_INNER = {
  .inner = {.refCount = {.count = 1}, .len = 4, .allocSize = 0, ._padding = 0},
  // Explicitly zero out the memory
  .buf = {'t', 'r', 'u', 'e', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
};
const CubsString TRUE_STRING = {._inner = (void*)&TRUE_INNER};

/// NOTE DO NOT MAKE THIS CONST because it will cause segmentation faults
PredefinedStringInner FALSE_INNER = {
  .inner = {.refCount = {.count = 1}, .len = 5, .allocSize = 0, ._padding = 0},
  // Explicitly zero out the memory
  .buf = {'f', 'a', 'l', 's', 'e', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
};
const CubsString FALSE_STRING = {._inner = (void*)&FALSE_INNER};

CubsString cubs_string_from_bool(bool b) {
  if(b) {
    return cubs_string_clone(&TRUE_STRING);
  }
  else {
    return cubs_string_clone(&FALSE_STRING);
  }
}

/// NOTE DO NOT MAKE THIS CONST because it will cause segmentation faults
PredefinedStringInner ZERO_INNER = {
  .inner = {.refCount = {.count = 1}, .len = 1, .allocSize = 0, ._padding = 0},
  // Explicitly zero out the memory
  .buf = {'0', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
};
const CubsString ZERO_STRING = {._inner = (void*)&ZERO_INNER};

/// NOTE DO NOT MAKE THIS CONST because it will cause segmentation faults
PredefinedStringInner ONE_INNER = {
  .inner = {.refCount = {.count = 1}, .len = 1, .allocSize = 0, ._padding = 0},
  // Explicitly zero out the memory
  .buf = {'1', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
};
const CubsString ONE_STRING = {._inner = (void*)&ONE_INNER};

/// NOTE DO NOT MAKE THIS CONST because it will cause segmentation faults
PredefinedStringInner NEGATIVE_ONE_INNER = {
  .inner = {.refCount = {.count = 1}, .len = 2, .allocSize = 0, ._padding = 0},
  // Explicitly zero out the memory
  .buf = {'-', '1', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
};
const CubsString NEGATIVE_ONE_STRING = {._inner = (void*)&NEGATIVE_ONE_INNER};

CubsString cubs_string_from_int(int64_t num)
{
  // 0, 1, and -1 are reasonably likely values
  if(num == 0) {
    return cubs_string_clone(&ZERO_STRING);
  }
  if(num == 1) {
    return cubs_string_clone(&ONE_STRING);
  }
  if(num == -1) {
    return cubs_string_clone(&NEGATIVE_ONE_STRING);
  }
    
  // This is enough to handle all 64 bit integer values
  #define STRING_INT_BUFFER_SIZE 21
  char temp[STRING_INT_BUFFER_SIZE];
  // https://en.cppreference.com/w/c/io/fprintf
  const int len = sprintf_s((char*)&temp, STRING_INT_BUFFER_SIZE, "%lld", num);
  #if _DEBUG
  if(len < 0) {
    unreachable();
  }
  #endif
  const CubsStringSlice slice = {.str = (const char*)&temp, .len = len};
  return cubs_string_init_unchecked(slice);
}

CubsString cubs_string_from_float(double num) {
  // 0, 1, and -1 are reasonably likely values
  if(num == 0.0) {
    return cubs_string_clone(&ZERO_STRING);
  }
  if(num == 1.0) {
    return cubs_string_clone(&ONE_STRING);
  }
  if(num == -1.0) {
    return cubs_string_clone(&NEGATIVE_ONE_STRING);
  }

  // https://stackoverflow.com/questions/1701055/what-is-the-maximum-length-in-chars-needed-to-represent-any-double-value
  #define STRING_INT_BUFFER_SIZE 1079
  char temp[STRING_INT_BUFFER_SIZE];
  // https://en.cppreference.com/w/c/io/fprintf
  // Is there a way to automatically remove trailing zeroes?
  // %g Doesn't seem to remove trailing zeroes 
  const int len = sprintf_s((char*)&temp, STRING_INT_BUFFER_SIZE, "%f", num);
  #if _DEBUG
  if(len < 0) {
    unreachable();
  }
  #endif
  
  int decimalIndex = -1;
  for(int i = 0; i < len; i++) {
    if(temp[i] == '.') {
      decimalIndex = i;
      break;
    }
  }

  #if _DEBUG
  assert(decimalIndex != -1);
  #endif

  CubsStringSlice slice = {.str = (const char*)&temp, .len = len};

  for(int i = len; i > decimalIndex; i--) {
    if(temp[i - 1] == '0') {
      slice.len -= 1;
    }
    else if(temp[i - 1] == '.') {
      slice.len -= 1;
    }
    else {
      break;
    }
  }

  return cubs_string_init_unchecked(slice);
}