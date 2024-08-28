#include "function.h"
#include "../../program/function_call_args.h"

CubsScriptFunctionCallArgs cubs_function_start_call(const CubsFunction *self)
{
    const CubsScriptFunctionCallArgs out = {.func = self, ._inner = {0}};
    return out;
}
