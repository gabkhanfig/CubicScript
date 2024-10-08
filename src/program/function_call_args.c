#include "function_call_args.h"
#include "../primitives/function/function.h"
#include <assert.h>
#include "../util/panic.h"
#include "../interpreter/interpreter.h"
#include "../interpreter/function_definition.h"
#include <stdio.h>
#include "../util/context_size_round.h"
#include "../primitives/context.h"
#include <string.h>
#include "../platform/mem.h"

const size_t CURRENT_OFFSET = 0;
const size_t PUSHED_ARG_COUNT = 1;

void cubs_function_push_arg(CubsFunctionCallArgs *self, void *arg, const CubsTypeContext *typeContext)
{
    if(self->func->funcType == cubsFunctionPtrTypeScript) {
        const int currentOffset = self->_inner[CURRENT_OFFSET];
        const int currentPushedArgs = self->_inner[PUSHED_ARG_COUNT];

        #if _DEBUG
        const CubsScriptFunctionPtr* header = self->func->func.script;
        char buf[512];
        if(currentPushedArgs >= header->argsLen) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Script function [%s] expects %lld arguments", cubs_string_as_slice(&header->name).str, header->argsLen);
            #else
            const int len = sprintf(buf, "Script function [%s] expects %ld arguments", cubs_string_as_slice(&header->name).str, header->argsLen);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        if(currentOffset > header->_stackSpaceRequired) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Overflowed script function [%s] stack frame with function arguments", cubs_string_as_slice(&header->name).str);
            #else
            const int len = sprintf(buf, "Overflowed script function [%s] stack frame with function arguments", cubs_string_as_slice(&header->name).str);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        #endif

        cubs_interpreter_push_script_function_arg(arg, typeContext, currentOffset);   
    } else {
        const int currentOffset = self->_inner[CURRENT_OFFSET];
        const int currentPushedArgs = self->_inner[PUSHED_ARG_COUNT];

        cubs_interpreter_push_c_function_arg(arg, typeContext, currentOffset, currentPushedArgs, currentOffset);
    }
    const int offsetToAdd = (int)ROUND_SIZE_TO_MULTIPLE_OF_8(typeContext->sizeOfType);
    self->_inner[CURRENT_OFFSET] += (offsetToAdd / 8);
    self->_inner[PUSHED_ARG_COUNT] += 1;
}

int cubs_function_call(CubsFunctionCallArgs self, CubsFunctionReturn outReturn)
{    
    if(self.func->funcType == cubsFunctionPtrTypeScript) {
        
        const int currentOffset = self._inner[CURRENT_OFFSET];
        const int currentPushedArgs = self._inner[PUSHED_ARG_COUNT];

        const CubsScriptFunctionPtr* header = self.func->func.script;

        #if _DEBUG
        char buf[512];
        if(currentPushedArgs != header->argsLen) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Script function [%s] expects %lld arguments. Only %d passed in", cubs_string_as_slice(&header->name).str, header->argsLen, currentPushedArgs);
            #else
            const int len = sprintf(buf, "Script function [%s] expects %ld arguments. Only %d passed in", cubs_string_as_slice(&header->name).str, header->argsLen, currentPushedArgs);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        if(currentOffset > header->_stackSpaceRequired) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Overflowed script function [%s] stack frame with function arguments", cubs_string_as_slice(&header->name).str);
            #else
            const int len = sprintf(buf, "Overflowed script function [%s] stack frame with function arguments", cubs_string_as_slice(&header->name).str);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        if(header->returnType != NULL && (outReturn.value == NULL || outReturn.context == NULL)) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Script function [%s] expected return value destination", cubs_string_as_slice(&header->name).str);
            #else
            const int len = sprintf(buf, "Script function [%s] expected return value destination", cubs_string_as_slice(&header->name).str);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        #endif

        return (int)cubs_interpreter_execute_function(header, outReturn.value, outReturn.context);
    } else {
        cubs_interpreter_push_frame(self._inner[CURRENT_OFFSET], outReturn.value, outReturn.context);
        const InterpreterStackFrame frame = cubs_interpreter_current_stack_frame();

        const CubsCFunctionHandler args = {
            //.program = program,
            ._frameBaseOffset = frame.basePointerOffset,
            ._offsetForArgs = self._inner[CURRENT_OFFSET], 
            .argCount = self._inner[PUSHED_ARG_COUNT],
            .outReturn = outReturn,
        };

        const CubsCFunctionPtr func = self.func->func.externC;
        const int err = func(args);
        // if(err != 0) {
        //     char* buf = cubs_malloc(128, 1);
        //     #if defined(_WIN32) || defined(WIN32)
        //     const int len = sprintf(buf, "CubicScript extern C function call error code %d", err);
        //     #else
        //     const int len = sprintf(buf, "CubicScript extern C function call error code %d", err);
        //     #endif
        //     assert(len >= 0);   
        //     cubs_panic(buf);
        // }

        cubs_interpreter_stack_unwind_frame();
        cubs_interpreter_pop_frame();
        return err;
    }
}

void cubs_function_return_set_value(CubsCFunctionHandler self, void* returnValue, const struct CubsTypeContext* returnContext)
{
    assert(self.outReturn.value != NULL);
    assert(self.outReturn.context != NULL);
    assert(returnValue != NULL);
    assert(returnContext != NULL);

    memcpy(self.outReturn.value, returnValue, returnContext->sizeOfType);
    *self.outReturn.context = returnContext;
}
