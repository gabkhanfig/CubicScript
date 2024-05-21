#include "script_thread.h"
#include "global_allocator.h"
#include "panic.h"
#include <stdio.h>

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

typedef struct {
    HANDLE thread;
    DWORD identifier;
    /// May be NULL
    bool closeWithScript;
} CubsThreadWindowsImpl;

static DWORD WINAPI windows_thread_loop(CubsThreadWindowsImpl* self) {
    return 0;
}

static void windows_thread_close(CubsThreadWindowsImpl* self) {
    WaitForSingleObject(self->thread, INFINITE);
    CloseHandle(self->thread);
    cubs_free((void*)self, sizeof(CubsThreadWindowsImpl), _Alignof(CubsThreadWindowsImpl));
}

/// If `self` has an owner, don't bother freeing the thread on script close.
static void windows_thread_on_script_close(CubsThreadWindowsImpl* self) {
    if(self->closeWithScript == false) {
        return;
    }

    windows_thread_close(self);
}

static int windows_thread_get_id(const CubsThreadWindowsImpl* self) {
    return (int)self->identifier;
}

const CubsThreadVTable windowsVTable = {
    .onScriptClose = (CubsThreadOnScriptClose)&windows_thread_on_script_close, 
    .getId = (CubsThreadGetId)&windows_thread_get_id,
    .close = (CubsThreadClose)&windows_thread_close,
};

CubsThread cubs_thread_spawn(bool closeWithScript)
{
    CubsThread thread = {.threadObj = NULL, .vtable = NULL};

    CubsThreadWindowsImpl* impl = cubs_malloc(sizeof(CubsThreadWindowsImpl), _Alignof(CubsThreadWindowsImpl));

    DWORD identifier;
    HANDLE handle = CreateThread(
        NULL, // default security attributes
        0,  // default stack size
        (LPTHREAD_START_ROUTINE)windows_thread_loop, // function name
        impl, // argument to function
        0, // default creation flags
        &identifier); // thread identifier

    if(handle == NULL) {
        cubs_free((void*)impl, sizeof(CubsThreadWindowsImpl), _Alignof(CubsThreadWindowsImpl));
        cubs_panic("Failed to spawn CubicScript thread");
    }

    impl->thread = handle;
    impl->identifier = identifier;
    impl->closeWithScript = closeWithScript;

    thread.threadObj = (void*)impl;
    thread.vtable = &windowsVTable;

    
    return thread;
}

#endif // WIN32

int cubs_thread_get_id(const CubsThread *thread)
{
    return thread->vtable->getId(thread->threadObj);
}

void cubs_thread_close(CubsThread *thread)
{
    if(thread->vtable->close == NULL) {
        return;
    }
    thread->vtable->close(thread->threadObj);
}
