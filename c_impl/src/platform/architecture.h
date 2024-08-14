#pragma once

// what the frick is MSVC _M_ARM64EC
//#if defined(_M_ARM64EC)

#if defined(_M_X64) || defined(__x86_64__)
#define CUBS_ARCH_X86_64 1
#elif defined(_M_ARM64) || defined(__aarch64__)
#define CUBS_ARCH_ARM64 1
#endif