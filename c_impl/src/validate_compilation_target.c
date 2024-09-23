#include <stddef.h>

_Static_assert(sizeof(void*) == 8, "CubicScript is only compatible with 64 bit systems");
_Static_assert(sizeof(size_t) == sizeof(void*), "CubicScript requires a system with non-segmented addressing");