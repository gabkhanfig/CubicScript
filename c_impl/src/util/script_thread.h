#pragma once

/// A function pointer for when the script instance has closed and the thread is no longer needed.
typedef void(*CubsThreadOnScriptClose)(void* threadObj);
typedef int(*CubsThreadGetId)(const void* threadObj);
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

CubsThread cubs_thread_spawn(void* optionalOwner);

void cubs_thread_close(CubsThread* thread);

int cubs_thread_get_id(const CubsThread* thread);
