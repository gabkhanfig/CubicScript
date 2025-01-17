#pragma once

#include "string_slice.h"
#include "../../c_basic_types.h"
#include "../../util/ordering.h"

/// Unlike C, `CubsChar` represents a single unicode character, more specifically a 32-bit
/// [unicode scalar value](https://www.unicode.org/glossary/#unicode_scalar_value), which is similar to but not the same as a [unicode code point](https://www.unicode.org/glossary/#code_point).
/// ### Scalar Values:
/// Scalar values are any code point excluding the high and low surrogate code points.
/// The valid scalar values are in the range of hex 0 to D7FF and E000 to 10FFFF.
/// ### Code Points:
/// Any of the 1114111 (hex 10FFFF) possible, but not necessarily assigned, values
/// 
/// It is the responsibility of the programmer to ensure that they use valid scalar values, 
/// and functions that use `CubsChar` will debug assert that this is the case.
///
/// # See
/// - [Glossary of Unicode Terms](https://www.unicode.org/glossary)
/// - [List of Unicode Characters](https://en.wikipedia.org/wiki/List_of_Unicode_characters)
/// - [Unicode Technical Quick Start Guide](https://home.unicode.org/technical-quick-start-guide)
typedef unsigned int CubsChar;

/// 0 / null intialization makes it an empty string.
typedef struct CubsString {
    /// Reading this is safe. Writing is unsafe.
    size_t len;
    /// Accessing this is unsafe
    void* _metadata[3];
} CubsString;

typedef enum CubsStringError {
  cubsStringErrorNone = 0,
  cubsStringErrorInvalidUtf8 = 1,
  cubsStringErrorIndexOutOfBounds = 2,
  cubsStringErrorParseBool = 3,
  cubsStringErrorParseInt = 4,
  cubsStringErrorParseFloat = 5,

  // Enforce enum size is at least 32 bits, which is `int` on most platforms
  _CUBS_STRING_ERROR_MAX_VALUE = 0x7FFFFFFF,
} CubsStringError;

/// https://cplusplus.com/reference/string/string/npos/
static const size_t CUBS_STRING_N_POS = -1;

#ifdef __cplusplus
extern "C" {
#endif

/// In `_DEBUG`:
/// - Asserts that a null terminator does not exist before `slice.len`.
/// - Asserts that the slice is valid utf8.
///
/// If not `_DEBUG`, does not perform those checks.
CubsString cubs_string_init_unchecked(CubsStringSlice slice);

/// In debug mode, will validate that a null terminator does not exist before `slice.len`.
/// Will always validate that the string is valid utf8, returning the appropriate error if it's not.
/// @returns `cubsStringErrorInvalidUtf8` if invalid utf8, or `cubsStringErrorNone` if valid.
CubsStringError cubs_string_init(CubsString* out, CubsStringSlice slice);

/// For heap strings, decrements the ref count, freeing the string if there are no more references.
void cubs_string_deinit(CubsString* self);

/// memcpy's `self`, incrementing the ref count if `self` is a heap string.
CubsString cubs_string_clone(const CubsString* self);

/// Get an immutable reference to the slice that this string owns. This string slice is null terminated.
/// Mutation operations on this string may make the slice point to invalid memory.
/// If the string is empty, returns a slice where `.str == NULL` and `.len == 0`
CubsStringSlice cubs_string_as_slice(const CubsString* self);

/// Equality comparison of two strings. Uses 32 byte SIMD optimizations (AVX2 on x86) when available.
bool cubs_string_eql(const CubsString* self, const CubsString* other);

/// Equality comparison of a string and a string slice. Uses 32 byte SIMD optimizations (AVX2 on x86) when available.
/// If `slice.len == 0`, checks that string is empty.
///
/// TECHNICAL NOTE: Only derefences `slice.str` if `slice.len == 0`, so it can point to anything as long as `slice.len == 0`.
/// [undefined](https://ziglang.org/documentation/master/#undefined) in Zig, which is 0xAA... is safe for this function.
bool cubs_string_eql_slice(const CubsString* self, CubsStringSlice slice);

/// Compares two strings, returning the ordering between them.
CubsOrdering cubs_string_cmp(const CubsString* self, const CubsString* rhs);

size_t cubs_string_hash(const CubsString* self);

/// Iterates through `self`, searching for the first occurrence of `slice` starting at `startIndex` inclusively.
/// Returns `CUBS_STRING_N_POS` if the value is not found. Unfortunately C does not have optionals by default.
/// Otherwise, just returns the index where the substring starts.
/// The returned valid value (not `CUBS_STRING_N_POS`) is guaranteed to be valid for indexing `cubs_string_as_slice(self)`.
size_t cubs_string_find(const CubsString* self, CubsStringSlice slice, size_t startIndex);

/// Reverse iterates through `self`, searching for the last occurrence of `slice` starting at `startIndex` inclusively.
/// Returns `CUBS_STRING_N_POS` if the value is not found. Unfortunately C does not have optionals by default.
/// Otherwise, just returns the index where the substring starts.
/// The returned valid value (not `CUBS_STRING_N_POS`) is guaranteed to be valid for indexing `cubs_string_as_slice(self)`.
size_t cubs_string_rfind(const CubsString* self, CubsStringSlice slice, size_t startIndex);

/// Concatenates two strings, creating a new string. Since strings are always valid utf8,
/// this function doesn't error.
CubsString cubs_string_concat(const CubsString* self, const CubsString* other);

/// Concatenate this string with a string slice, returning a new string.
/// In `_DEBUG`:
/// - Asserts that a null terminator does not exist before `slice.len`.
/// - Asserts that the slice is valid utf8.
///
/// If not `_DEBUG`, does not perform those checks.z
CubsString cubs_string_concat_slice_unchecked(const CubsString* self, CubsStringSlice slice);

/// Concatenate this string with a string slice, returning a new string.
/// Will always validate `slice` is valid utf8, returning the appropriate error if it's not.
/// @returns `cubsStringErrorInvalidUtf8` if invalid utf8, or `cubsStringErrorNone` if valid.
CubsStringError cubs_string_concat_slice(CubsString* out, const CubsString* self, CubsStringSlice slice);

/// Creates a substring of this string from the range `startInclusive` to `endExclusive`. If they are equal, 
/// `out` will be assigned to an empty string. 
/// @param out The outparam of the new substring.
/// @param startInclusive The byte index that the substring starts at, NOT utf8 codepoint index. The substring will include this character, 
/// hence "Inclusive". It may not be greater than the length of `self`, or `endExclusive`.
/// @param endExclusive The byte index that the substring ends at, NOT utf8 codepoint index. The substring terminates right before this character, 
/// hence "Exclusive". It may not be greater than the length of `self`.
/// @return `cubsStringErrorNone` if everything is ok, `cubsStringErrorOutOfRange` if either the start or end are out of range,
/// or `cubsStringErrorInvalidUtf8` if the substring is not valid utf8.
CubsStringError cubs_string_substr(CubsString* out, const CubsString* self, size_t startInclusive, size_t endExclusive);

/// Converts a bool to an string. Does not allocate any memory as the SSO buffer is large enough to fit "true" and "falses"
CubsString cubs_string_from_bool(bool b);

/// Converts a signed 64 bit integer to an string. Does not allocate any memory since the SSO
/// buffer is large enough to fit all signed 64 bit integers as strings.
CubsString cubs_string_from_int(int64_t num);

/// Converts a 64 bit float to a string in decimal notation in the style `-ddd.ddd`.
/// Uses the `%f` format specifier, but also removes trailing zeroes.
CubsString cubs_string_from_float(double num);

/// Parses a bool from this string, returning an error if `self` isn't "true" or "false".
CubsStringError cubs_string_to_bool(bool* out, const CubsString* self);

#ifdef __cplusplus
} // extern "C"
#endif
