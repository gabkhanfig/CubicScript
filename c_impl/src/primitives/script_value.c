#include "script_value.h"
#include "../util/panic.h"
#include "../util/unreachable.h"
#include "string/string.h"
#include "array/array.h"
#include "map/map.h"
#include "set/set.h"

_Static_assert(sizeof(int64_t) == 8, "64 bit integer must occupy 64 bits");
_Static_assert(sizeof(size_t) == sizeof(void*), "CubicScript requires a system with non-segmented addressing");
_Static_assert(sizeof(void*) == 8, "CubicScript is not compatible with non-64 bit architectures");

void cubs_class_opaque_deinit(void *self)
{
}

bool cubs_class_opaque_eql(const void *self, const void *other)
{
    return false;
}

size_t cubs_class_opaque_hash(const void *self)
{
    return 0;
}
