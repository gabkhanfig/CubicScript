#pragma once

typedef enum CubsValueTag {
    cubsValueTagNone = 0,
    cubsValueTagBool = 1,
    cubsValueTagInt = 2,
    cubsValueTagFloat = 3,
    cubsValueTagString = 4,
    cubsValueTagArray = 5,
    cubsValueTagSet = 6,
    cubsValueTagMap = 7,
    cubsValueTagOption = 8,
    cubsValueTagResult = 9,
    cubsValueTagClass = 10,
    cubsValueTagOwnedInterface = 11,
    cubsValueTagInterfaceRef = 12,
    cubsValueTagConstRef = 13,
    cubsValueTagMutRef = 14,
    cubsValueTagUnique = 15,
    cubsValueTagShared = 16,
    cubsValueTagWeak = 17,
    cubsValueTagFunctionPtr = 18,
    cubsValueTagVec2i = 19,
    cubsValueTagVec3i = 20,
    cubsValueTagVec4i = 21,
    cubsValueTagVec2f = 21,
    cubsValueTagVec3f = 23,
    cubsValueTagVec4f = 24,
    cubsValueTagMat3f = 25,
    cubsValueTagMat4f = 26,
    // Enforce enum size is at least 32 bits, which is `int` on most platforms
    _CUBS_VALUE_TAG_MAX_VALUE = 0x7FFFFFFF,
} CubsValueTag;