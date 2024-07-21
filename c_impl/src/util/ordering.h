#pragma once

/// Enum used for ordering. This matches with both [C++ `<=>`](https://open-std.org/JTC1/SC22/WG21/docs/papers/2017/p0515r0.pdf)
/// and [Rust `std::cmp::Ordering`](https://doc.rust-lang.org/std/cmp/enum.Ordering.html).
///
/// For Rust, this enum will need to be converted to `std::cmp::Ordering`, not bitcast interpreted, 
/// because CubsOrdering is at least 4 bytes, whereas `std::cmp::Ordering` uses a byte.
typedef enum CubsOrdering {
    cubsOrderingLess = -1,
    cubsOrderingEqual = 0,
    cubsOrderingGreater = 1,
    // Enforce enum size is at least 32 bits, which is `int` on most platforms
    _CUBS_ORDERING_MAX_VALUE = 0x7FFFFFFF,
} CubsOrdering;

#if __cplusplus
namespace cubs {
    enum Ordering : int {
        Less = cubsOrderingLess,
        Equal = cubsOrderingEqual,
        Greater = cubsOrderingGreater,
    }
}
#endif