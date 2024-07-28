#include "script_value.h"
#include "../util/panic.h"
#include "../util/unreachable.h"
#include "string/string.h"
#include "array/array.h"
#include "map/map.h"
#include "set/set.h"

_Static_assert(sizeof(size_t) == sizeof(void*), "CubicScript requires a system with non-segmented addressing");
_Static_assert(sizeof(void*) == 8, "CubicScript is not compatible with non-64 bit architectures");