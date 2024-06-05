#include "script_thread.h"
#include "../util/global_allocator.h"
#include "../util/panic.h"
#include <stdio.h>
#include "rwlock.h"

#if defined(_WIN32) || defined(WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#if _MSC_VER
#include <vcruntime_c11_atomic_support.h>
#endif

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

static uint64_t windows_thread_get_id(const CubsThreadWindowsImpl* self) {
    return (uint64_t)self->identifier;
}

const CubsThreadVTable windowsVTable = {
    .onScriptClose = (CubsThreadOnScriptClose)&windows_thread_on_script_close, 
    .getId = (CubsThreadGetId)&windows_thread_get_id,
    .join = (CubsThreadJoin)&windows_thread_close,
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

#if __unix__

#include <pthread.h>

typedef struct {
    pthread_t thread;
    /// May be NULL
    bool closeWithScript; 
} CubsThreadPThreadImpl;

static void* pthread_thread_loop(void* self) {
    return NULL;
}

static void pthread_thread_close(CubsThreadPThreadImpl* self) {
    pthread_join(self->thread, NULL);
    cubs_free((void*)self, sizeof(CubsThreadPThreadImpl), _Alignof(CubsThreadPThreadImpl));
}

/// If `self` has an owner, don't bother freeing the thread on script close.
static void pthread_thread_on_script_close(CubsThreadPThreadImpl* self) {
    if(self->closeWithScript == false) {
        return;
    }

    pthread_thread_close(self);
}

static uint64_t pthread_thread_get_id(const CubsThreadPThreadImpl* self) {
    return (uint64_t)self->thread;
}

const CubsThreadVTable pthreadVTable = {
    .onScriptClose = (CubsThreadOnScriptClose)&pthread_thread_on_script_close, 
    .getId = (CubsThreadGetId)&pthread_thread_get_id,
    .close = (CubsThreadClose)&pthread_thread_close,
};

CubsThread cubs_thread_spawn(bool closeWithScript) {
    CubsThread thread = {.threadObj = NULL, .vtable = NULL};

    CubsThreadPThreadImpl* impl = cubs_malloc(sizeof(CubsThreadPThreadImpl), _Alignof(CubsThreadPThreadImpl));
    
    pthread_create(&impl->thread, NULL, pthread_thread_loop, (void*)impl);
    impl->closeWithScript = closeWithScript;
    
    thread.threadObj = (void*)impl;
    thread.vtable = &pthreadVTable;

    return thread;
}

#endif

uint64_t cubs_thread_get_id(const CubsThread *thread)
{
    return thread->vtable->getId(thread->threadObj);
}

void cubs_thread_close(CubsThread *thread)
{
    if(thread->vtable->join == NULL) {
        return;
    }
    thread->vtable->join(thread->threadObj);
}
