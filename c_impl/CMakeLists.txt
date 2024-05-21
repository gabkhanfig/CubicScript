cmake_minimum_required (VERSION 3.12)

if (POLICY CMP0141)
  cmake_policy(SET CMP0141 NEW)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug,RelWithDebInfo>:EditAndContinue>,$<$<CONFIG:Debug,RelWithDebInfo>:ProgramDatabase>>")
endif()

project("CubicScript")

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")

add_library(CubicScript STATIC 
  "src/util/atomic_ref_count.c"
  "src/util/global_allocator.c"
  "src/util/rwlock.c"
  "src/util/panic.c"
  "src/util/math.c"
  "src/util/script_thread.c"
  "src/primitives/script_value.c"
  "src/primitives/string.c"
  "src/primitives/array.c"
)

target_include_directories(CubicScript PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_options(CubicScript PRIVATE $<$<BOOL:${MSVC}>:/arch:AVX2>)