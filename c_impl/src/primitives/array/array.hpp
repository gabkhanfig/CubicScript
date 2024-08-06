#pragma once

#include "../script_value.hpp"
#include <assert.h>
#include <cstdint>

namespace cubs {
    namespace detail {
        #include "array.h"
    }

    template<typename T>
    class Array {
    public:
        
        Array();

        ~Array() {
            detail::cubs_array_deinit(&this->arr);
        }

        static const TypeContext* scriptTypeContext() {
            return &detail::CUBS_ARRAY_CONTEXT;
        }

    private:
        detail::CubsArray arr;
    };
}

#include "../context.hpp"

template<typename T>
inline cubs::Array<T>::Array() {
    const detail::CubsArray a = {.len = 0, .buf = nullptr, .capacity = 0, .context = autoTypeContext<T>()};
    this->arr = a;
}

// template<typename T>
// inline const cubs::TypeContext* cubs::Array<T>::scriptTypeContext() {
//     return &detail::CUBS_ARRAY_CONTEXT;
// }