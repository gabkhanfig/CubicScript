#pragma once
#ifndef COMPILE_ERROR_H
#define COMPILE_ERROR_H

#include "../../primitives/string/string_slice.h"
#include "../compiler.h"

typedef void(*CompileErrorDeinit)(void* self);
/// Gets the source file location of the error.
typedef CubsCompileErrorLocation (*CompileErrorWhere)(const void* self);
/// Gets the error message of the compile error.
typedef CubsStringSlice (*CompileErrorWhat)(const void* self);

typedef struct CompileErrorVTable {
    CompileErrorDeinit deinit;
    CompileErrorWhere where;
    CompileErrorWhat what;
} CompileErrorVTable;

typedef struct CompileError {
    void* ptr;
    const CompileErrorVTable* vtable;
} CompileError;

void cubs_compile_error_deinit(CompileError* self);

CubsCompileErrorLocation cubs_compile_error_where(const CompileError* self);

CubsStringSlice cubs_compile_error_what(const CompileError* self);

#endif