#ifndef PROGRAM_TYPE_CONTEXT_H
#define PROGRAM_TYPE_CONTEXT_H

#include <stdbool.h>
#include "../primitives/context.h"

union TypeContext {
    const CubsTypeContext* userContext;
    CubsTypeContext* scriptContext;
};

typedef struct ProgramTypeContext {
    union TypeContext context;
    bool isScriptContext;
} ProgramTypeContext;

#endif