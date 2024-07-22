#pragma once

#include "script_value.h"
#include "primitives_context.h"

namespace cubs {
    namespace detail {
    }

    enum class ValueTag : int {
        Bool = cubsValueTagBool,
        Int = cubsValueTagInt,
        Float = cubsValueTagFloat,
        Char = cubsValueTagChar,
        String = cubsValueTagString,
        StringIter = cubsValueTagStringIter,
        Array = cubsValueTagArray,
        ArrayConstIter = cubsValueTagArrayConstIter,
        ArrayMutIter = cubsValueTagArrayMutIter,
        Set = cubsValueTagSet,
        SetIter = cubsValueTagSetIter,
        Map = cubsValueTagMapConstIter,
        MapConstIter = cubsValueTagMapConstIter,
        MapMutIter = cubsValueTagMapMutIter,
        Option = cubsValueTagOption,
        Error = cubsValueTagError,
        Result = cubsValueTagResult,
        TaggedUnion = cubsValueTagTaggedUnion,
        UserClass = cubsValueTagUserClass,
        OwnedInterface = cubsValueTagOwnedInterface,
        InterfaceRef = cubsValueTagInterfaceRef,
        ConstRef = cubsValueTagConstRef,
        MutRef = cubsValueTagMutRef,
        Unique = cubsValueTagUnique,
        Shared = cubsValueTagShared,
        Weak = cubsValueTagWeak,
        FunctionPtr = cubsValueTagFunctionPtr,
        Future = cubsValueTagFuture,
        Vec2i = cubsValueTagVec2i,
        Vec3i = cubsValueTagVec3i,
        Vec4i = cubsValueTagVec4i,
        Vec2f = cubsValueTagVec2f,
        Vec3f = cubsValueTagVec3f,
        Vec4f = cubsValueTagVec4f,
        Mat3f = cubsValueTagMat3f,
        Mat4f = cubsValueTagMat4f,
    };

    /// See `autoTypeContext<T>()` to automatically create one for a type.
    using TypeContext = CubsTypeContext;

    // namespace detail {
    //     template<typename T, typename = void>
    //     struct has_user_defined_context : std::false_type {};

    //     template<typename T>
    //     struct has_user_defined_context<T, std::enable_if_t<std::is_invocable_r<const TypeContext*, decltype(T::scriptTypeContext)>::value>>
    //     : std::true_type {};

    //     template<typename T>
    //     constexpr bool has_user_defined_context_v = has_user_defined_context<T>::value;
    // }

    // template<typename T>
    // const TypeContext* autoTypeContext() {
    //     using namespace detail;

    //     if(std::is_same<T, bool>::value) {
    //         return &CUBS_BOOL_CONTEXT;
    //     } else if(std::is_same<T, int64_t>::value) {
    //         return &CUBS_INT_CONTEXT;
    //     } else if(std::is_same<T, double>::value) {
    //         return &CUBS_FLOAT_CONTEXT;
    //     } else if(has_user_defined_context_v<T>) {
    //         return T::scriptTypeContext();
    //     }
    // }

}