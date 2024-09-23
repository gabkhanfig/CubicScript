#include <stddef.h>

_Static_assert(sizeof(size_t) == sizeof(void*), "CubicScript requires a system with non-segmented addressing");
_Static_assert(sizeof(void*) == 8, "CubicScript is not compatible with non-64 bit architectures");