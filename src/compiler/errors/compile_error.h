#pragma once
#ifndef COMPILE_ERROR_H
#define COMPILE_ERROR_H

#include "../../primitives/string/string_slice.h"
#include "../../primitives/string/string.h"
#include "../compiler.h"

typedef enum CompileErrorType {
    compileErrorTypeUnexpectedToken,
} CompileErrorType;

typedef void(*CompileErrorDeinit)(void* self);

typedef struct CompileErrorVTable {
    CompileErrorType    errType;
    CompileErrorDeinit  deinit;
} CompileErrorVTable;

typedef struct CompileError {
    const CompileErrorVTable*   vtable;
    void*                       ptr;
    CubsCompileErrorLocation    location;
    CubsString                  message;
} CompileError;

void cubs_compile_error_deinit(CompileError* self);

static inline CubsString charPosToString(CubsSourceFileCharPosition pos) {
    CubsString temp = {0};
    CubsString out = cubs_string_init_unchecked((CubsStringSlice){.str = "Byte ", .len = 5});

    CubsString byteString = cubs_string_from_int(pos.index);
    temp = cubs_string_concat(&out, &byteString);
    cubs_string_deinit(&out);
    cubs_string_deinit(&byteString);

    out = cubs_string_concat_slice_unchecked(&temp, (CubsStringSlice){.str = ", Ln ", .len = 5});
    cubs_string_deinit(&temp);
    
    CubsString lineString = cubs_string_from_int(pos.line);
    temp = cubs_string_concat(&out, &cubs_string_concat);
    cubs_string_deinit(&out);
    cubs_string_deinit(&lineString);

    out = cubs_string_concat_slice_unchecked(&temp, (CubsStringSlice){.str = ", Col ", .len = 6});
    cubs_string_deinit(&temp);

    CubsString columnString = cubs_string_from_int(pos.column);
    temp = cubs_string_concat(&out, &cubs_string_concat);
    cubs_string_deinit(&out);
    cubs_string_deinit(&columnString);

    return temp;
}

#endif