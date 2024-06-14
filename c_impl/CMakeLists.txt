cmake_minimum_required (VERSION 3.12)

if (POLICY CMP0141)
  cmake_policy(SET CMP0141 NEW)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug,RelWithDebInfo>:EditAndContinue>,$<$<CONFIG:Debug,RelWithDebInfo>:ProgramDatabase>>")
endif()

project("CubicScript")

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")

add_library(CubicScript STATIC 
    "src/program/program.c"
    "src/interpreter/stack.c"
    "src/interpreter/bytecode.c"
    "src/sync/atomic_ref_count.c"
    "src/sync/mutex.c"
    "src/sync/rwlock.c"
    "src/sync/sync_queue.c"
    "src/sync/script_thread.c"
    "src/util/global_allocator.c"
    "src/util/panic.c"
    "src/util/os.c"
    "src/util/math.c"
    "src/util/hash.c"
    "src/primitives/script_value.c"
    "src/primitives/string/string.c"
    "src/primitives/array/array.c"
    "src/primitives/map/map.c"
    "src/primitives/set/set.c"
    "src/primitives/option/option.c"
    "src/primitives/result/result.c"
    "src/primitives/vector/vector.c"
)

target_include_directories(CubicScript PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

# TODO improve this
if (CMAKE_SYSTEM_PROCESSOR MATCHES "(x86)|(X86)|(amd64)|(AMD64)")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mavx2")
    target_compile_options(CubicScript PRIVATE $<$<BOOL:${MSVC}>:/arch:AVX2>)
else ()
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
endif ()