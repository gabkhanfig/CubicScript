#pragma once

namespace cubs {
    namespace detail {
        #include "script_value.h"
        #include "primitives_context.h"
    }
    /// See `autoTypeContext<T>()` to automatically create one for a type.
    using TypeContext = detail::CubsTypeContext;

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