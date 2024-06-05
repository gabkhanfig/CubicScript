#include "string.h"
#include "../../sync/atomic_ref_count.h"
#include <assert.h>
#include "../../util/global_allocator.h"
#include <string.h>
#include <stdint.h>
#include "../../util/panic.h"
#include <stdio.h>
#include "../../util/unreachable.h"

//#if __AVX2__
#include <immintrin.h>
//#endif

static const char HEAP_FLAG_BIT = (char)0b10000000;
static const size_t MAX_SSO_LEN = 23;
static const size_t HEAP_BUF_ALIGNMENT = 32;
static const size_t HEAP_REP_FLAG_BITMASK = 1ULL << 63;
static const CubsString EMPTY_STRING = {0};

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

typedef struct {
    char sso[24];
} SsoRep;

typedef struct {
    const char* buf;
    AtomicRefCount* refCount;
    size_t allocSizeAndFlag;
} HeapRep;

static bool is_sso(const CubsString* self) {
    const char* metadata = (const char*)(&self->_metadata);
    // If the element at index 23 (the last sso char) has the high bit set, its using the heap representation
    return (metadata[23] & HEAP_FLAG_BIT) == 0;
}

static void set_sso(CubsString* self) {
    char* metadata = (char*)(&self->_metadata);
    metadata[23] |= HEAP_FLAG_BIT;
    #if _DEBUG
    const SsoRep* ssoRep = (const SsoRep*)(&self->_metadata);
    assert((ssoRep->sso[23] & HEAP_FLAG_BIT) != 0);
    const HeapRep* heapRep = (const HeapRep*)(&self->_metadata);
    assert((heapRep->allocSizeAndFlag & HEAP_REP_FLAG_BITMASK) != 0);
    #endif
}

static const SsoRep* sso_rep(const CubsString* self) {
    assert(is_sso(self));
    return (const SsoRep*)(&self->_metadata);
}

static SsoRep* sso_rep_mut(CubsString* self) {
    assert(is_sso(self));
    return (SsoRep*)(&self->_metadata);
}

static const HeapRep* heap_rep(const CubsString* self) {
    assert(!is_sso(self));
    return (const HeapRep*)(&self->_metadata);
}

static HeapRep* heap_rep_mut(CubsString* self) {
    assert(!is_sso(self));
    return (HeapRep*)(&self->_metadata);
}

static void heap_rep_deinit(HeapRep* self) {
    if(!atomic_ref_count_remove_ref(self->refCount)) {
        return;
    }
    cubs_free((void*)self->refCount, sizeof(AtomicRefCount), _Alignof(AtomicRefCount));
    cubs_free((void*)self->buf, self->allocSizeAndFlag & ~HEAP_REP_FLAG_BITMASK, HEAP_BUF_ALIGNMENT);
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

static __m256i string_hash_iteration(const __m256i* vec, char num) {
	// in the case of SSO, will ignore the 
	const __m256i seed = _mm256_set1_epi64x(0);
	const __m256i indices = _mm256_set_epi8(31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);
	const __m256i numVec = _mm256_set1_epi8(num);

	// Checks if num is greater than each value of indices.
	// Mask is 0xFF if greater than, and 0x00 otherwise. 
	const __m256i mask = _mm256_cmpgt_epi8(numVec, indices);
	const __m256i partial = _mm256_and_si256(*vec, mask);
	return _mm256_add_epi8(partial, numVec);
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

static CubsString concat_valid_slices(CubsStringSlice lhs, CubsStringSlice rhs) {
  const size_t totalLen = lhs.len + rhs.len;

  CubsString temp = {0};
  temp.len = totalLen;
  if(totalLen <= MAX_SSO_LEN) {
    memcpy((void*)sso_rep_mut(&temp)->sso, lhs.str, lhs.len);
    memcpy((void*)&sso_rep_mut(&temp)->sso[lhs.len], rhs.str, rhs.len);
    return temp;
  }

  AtomicRefCount* refCount = cubs_malloc(sizeof(AtomicRefCount), _Alignof(AtomicRefCount));
  atomic_ref_count_init(refCount);

  const size_t remainder = (totalLen + 1) % 32;
  const size_t requiredStringAllocation = (totalLen + 1) + (32 - remainder); // allocate 32 byte chunks for AVX2
  char* buf = cubs_malloc(requiredStringAllocation, HEAP_BUF_ALIGNMENT);
  memset((void*)buf, 0, requiredStringAllocation);
  memcpy((void*)buf, lhs.str, lhs.len);
  memcpy((void*)&buf[lhs.len], rhs.str, rhs.len);

  set_sso(&temp);
  HeapRep* heapRep = heap_rep_mut(&temp);
  heapRep->buf = buf;
  heapRep->refCount = refCount;
  heapRep->allocSizeAndFlag = requiredStringAllocation | HEAP_REP_FLAG_BITMASK;

  return temp;
}

CubsString cubs_string_init_unchecked(CubsStringSlice slice)
{
    VALIDATE_SLICE(slice);

    CubsString temp = {0};
    temp.len = slice.len;

    if(slice.len <= MAX_SSO_LEN) {
        temp.len = slice.len;
        memcpy((void*)sso_rep_mut(&temp), slice.str, slice.len);
        return temp;
    }

    AtomicRefCount* refCount = cubs_malloc(sizeof(AtomicRefCount), _Alignof(AtomicRefCount));
    atomic_ref_count_init(refCount);

    const size_t remainder = (slice.len + 1) % 32;
    const size_t requiredStringAllocation = (slice.len + 1) + (32 - remainder); // allocate 32 byte chunks for AVX2
    char* buf = cubs_malloc(requiredStringAllocation, HEAP_BUF_ALIGNMENT);
    memset((void*)buf, 0, requiredStringAllocation);
    memcpy((void*)buf, slice.str, slice.len);

    set_sso(&temp);
    HeapRep* heapRep = heap_rep_mut(&temp);
    heapRep->buf = buf;
    heapRep->refCount = refCount;
    heapRep->allocSizeAndFlag = requiredStringAllocation | HEAP_REP_FLAG_BITMASK;

    return temp;
}

NewStringError cubs_string_init(CubsString *out, CubsStringSlice slice)
{
  if (is_valid_utf8(slice)) {
    (*out) = cubs_string_init_unchecked(slice);
    return newStringErrorNone;
  }
  else {
    return newStringErrorInvalidUtf8;
  }
}

void cubs_string_deinit(CubsString *self)
{
    if(is_sso(self)) {
        return;
    }
    heap_rep_deinit(heap_rep_mut(self));
    memset((void*)self, 0, sizeof(CubsString)); // ensure no use after free
}

CubsString cubs_string_clone(const CubsString *self)
{
    CubsString temp;
    memcpy((void*)&temp, (const void*)self, sizeof(CubsString)); // Even works for heap strings :D
    if(is_sso(self)) {
        return temp;
    }

    const HeapRep* heapRep = heap_rep(self);
    AtomicRefCount* refCount = (AtomicRefCount*)heapRep->refCount; // Explicitly const-cast
    atomic_ref_count_add_ref(refCount);

    return temp;
}

CubsStringSlice cubs_string_as_slice(const CubsString *self)
{
    if(is_sso(self)) {
        const CubsStringSlice slice = {.str = sso_rep(self)->sso, .len = self->len};
        return slice;
    } else {
        const CubsStringSlice slice = {.str = heap_rep(self)->buf, .len = self->len};
        return slice;
    }
}

bool cubs_string_eql(const CubsString *self, const CubsString *other)
{
    if(is_sso(self)) {
        const size_t* selfStart = (const size_t*)self;
        const size_t* otherStart = (const size_t*)other;
        // Due to the memory layout, this is guaranteed to be a valid equality check.
        return (selfStart[0] == otherStart[0])
			&& (selfStart[1] == otherStart[1])
			&& (selfStart[2] == otherStart[2])
			&& (selfStart[3] == otherStart[3]);
    }
    if(self->len != other->len) {
        return false;
    }
    // At this point, the length of `self` and `other` are the same, and `self` is not SSO,
    // therefore both must be using the heap representation.
    const HeapRep* selfHeap = heap_rep(self);
    const HeapRep* otherHeap = heap_rep(other);

    if(selfHeap->buf == otherHeap->buf) {
        return true;
    }

    return simd_compare_equal_string_and_string(selfHeap->buf, otherHeap->buf, self->len);
}

bool cubs_string_eql_slice(const CubsString* self, CubsStringSlice slice) {
  if(self->len != slice.len) {
    return false;
  }

  if(is_sso(self)) {
    const size_t* selfChars = (const size_t*)(sso_rep(self)->sso);

    size_t buf[3] = {0};
    memcpy((void*)buf, (const void*)slice.str, slice.len);
    return (selfChars[0] == buf[0])
			&& (selfChars[1] == buf[1])
			&& (selfChars[2] == buf[2]);
  }

  return simd_compare_equal_string_and_slice(heap_rep(self)->buf, slice);
}

CubsOrdering cubs_string_cmp(const CubsString *self, const CubsString *rhs)
{
  const CubsStringSlice selfSlice = cubs_string_as_slice(self);
  const CubsStringSlice otherSlice = cubs_string_as_slice(rhs);
  const int result = strcmp(selfSlice.str, otherSlice.str);
  if(result == 0) {
    return cubsOrderingEqual;
  }
  else if(result > 0) {
    return cubsOrderingGreater;
  }
  else {
    return cubsOrderingLess;
  }
}

size_t cubs_string_hash(const CubsString *self)
{
  const size_t HASH_MODIFIER = 0xc6a4a7935bd1e995ULL;
  const size_t HASH_SHIFT = 47;

  size_t h = 0;
  h = 0 ^ (self->len * HASH_MODIFIER);

	if (is_sso(self)) {
		__m256i thisVec = {0};
    memcpy((void*)&thisVec, (const void*)sso_rep(self)->sso, self->len);
		const __m256i hashIter = string_hash_iteration(&thisVec, (char)self->len);
    const uint64_t* m256i_u64 = (const uint64_t*)&hashIter;

		for (size_t i = 0; i < 4; i++) {
			h ^= m256i_u64[i];
			h *= HASH_MODIFIER;
			h ^= h >> HASH_SHIFT;
		}
	}
	else {
		const size_t iterationsToDo = ((self->len) % 32 == 0 ?
			self->len :
			self->len + (32 - (self->len % 32)))
			/ 32;

		for (size_t i = 0; i < iterationsToDo; i++) {
			const __m256i* thisVec = (const __m256i*)(heap_rep(self)->buf);
			const char num = i != (iterationsToDo - 1) ? (char)(32) : (char)((iterationsToDo * i) - self->len);
			const __m256i hashIter = string_hash_iteration(thisVec + i, num);
      const uint64_t* m256i_u64 = (const uint64_t*)&hashIter;

			for (size_t j = 0; j < 4; j++) {
				h ^= m256i_u64[j];
				h *= HASH_MODIFIER;
				h ^= h >> HASH_SHIFT;
			}
		}
	}

	h ^= h >> HASH_SHIFT;
	h *= HASH_MODIFIER;
	h ^= h >> HASH_SHIFT;
	return h;
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
  // TODO simd
  return index_of_pos_linear(cubs_string_as_slice(self), slice, startIndex);
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

CubsString cubs_string_concat(const CubsString *self, const CubsString *other)
{
  return concat_valid_slices(cubs_string_as_slice(self), cubs_string_as_slice(other));
}

CubsString cubs_string_concat_slice_unchecked(const CubsString *self, CubsStringSlice slice)
{
  VALIDATE_SLICE(slice);
  return concat_valid_slices(cubs_string_as_slice(self), slice);
}

NewStringError cubs_string_concat_slice(CubsString *out, const CubsString *self, CubsStringSlice slice)
{
  if (is_valid_utf8(slice)) {
    (*out) = concat_valid_slices(cubs_string_as_slice(self), slice);
    return newStringErrorNone;
  }
  else {
    return newStringErrorInvalidUtf8;
  }
}

NewStringError cubs_string_substr(CubsString *out, const CubsString *self, size_t startInclusive, size_t endExclusive)
{
  if(startInclusive == 0 && endExclusive == 0) {   
    (*out) = EMPTY_STRING;
    return newStringErrorNone;
  }

  const CubsStringSlice selfSlice = cubs_string_as_slice(self);
  if(startInclusive >= selfSlice.len || endExclusive > selfSlice.len || startInclusive > endExclusive) {
    return newStringErrorIndexOutOfBounds;
  }

  if(startInclusive == endExclusive) {
    (*out) = EMPTY_STRING;
    return newStringErrorNone;
  }

  const size_t len = endExclusive - startInclusive;
  const CubsStringSlice subSlice = {.str = &selfSlice.str[startInclusive], .len = len};
  // `cubs_string_init()` only returns a none error or invalid utf8, which will be propegated
  return cubs_string_init(out, subSlice);
}

/// Has the same layout as `CubsString` so can be reinterpret casted
typedef struct {
  size_t len;
  char sso[24];
} PredefinedSsoString;

static const PredefinedSsoString TRUE_STRING = {
  .len = 4,
  .sso = {'t', 'r', 'u', 'e', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

static const PredefinedSsoString FALSE_STRING = {
  .len = 5,
  .sso = {'f', 'a', 'l', 's', 'e', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

static const PredefinedSsoString ZERO_STRING = {
  .len = 1,
  .sso = {'0', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

static const PredefinedSsoString ONE_STRING = {
  .len = 1,
  .sso = {'1', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

static const PredefinedSsoString NEGATIVE_ONE_STRING = {
  .len = 2,
  .sso = {'-', '1', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

CubsString cubs_string_from_bool(bool b)
{
  if(b) {
    return *(const CubsString*)&TRUE_STRING;
  } 
  return *(const CubsString*)&FALSE_STRING;
}

CubsString cubs_string_from_int(int64_t num)
{
  // signed 64 bit integers will always take less characters than the max SSO buffer,
  // therefore its safe to create it inline
  if(num == 0) {
    return *(const CubsString*)&ZERO_STRING;
  }
  else if(num == 1) {
    return *(const CubsString*)&ONE_STRING;
  }
  else if(num == -1) {
    return *(const CubsString*)&NEGATIVE_ONE_STRING;
  }

  CubsString temp = {0};
  #if defined(_WIN32) || defined(WIN32)
  const int len = sprintf_s(sso_rep_mut(&temp)->sso, sizeof(SsoRep), "%lld", num);
  #else
    const int len = sprintf(sso_rep_mut(&temp)->sso, "%ld", num);
  #endif
  #if _DEBUG
  if(len < 0) {
    unreachable();
  }
  #endif
  temp.len = (size_t)len;
  return temp;
}

CubsString cubs_string_from_float(double num)
{
  if(num == 0.0) {
    return *(const CubsString*)&ZERO_STRING;
  }
  else if(num == 1.0) {
    return *(const CubsString*)&ONE_STRING;
  }
  else if(num == -1.0) {
    return *(const CubsString*)&NEGATIVE_ONE_STRING;
  }

  // https://stackoverflow.com/questions/1701055/what-is-the-maximum-length-in-chars-needed-to-represent-any-double-value
  #define STRING_INT_BUFFER_SIZE 1079
  char temp[STRING_INT_BUFFER_SIZE];
  // https://en.cppreference.com/w/c/io/fprintf
  // Is there a way to automatically remove trailing zeroes?
  // %g Doesn't seem to remove trailing zeroes 
  const int len = sprintf((char*)&temp, "%f", num);
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

NewStringError cubs_string_to_bool(bool *out, const CubsString *self)
{
  const size_t TRUE_MASK = (size_t)('t') | ((size_t)('r') << 8) | ((size_t)('u') << 16)| ((size_t)('e') << 24);
  const size_t FALSE_MASK = (size_t)('f') | ((size_t)('a') << 8) | ((size_t)('l') << 16)| ((size_t)('s') << 24) | ((size_t)('e') << 32);
  /// Start of slice is guaranteed to be 8 byte aligned, and valid for 24 bytes
  const size_t* start = (const size_t*)cubs_string_as_slice(self).str;
    if((*start) == TRUE_MASK) {
    (*out) = true;
    return newStringErrorNone;
  }
  else if((*start) == FALSE_MASK) {
    (*out) = false;
    return newStringErrorNone;
  }
  else {
    return newStringErrorParseBool;
  }
}
