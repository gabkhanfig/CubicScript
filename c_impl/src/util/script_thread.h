#pragma once

#include <stdbool.h>
#include <stdint.h>

/// A function pointer for when the script instance has closed and the thread is no longer needed.
typedef void(*CubsThreadOnScriptClose)(void* threadObj);
typedef uint32_t(*CubsThreadGetId)(const void* threadObj);
typedef void(*CubsThreadClose)(void* threadObj);

typedef struct CubsThreadVTable {
    /// Can be `NULL`.
    CubsThreadOnScriptClose onScriptClose;
    /// Must not be `NULL`.
    CubsThreadGetId getId;
    /// Can be `NULL`. Will explicitly close the thread if not `NULL`.
    CubsThreadClose close;
} CubsThreadVTable;

typedef struct CubsThread {
    void* threadObj;
    const CubsThreadVTable* vtable;
} CubsThread;

CubsThread cubs_thread_spawn(bool closeWithScript);

void cubs_thread_close(CubsThread* thread);

uint32_t cubs_thread_get_id(const CubsThread* thread);