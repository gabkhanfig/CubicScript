#pragma once

typedef enum CubsValueTag {
    // 0 is reserved for internal use

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
    cubsValueTagClass = 19,
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
    // Enforce enum size is at least 32 bits
    _CUBS_VALUE_TAG_MAX_VALUE = 0x7FFFFFFF,
} CubsValueTag;