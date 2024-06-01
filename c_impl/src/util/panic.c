#include "panic.h"
#include "unreachable.h"
#include <stdio.h>

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#endif // WIN32

void cubs_panic(const char *message)
{
    #if _DEBUG
    fprintf(stderr, "CubicScript panic:\n%s\n", message);
    #if defined(_WIN32) || defined(WIN32)
    DebugBreak();
    #else __GNUC__
    __builtin_trap();
    #endif
    #else // _DEBUG
    #if defined(_WIN32) || defined(WIN32)
    MessageBox(NULL, message, "CubicScript Panic", MB_ICONERROR | MB_OK);
    #endif //WIN32
    fprintf(stderr, "CubicScript panic:\n%s\n", message);
    abort();
    #endif
    unreachable();
}

