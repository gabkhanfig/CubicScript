#pragma once

#include "script_value.hpp"

namespace cubs {
    template<typename T>
    const TypeContext* autoTypeContext();
}

#include <type_traits>
#include "array/array.hpp"

template<typename T, typename = void>
struct _has_user_defined_context : std::false_type {};

template<typename T>
struct _has_user_defined_context<T, std::enable_if_t<std::is_invocable_r<const cubs::TypeContext*, decltype(T::scriptTypeContext)>::value>>
: std::true_type {};

template<typename T>
constexpr bool _has_user_defined_context_v = _has_user_defined_context<T>::value;

template <class T, template <class...> class Template>
struct _is_specialization : std::false_type {};

template <template <class...> class Template, class... Args>
struct _is_specialization<Template<Args...>, Template> : std::true_type {};

namespace cubs {
    template<typename T>
    inline const TypeContext* autoTypeContext() {
        if constexpr (std::is_same<T, bool>::value) {
            return &CUBS_BOOL_CONTEXT;
        } else if constexpr (std::is_same<T, int64_t>::value) {
            return &CUBS_INT_CONTEXT;
        } else if constexpr (std::is_same<T, double>::value) {
            return &CUBS_FLOAT_CONTEXT;
        } else if constexpr (_has_user_defined_context_v<T>) {
            return T::scriptTypeContext();
        }
    }
} // namespace cubs