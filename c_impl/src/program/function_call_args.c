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

const size_t CURRENT_OFFSET = 0;
const size_t PUSHED_ARG_COUNT = 1;

void cubs_function_push_arg(CubsFunctionCallArgs *self, void *arg, const CubsTypeContext *typeContext)
{
    if(self->func->funcType == cubsFunctionPtrTypeScript) {
        const int currentOffset = self->_inner[CURRENT_OFFSET];
        const int currentPushedArgs = self->_inner[PUSHED_ARG_COUNT];

        #if _DEBUG
        const ScriptFunctionDefinitionHeader* header = (const ScriptFunctionDefinitionHeader*)self->func->_inner;
        char buf[512];
        if(currentPushedArgs >= header->args.len) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Script function [%s] expects %lld arguments", cubs_string_as_slice(&header->name).str, header->args.len);
            #else
            const int len = sprintf(buf, "Script function [%s] expects %ld arguments", cubs_string_as_slice(&header->name).str, header->args.len);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        if(currentOffset > header->stackSpaceRequired) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Overflowed script function [%s] stack frame with function arguments", cubs_string_as_slice(&header->name).str);
            #else
            const int len = sprintf(buf, "Overflowed script function [%s] stack frame with function arguments", cubs_string_as_slice(&header->name).str);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        #endif

        cubs_interpreter_push_function_arg(arg, typeContext, currentOffset);

        const int offsetToAdd = (int)ROUND_SIZE_TO_MULTIPLE_OF_8(typeContext->sizeOfType);
        self->_inner[CURRENT_OFFSET] += offsetToAdd;
        self->_inner[PUSHED_ARG_COUNT] += 1;
    } else {
        cubs_panic("TODO extern C functions");
    }
}

void cubs_function_call(CubsFunctionCallArgs self, const struct CubsProgram* program, CubsFunctionReturn outReturn)
{    
    if(self.func->funcType == cubsFunctionPtrTypeScript) {
        
        const int currentOffset = self._inner[CURRENT_OFFSET];
        const int currentPushedArgs = self._inner[PUSHED_ARG_COUNT];

        const ScriptFunctionDefinitionHeader* header = (const ScriptFunctionDefinitionHeader*)self.func->_inner;

        #if _DEBUG
        char buf[512];
        if(currentPushedArgs != header->args.len) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Script function [%s] expects %lld arguments. Only %lld passed in", cubs_string_as_slice(&header->name).str, header->args.len, currentPushedArgs);
            #else
            const int len = sprintf(buf, "Script function [%s] expects %ld arguments. Only %lld passed in", cubs_string_as_slice(&header->name).str, header->args.len, currentPushedArgs);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        if(currentOffset > header->stackSpaceRequired) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Overflowed script function [%s] stack frame with function arguments", cubs_string_as_slice(&header->name).str);
            #else
            const int len = sprintf(buf, "Overflowed script function [%s] stack frame with function arguments", cubs_string_as_slice(&header->name).str);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        if(header->optReturnType != NULL && outReturn == NULL) {
            #if defined(_WIN32) || defined(WIN32)
            const int len = sprintf_s(buf, 512, "Script function [%s] expected return value destination", cubs_string_as_slice(&header->name).str);
            #else
            const int len = sprintf(buf, "Script function [%s] expected return value destination", cubs_string_as_slice(&header->name).str);
            #endif
            assert(len >= 0);   
            cubs_panic(buf);
        }
        #endif

        cubs_interpreter_execute_function(program, header, outReturn.value, outReturn.context);
    } else {
        cubs_panic("TODO extern C functions");
    }
}

void cubs_function_return_set_value(CubsFunctionReturn self, void *returnValue, const CubsTypeContext *returnContext)
{
    assert(self.value != NULL);
    assert(self.context != NULL);
    assert(returnValue != NULL);
    assert(returnContext != NULL);

    memcpy(self.value, returnValue, returnContext->sizeOfType);
    *self.context = returnContext;
}
