#pragma once

namespace cubs {
    namespace detail {
        #include "script_value.h"
    }

    enum class ValueTag : int {
        Bool = detail::cubsValueTagBool,
        Int = detail::cubsValueTagInt,
        Float = detail::cubsValueTagFloat,
        Char = detail::cubsValueTagChar,
        String = detail::cubsValueTagString,
        StringIter = detail::cubsValueTagStringIter,
        Array = detail::cubsValueTagArray,
        ArrayConstIter = detail::cubsValueTagArrayConstIter,
        ArrayMutIter = detail::cubsValueTagArrayMutIter,
        Set = detail::cubsValueTagSet,
        SetIter = detail::cubsValueTagSetIter,
        Map = detail::cubsValueTagMapConstIter,
        MapConstIter = detail::cubsValueTagMapConstIter,
        MapMutIter = detail::cubsValueTagMapMutIter,
        Option = detail::cubsValueTagOption,
        Error = detail::cubsValueTagError,
        Result = detail::cubsValueTagResult,
        TaggedUnion = detail::cubsValueTagTaggedUnion,
        UserClass = detail::cubsValueTagUserClass,
        OwnedInterface = detail::cubsValueTagOwnedInterface,
        InterfaceRef = detail::cubsValueTagInterfaceRef,
        ConstRef = detail::cubsValueTagConstRef,
        MutRef = detail::cubsValueTagMutRef,
        Unique = detail::cubsValueTagUnique,
        Shared = detail::cubsValueTagShared,
        Weak = detail::cubsValueTagWeak,
        FunctionPtr = detail::cubsValueTagFunctionPtr,
        Future = detail::cubsValueTagFuture,
        Vec2i = detail::cubsValueTagVec2i,
        Vec3i = detail::cubsValueTagVec3i,
        Vec4i = detail::cubsValueTagVec4i,
        Vec2f = detail::cubsValueTagVec2f,
        Vec3f = detail::cubsValueTagVec3f,
        Vec4f = detail::cubsValueTagVec4f,
        Mat3f = detail::cubsValueTagMat3f,
        Mat4f = detail::cubsValueTagMat4f,
    };

    using TypeContext = detail::CubsTypeContext;
}