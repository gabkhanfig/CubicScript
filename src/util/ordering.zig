/// Enum used for ordering. This matches with both [C++ `<=>`](https://open-std.org/JTC1/SC22/WG21/docs/papers/2017/p0515r0.pdf)
/// and [Rust `std::cmp::Ordering`](https://doc.rust-lang.org/std/cmp/enum.Ordering.html).
///
/// For Rust, this enum will need to be converted to `std::cmp::Ordering`, not bitcast interpreted,
/// because CubsOrdering is at least 4 bytes, whereas `std::cmp::Ordering` uses a byte.
pub const Ordering = enum(c_int) {
    Less = -1,
    Equal = 0,
    Greater = 1,
};
