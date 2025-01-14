#pragma once

#include "../../c_basic_types.h"

/// Is essential a [C++ std::string_view](https://en.cppreference.com/w/cpp/header/string_view) or a [Rust &str](https://doc.rust-lang.org/std/primitive.str.html)
typedef struct CubsStringSlice {
  /// Does not have to be null terminated.
  const char* str;
  /// Does not include null terminator. 
  size_t len;
} CubsStringSlice;