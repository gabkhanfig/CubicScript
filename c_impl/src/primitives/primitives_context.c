#include "primitives_context.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"
#include "../primitives/map/map.h"
#include "../util/panic.h"
#include <assert.h>

static void bool_clone(bool* dst, const bool* self) {
    *dst = *self;
}

static bool bool_eql(const bool* self, const bool* other) {
    return *self == *other;
}

static size_t bool_hash(const bool* self) {
    return (size_t)(*self);
}

const CubsStructContext CUBS_BOOL_CONTEXT = {
    .sizeOfType = sizeof(bool),
    .tag = cubsValueTagBool,
    .onDeinit = NULL,
    .clone = (CubsStructCloneFn)&bool_clone,
    .eql = (CubsStructEqlFn)&bool_eql,
    .hash = (CubsStructHashFn)&bool_hash,
    .name = "bool",
    .nameLength = 4,
};

static void int_clone(int64_t* dst, const int64_t* self) {
    *dst = *self;
}

static bool int_eql(const int64_t* self, const int64_t* other) {
    return *self == *other;
}

static size_t int_hash(const int64_t* self) {
    return (size_t)(*self);
}

const CubsStructContext CUBS_INT_CONTEXT = {
    .sizeOfType = sizeof(int64_t),
    .tag = cubsValueTagInt,
    .onDeinit = NULL, 
    .clone = (CubsStructCloneFn)&int_clone,
    .eql = (CubsStructEqlFn)&int_eql,
    .hash = (CubsStructHashFn)&int_hash,
    .name = "int",
    .nameLength = 3,
};

static void float_clone(double* dst, const double* self) {
    *dst = *self;
}

static bool float_eql(const double* self, const double* other) {
    return *self == *other;
}

static size_t float_hash(const double* self) {  
    // Since technically multiple representations can be the same value,
    // cast to an integer and hash from there
    const int64_t floatAsInt = (int64_t)(*self);
    return int_hash(&floatAsInt);
}

const CubsStructContext CUBS_FLOAT_CONTEXT = {
    .sizeOfType = sizeof(double),
    .tag = cubsValueTagFloat,
    .onDeinit = NULL, 
    .clone = (CubsStructCloneFn)&float_clone,
    .eql = (CubsStructEqlFn)&float_eql,
    .hash = (CubsStructHashFn)&float_hash,
    .name = "float",
    .nameLength = 5,
};

static void string_clone(CubsString* dst, const CubsString* self) {
    const CubsString temp = cubs_string_clone(self);
    *dst = temp;
}

const CubsStructContext CUBS_STRING_CONTEXT = {
    .sizeOfType = sizeof(CubsString),
    .tag = cubsValueTagString,
    .onDeinit = (CubsStructOnDeinit)&cubs_string_deinit,
    .clone = (CubsStructCloneFn)&string_clone,
    .eql = (CubsStructEqlFn)&cubs_string_eql,
    .hash = (CubsStructHashFn)&cubs_string_hash,
    .name = "string",
    .nameLength = 6,
};

static void array_clone(CubsArray* dst, const CubsArray* self) {
    const CubsArray temp = cubs_array_clone(self);
    *dst = temp;
}

const CubsStructContext CUBS_ARRAY_CONTEXT = {
    .sizeOfType = sizeof(CubsArray),
    .tag = cubsValueTagArray,
    .onDeinit = (CubsStructOnDeinit)&cubs_array_deinit,
    .clone = (CubsStructCloneFn)&array_clone,
    .eql = (CubsStructEqlFn)&cubs_array_eql,
    .hash = NULL,
    .name = "array",
    .nameLength = 5,
};

static void map_clone(CubsMap* dst, const CubsMap* self) {
    const CubsMap temp = cubs_map_clone(self);
    *dst = temp;
}

const CubsStructContext CUBS_MAP_CONTEXT = {
    .sizeOfType = sizeof(CubsMap),
    .tag = cubsValueTagMap,
    .onDeinit = (CubsStructOnDeinit)&cubs_map_deinit,
    .clone = (CubsStructCloneFn)&map_clone,
    .eql = NULL,
    .hash = NULL,
    .name = "map",
    .nameLength = 3,
};

const CubsStructContext *cubs_primitive_context_for_tag(CubsValueTag tag)
{
    assert(tag != cubsValueTagUserStruct && "This function is for primitive types only");
    switch(tag) {
        case cubsValueTagBool: {
            return &CUBS_BOOL_CONTEXT;
        } break;
        case cubsValueTagInt: {
            return &CUBS_INT_CONTEXT;
        } break;
        case cubsValueTagFloat: {
            return &CUBS_FLOAT_CONTEXT;
        } break;
        case cubsValueTagString: {
            return &CUBS_STRING_CONTEXT;
        } break;
        case cubsValueTagArray: {
            return &CUBS_ARRAY_CONTEXT;
        } break;
        case cubsValueTagMap: {
            return &CUBS_MAP_CONTEXT;
        } break;
        default: {
            cubs_panic("unsupported primitive context type");
        } break;
    }
}
