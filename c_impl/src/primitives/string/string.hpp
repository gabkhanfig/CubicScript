#pragma once

#include <string_view> 
#include "../script_value.hpp"
#include <assert.h>
#include <iostream>

extern "C" {  
    #include "string.h"
}

namespace cubs {
    namespace detail {
    }

    class String {
    public:

        using string_view = std::string_view;
        using int64_t = std::int64_t;

        enum class Error : int {
            None = newStringErrorNone,
            InvalidUtf8 = newStringErrorInvalidUtf8,
            IndexOutOfBounds = newStringErrorIndexOutOfBounds,
            ParseBool = newStringErrorParseBool,
            ParseInt = newStringErrorParseInt,
            ParseFloat = newStringErrorParseFloat,
        };

        constexpr static size_t npos = CUBS_STRING_N_POS;

        String() : string{0} {}

        String(string_view str) {
            CubsStringSlice slice;
            slice.str = str.data();
            slice.len = str.size();
            this->string = cubs_string_init_unchecked(slice);
        }

        String(const char* str) {
            const string_view sv{str};         
            CubsStringSlice slice;
            slice.str = sv.data();
            slice.len = sv.size();
            this->string = cubs_string_init_unchecked(slice);
        }

        String(const String& other) {
            this->string = cubs_string_clone(&other.string);
        }

        String(String&& other) noexcept {
            this->string = other.string;
            other.string = {0};
        }

        ~String() noexcept {
            cubs_string_deinit(&this->string);
        }

        static const TypeContext* scriptTypeContext() {
            return &CUBS_STRING_CONTEXT;
        }

        size_t len() const {
            return this->string.len;
        }

        String& operator= (const String& other) {
            cubs_string_deinit(&this->string);
            this->string = cubs_string_clone(&other.string);
        }

        String& operator= (String&& other) {
            cubs_string_deinit(&this->string);
            this->string = other.string;
            other.string = {0};
        }

        [[nodiscard]] string_view asStringView() const {
            const CubsStringSlice slice = cubs_string_as_slice(&this->string);
            const string_view view(slice.str, slice.len);
            return view;
        }

        [[nodiscard]] bool operator==(const String& other) const {
            return cubs_string_eql(&this->string, &other.string);
        }

        [[nodiscard]] bool operator==(string_view view) const { 
            CubsStringSlice slice;
            slice.str = view.data();
            slice.len = view.size();
            return cubs_string_eql_slice(&this->string, slice);
        }

        [[nodiscard]] bool operator==(const char* str) const {
            const string_view sv{str};
            return *this == sv;
        }

        [[nodiscard]] bool operator<(const String& other) const {
            return cubs_string_cmp(&this->string, &other.string) == cubsOrderingLess;
        }

        [[nodiscard]] bool operator>(const String& other) const {
            return cubs_string_cmp(&this->string, &other.string) == cubsOrderingGreater;
        }

        [[nodiscard]] bool operator<=(const String& other) const {
            const CubsOrdering result = cubs_string_cmp(&this->string, &other.string);
            return (result == cubsOrderingLess) || (result == cubsOrderingEqual);
        }

        [[nodiscard]] bool operator>=(const String& other) const {
            const bool result = cubs_string_cmp(&this->string, &other.string);
            return (result == cubsOrderingGreater) || (result == cubsOrderingEqual);
        }

        [[nodiscard]] size_t hash() const {
            return cubs_string_hash(&this->string);
        }

        [[nodiscard]] size_t find(const String& other, size_t startIndex = 0) const {
            const CubsStringSlice slice = cubs_string_as_slice(&other.string);
            return cubs_string_find(&this->string, slice, startIndex);
        }

        [[nodiscard]] size_t find(string_view view, size_t startIndex = 0) const {   
            CubsStringSlice slice;
            slice.str = view.data();
            slice.len = view.size();
            return cubs_string_find(&this->string, slice, startIndex);
        }

        [[nodiscard]] size_t find(const char* str, size_t startIndex = 0) const {
            return this->find(string_view(str), startIndex);
        }

        [[nodiscard]] size_t rfind(const String& other, size_t startIndex) const {
            const CubsStringSlice slice = cubs_string_as_slice(&other.string);
            return cubs_string_rfind(&this->string, slice, startIndex);
        }

        [[nodiscard]] size_t rfind(string_view view, size_t startIndex) const {   
            CubsStringSlice slice;
            slice.str = view.data();
            slice.len = view.size();
            return cubs_string_rfind(&this->string, slice, startIndex);
        }

        [[nodiscard]] size_t rfind(const char* str, size_t startIndex) const {
            return this->rfind(string_view(str), startIndex);
        }

        [[nodiscard]] String operator+ (const String& other) const {
            String out;
            out.string = cubs_string_concat(&this->string, &other.string);
            return out;
        }

        [[nodiscard]] String operator+ (string_view view) const {
            String out;
            CubsStringSlice slice;
            slice.str = view.data();
            slice.len = view.size();
            out.string = cubs_string_concat_slice_unchecked(&this->string, slice);
            return out;
        }

        [[nodiscard]] String operator+ (const char* str) const {
            return *this + string_view(str);
        }

        [[nodiscard]] Error substr(String& out, size_t startInclusive, size_t endExclusive) const {
            const Error result = static_cast<Error>(cubs_string_substr(&out.string, &this->string, startInclusive, endExclusive));
            return result;
        }

        [[nodiscard]] static String fromBool(bool b) {
            String out;
            out.string = cubs_string_from_bool(b);
            return out;
        }

        [[nodiscard]] static String fromInt(int64_t b) {
            String out;
            out.string = cubs_string_from_int(b);
            return out;
        }

        [[nodiscard]] static String fromFloat(double b) {
            String out;
            out.string = cubs_string_from_float(b);
            return out;
        }

        [[nodiscard]] Error toBool(bool& out) const {
            const Error result = static_cast<Error>(cubs_string_to_bool(reinterpret_cast<bool*>(out), &this->string));
            return result;
        }

    private:
        CubsString string;
    };
}

namespace std {
    template <>
    struct hash<cubs::String> {
        size_t operator()(const cubs::String& str) const noexcept {
            return str.hash();
        }
    };
};

