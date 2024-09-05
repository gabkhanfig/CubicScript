#include "function.h"
#include "../../program/function_call_args.h"

CubsFunctionCallArgs cubs_function_start_call(const CubsFunction *self)
{
    const CubsFunctionCallArgs out = {.func = self, ._inner = {0}};
    return out;
}
