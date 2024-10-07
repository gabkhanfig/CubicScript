#include "function.h"

CubsFunction cubs_function_init_c(CubsCFunctionPtr func)
{
    const CubsFunction out = {.func = { .externC = func }, .funcType = cubsFunctionPtrTypeC};
    return out;
}

bool cubs_function_eql(const CubsFunction *self, const CubsFunction *other)
{
    return self->func.externC == other->func.externC;
}

size_t cubs_function_hash(const CubsFunction *self)
{
    return (size_t)self->func.externC;
}

CubsFunctionCallArgs cubs_function_start_call(const CubsFunction *self)
{
    const CubsFunctionCallArgs out = {.func = self, ._inner = {0}};
    return out;
}
