#include "primitives_context.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"
#include "../primitives/set/set.h"
#include "../primitives/map/map.h"
#include "../primitives/option/option.h"
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

const CubsTypeContext CUBS_BOOL_CONTEXT = {
    .sizeOfType = 1,
    .powOf8Size = sizeof(size_t),
    .tag = cubsValueTagBool,
    .destructor = NULL,
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
    // Don't bother combining with the seed, as the hashmap and hashset do that themselves
    return (size_t)(*self);
}

const CubsTypeContext CUBS_INT_CONTEXT = {
    .sizeOfType = sizeof(int64_t),
    .powOf8Size = sizeof(int64_t),
    .tag = cubsValueTagInt,
    .destructor = NULL, 
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
    // Don't bother combining with the seed, as the hashmap and hashset do that themselves
    const int64_t floatAsInt = (int64_t)(*self);
    return int_hash(&floatAsInt);
}

const CubsTypeContext CUBS_FLOAT_CONTEXT = {
    .sizeOfType = sizeof(double),
    .powOf8Size = sizeof(double),
    .tag = cubsValueTagFloat,
    .destructor = NULL, 
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

const CubsTypeContext CUBS_STRING_CONTEXT = {
    .sizeOfType = sizeof(CubsString),
    .powOf8Size = sizeof(CubsString),
    .tag = cubsValueTagString,
    .destructor = (CubsStructDestructorFn)&cubs_string_deinit,
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

const CubsTypeContext CUBS_ARRAY_CONTEXT = {
    .sizeOfType = sizeof(CubsArray),
    .powOf8Size = sizeof(CubsArray),
    .tag = cubsValueTagArray,
    .destructor = (CubsStructDestructorFn)&cubs_array_deinit,
    .clone = (CubsStructCloneFn)&array_clone,
    .eql = (CubsStructEqlFn)&cubs_array_eql,
    .hash = (CubsStructHashFn)&cubs_array_hash,
    .name = "array",
    .nameLength = 5,
};

static void set_clone(CubsSet* dst, const CubsSet* self) {
    const CubsSet temp = cubs_set_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_SET_CONTEXT = {  
    .sizeOfType = sizeof(CubsSet),
    .powOf8Size = sizeof(CubsSet),
    .tag = cubsValueTagSet,
    .destructor = (CubsStructDestructorFn)&cubs_set_deinit,
    .clone = (CubsStructCloneFn)&set_clone,
    .eql = (CubsStructEqlFn)&cubs_set_eql,
    .hash = (CubsStructHashFn)&cubs_set_hash,
    .name = "set",
    .nameLength = 3,
};

static void map_clone(CubsMap* dst, const CubsMap* self) {
    const CubsMap temp = cubs_map_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_MAP_CONTEXT = {
    .sizeOfType = sizeof(CubsMap),
    .powOf8Size = sizeof(CubsMap),
    .tag = cubsValueTagMap,
    .destructor = (CubsStructDestructorFn)&cubs_map_deinit,
    .clone = (CubsStructCloneFn)&map_clone,
    .eql = (CubsStructEqlFn)&cubs_map_eql,
    .hash = (CubsStructHashFn)&cubs_map_hash,
    .name = "map",
    .nameLength = 3,
};

static void option_clone(CubsOption* dst, const CubsOption* self) {
    const CubsOption temp = cubs_option_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_OPTION_CONTEXT = {
    .sizeOfType = sizeof(CubsOption),
    .powOf8Size = sizeof(CubsOption),
    .tag = cubsValueTagOption,
    .destructor = (CubsStructDestructorFn)&cubs_option_deinit,
    .clone = (CubsStructCloneFn)&option_clone,
    .eql = (CubsStructEqlFn)&cubs_option_eql,
    .hash = (CubsStructHashFn)&cubs_option_hash,
    .name = "option",
    .nameLength = 6,
};

const CubsTypeContext *cubs_primitive_context_for_tag(CubsValueTag tag)
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
        case cubsValueTagSet: {
            return &CUBS_SET_CONTEXT;
        } break;
        case cubsValueTagMap: {
            return &CUBS_MAP_CONTEXT;
        } break;
        case cubsValueTagOption: {
            return &CUBS_OPTION_CONTEXT;
        } break;
        default: {
            cubs_panic("unsupported primitive context type");
        } break;
    }
}
