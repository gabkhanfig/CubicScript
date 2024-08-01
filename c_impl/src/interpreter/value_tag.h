#pragma once

#include "../primitives/primitives_context.h"
#include <assert.h>
#include "../util/panic.h"

typedef enum CubsValueTag {
    cubsValueTagBool = 1,
    cubsValueTagInt = 2,
    cubsValueTagFloat = 3,
    cubsValueTagChar = 4,
    cubsValueTagString = 5,
    cubsValueTagStringIter = 6,
    cubsValueTagArray = 7,
    cubsValueTagArrayConstIter = 8,
    cubsValueTagArrayMutIter = 9,
    cubsValueTagSet = 10,
    cubsValueTagSetIter = 11,
    cubsValueTagMap = 12,
    cubsValueTagMapConstIter = 13,
    cubsValueTagMapMutIter = 14,
    cubsValueTagOption = 15,
    cubsValueTagError = 16,
    cubsValueTagResult = 17,
    cubsValueTagTaggedUnion = 18,
    cubsValueTagUserClass = 19,
    cubsValueTagOwnedInterface = 20,
    cubsValueTagInterfaceRef = 21,
    cubsValueTagConstRef = 22,
    cubsValueTagMutRef = 23,
    cubsValueTagUnique = 24,
    cubsValueTagShared = 25,
    cubsValueTagWeak = 26,
    cubsValueTagFunctionPtr = 27,
    cubsValueTagFuture = 28,
    cubsValueTagVec2i = 29,
    cubsValueTagVec3i = 30,
    cubsValueTagVec4i = 31,
    cubsValueTagVec2f = 32,
    cubsValueTagVec3f = 33,
    cubsValueTagVec4f = 34,
    cubsValueTagMat3f = 35,
    cubsValueTagMat4f = 36,

    // Reserved for internal use.
    _CUBS_VALUE_TAG_NONE = 0,
    // Reserved for internal use. Enforces enum size is at least 32 bits.
    _CUBS_VALUE_TAG_MAX_VALUE = 0x7FFFFFFF,
} CubsValueTag;

static inline const CubsTypeContext *cubs_primitive_context_for_tag(CubsValueTag tag)
{
    assert(tag != cubsValueTagUserClass && "This function is for primitive types only");
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
        case cubsValueTagError: {
            return &CUBS_ERROR_CONTEXT;
        } break;
        case cubsValueTagResult: {
            return &CUBS_RESULT_CONTEXT;
        } break;
        case cubsValueTagUnique: {
            return &CUBS_UNIQUE_CONTEXT;
        } break;
        case cubsValueTagShared: {
            return &CUBS_SHARED_CONTEXT;
        } break;
        case cubsValueTagWeak: {
            return &CUBS_WEAK_CONTEXT;
        }
        default: {
            cubs_panic("unsupported primitive context type");
        } break;
    }
    return NULL;
}