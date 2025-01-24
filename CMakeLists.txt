cmake_minimum_required (VERSION 3.12)

if (POLICY CMP0141)
  cmake_policy(SET CMP0141 NEW)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug,RelWithDebInfo>:EditAndContinue>,$<$<CONFIG:Debug,RelWithDebInfo>:ProgramDatabase>>")
endif()

project("CubicScript")

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
set(CMAKE_CXX_STANDARD 17)

add_library(CubicScript STATIC 
    "src/validate_compilation_target.c"
    
    "src/platform/mem.c"

    "src/program/program.c"
    "src/program/protected_arena.c"
    "src/program/function_map.c"
    "src/program/type_map.c"
    "src/program/function_call_args.c"

    "src/interpreter/bytecode.c"
    "src/interpreter/interpreter.c"
    "src/interpreter/function_definition.c"
    "src/interpreter/operations.c"
    "src/interpreter/stack.c"

    "src/compiler/build_options.c"
    "src/compiler/compiler.c"
    "src/compiler/ast.c"
    "src/compiler/tokenizer.c"
    "src/compiler/stack_variables.c"
    "src/compiler/ast_nodes/file_node.c"
    "src/compiler/ast_nodes/function_node.c"
    "src/compiler/ast_nodes/return_node.c"
    "src/compiler/ast_nodes/binary_expression.c"
    "src/compiler/ast_nodes/variable_declaration.c"
    "src/compiler/ast_nodes/expression_value.c"
    "src/compiler/ast_nodes/struct_node.c"
    "src/compiler/ast_nodes/member_variable.c"

    "src/sync/atomic.c"
    "src/sync/locks.c"
    "src/sync/sync_queue.c"
    "src/sync/thread.c"

    "src/util/panic.c"
    "src/util/simd.c"
    "src/util/math.c"
    "src/util/hash.c"
    "src/util/utf8.c"

    "src/primitives/context.c"
    "src/primitives/string/string.c"
    "src/primitives/array/array.c"
    "src/primitives/map/map.c"
    "src/primitives/set/set.c"
    "src/primitives/option/option.c"
    "src/primitives/error/error.c"
    "src/primitives/result/result.c"
    "src/primitives/sync_ptr/sync_ptr.c"
    "src/primitives/reference/reference.c"
    "src/primitives/vector/vector.c"
    "src/primitives/function/function.c"
)

add_executable(CubicScriptCppTests
    "src/cpp_tests.cpp"
    "src/primitives/string/string_tests.cpp"
    "src/primitives/array/array_tests.cpp"
)

target_link_libraries(CubicScriptCppTests CubicScript)

target_include_directories(CubicScript PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

# TODO improve this
if (CMAKE_SYSTEM_PROCESSOR MATCHES "(x86)|(X86)|(amd64)|(AMD64)")
    target_compile_options(CubicScript PRIVATE $<$<BOOL:${MSVC}>:/arch:AVX2>)
else ()
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
endif ()