#include <stddef.h>

#if defined(_WIN32) || defined(WIN32)
#include <malloc.h>
#elif __GNUC__
#include <stdlib.h>
#endif

void* _cubs_os_aligned_malloc(size_t len, size_t align) {
    #if defined(_WIN32) || defined(WIN32)
    // https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/aligned-malloc?view=msvc-170&viewFallbackFrom=vs-2019
    return _aligned_malloc(len, (size_t)align);
    #elif __GNUC__
    return aligned_alloc(align, len);
    #endif
}

void _cubs_os_aligned_free(void *buf, size_t len, size_t align) {
    #if defined(_WIN32) || defined(WIN32)
    // https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/aligned-free?view=msvc-170
    _aligned_free(buf);
    #elif __GNUC__
    free(buf);
    #endif
}