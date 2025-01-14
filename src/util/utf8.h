#pragma once

#include <stdint.h>
#include <stdbool.h>

struct CubsStringSlice;

bool cubs_utf8_is_valid(const struct CubsStringSlice* slice);

#if _DEBUG
#define VALIDATE_SLICE(stringSlice) do { \
  assert(cubs_utf8_is_valid(&stringSlice)); \
  for (size_t _sliceIter = 0; _sliceIter < stringSlice.len; _sliceIter++) { \
    assert((stringSlice.str[_sliceIter] != '\0') && "String null terminator found before provided len"); \
  } \
} while(false);
#else
#define VALIDATE_SLICE(stringSlice)
#endif