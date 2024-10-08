#include "panic.h"
#include "unreachable.h"
#include <stdio.h>

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

void cubs_panic(const char* message) {
    #if _DEBUG
    fprintf(stderr, "CubicScript panic:\n%s\n", message);
    DebugBreak();
    #else 
    MessageBox(NULL, message, "CubicScript Panic", MB_ICONERROR | MB_OK);
    abort();
    #endif
}

#elif __GNUC__

#include <stdlib.h>

void cubs_panic(const char* message) {
    #if _DEBUG
    fprintf(stderr, "CubicScript panic:\n%s\n", message);
    __builtin_trap();
    #else
    abort();
    #endif
}

#endif

