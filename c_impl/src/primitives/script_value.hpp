#pragma once

namespace cubs {
    namespace detail {
        #include "script_value.h"
        #include "primitives_context.h"
        #include <type_traits>
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

    /// See `autoTypeContext<T>()` to automatically create one for a type.
    using TypeContext = detail::CubsTypeContext;

    namespace detail {
        template<typename T, typename = void>
        struct has_user_defined_context : std::false_type {};

        template<typename T>
        struct has_user_defined_context<T, std::enable_if_t<std::is_invocable_r<const TypeContext*, decltype(T::scriptTypeContext)>::value>>
        : std::true_type {};

        template<typename T>
        constexpr bool has_user_defined_context_v = has_user_defined_context<T>::value;
    }

    template<typename T>
    const TypeContext* autoTypeContext() {
        using namespace detail;

        if(std::is_same<T, bool>::value) {
            return &CUBS_BOOL_CONTEXT;
        } else if(std::is_same<T, int64_t>::value) {
            return &CUBS_INT_CONTEXT;
        } else if(std::is_same<T, double>::value) {
            return &CUBS_FLOAT_CONTEXT;
        } else if(has_user_defined_context_v<T>) {
            return T::scriptTypeContext();
        }
    }

}