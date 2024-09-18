#include "function.h"

CubsFunction cubs_function_init_c(CubsCFunctionPtr func)
{
    const CubsFunction out = {.func = { .externC = func }, .funcType = cubsFunctionPtrTypeC};
    return out;
}

CubsFunctionCallArgs cubs_function_start_call(const CubsFunction *self)
{
    const CubsFunctionCallArgs out = {.func = self, ._inner = {0}};
    return out;
}
