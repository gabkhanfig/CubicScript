#pragma once

#include "../context.hpp"
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

        static const TypeContext* scriptTypeContext();

    private:
        detail::CubsArray arr;
    };
}

template<typename T>
inline const cubs::TypeContext* cubs::Array<T>::scriptTypeContext() {
    return &detail::CUBS_ARRAY_CONTEXT;
}

template<typename T>
inline cubs::Array<T>::Array() {
    detail::CubsArray a;
    a.len = 0;
    a.buf = nullptr;
    a.capacity = 0;
    a.context = autoTypeContext<T>();
    this->arr = a;
}

// template<typename T>
// inline const cubs::TypeContext* cubs::Array<T>::scriptTypeContext() {
//     return &detail::CUBS_ARRAY_CONTEXT;
// }