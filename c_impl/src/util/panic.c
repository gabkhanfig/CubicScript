#include "panic.h"
#include "unreachable.h"

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>

void cubs_panic(const char *message)
{
    #if _DEBUG
    fprintf(stderr, "CubicScript panic:\n%s\n", message);
    DebugBreak();
    #else
    MessageBox(NULL, message, "CubicScript Panic", MB_ICONERROR | MB_OK);
    abort();
    #endif
    unreachable();
}

#endif


