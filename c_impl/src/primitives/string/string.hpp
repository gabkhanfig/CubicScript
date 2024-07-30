#pragma once

#include <string_view> 
#include "../script_value.hpp"
#include <assert.h>
#include <iostream>
#include "../context.hpp"

namespace cubs {
    namespace detail {
        #include "string.h"
    }

    class String {
    public:

        using string_view = std::string_view;
        using int64_t = std::int64_t;

        enum class Error : int {
            None = detail::newStringErrorNone,
            InvalidUtf8 = detail::newStringErrorInvalidUtf8,
            IndexOutOfBounds = detail::newStringErrorIndexOutOfBounds,
            ParseBool = detail::newStringErrorParseBool,
            ParseInt = detail::newStringErrorParseInt,
            ParseFloat = detail::newStringErrorParseFloat,
        };

        constexpr static size_t npos = detail::CUBS_STRING_N_POS;

        String() : string{0} {}

        String(string_view str) {
            detail::CubsStringSlice slice;
            slice.str = str.data();
            slice.len = str.size();
            this->string = detail::cubs_string_init_unchecked(slice);
        }

        String(const char* str) {
            const string_view sv{str};         
            detail::CubsStringSlice slice;
            slice.str = sv.data();
            slice.len = sv.size();
            this->string = detail::cubs_string_init_unchecked(slice);
        }

        String(const String& other) {
            this->string = detail::cubs_string_clone(&other.string);
        }

        String(String&& other) noexcept {
            this->string = other.string;
            other.string = {0};
        }

        ~String() noexcept {
            detail::cubs_string_deinit(&this->string);
        }

        static const TypeContext* scriptTypeContext() {
            return reinterpret_cast<const TypeContext*>(&CUBS_STRING_CONTEXT);
        }

        size_t len() const {
            return this->string.len;
        }

        String& operator= (const String& other) {
            detail::cubs_string_deinit(&this->string);
            this->string = detail::cubs_string_clone(&other.string);
        }

        String& operator= (String&& other) {
            detail::cubs_string_deinit(&this->string);
            this->string = other.string;
            other.string = {0};
        }

        [[nodiscard]] string_view asStringView() const {
            const detail::CubsStringSlice slice = detail::cubs_string_as_slice(&this->string);
            const string_view view(slice.str, slice.len);
            return view;
        }

        [[nodiscard]] const char* cstr() const {
            const detail::CubsStringSlice slice = detail::cubs_string_as_slice(&this->string);
            return slice.str;
        }

        friend std::ostream& operator << (std::ostream& os, const String& inString) {
            const std::string_view view = inString.asStringView();
			return os.write(view.data(), view.size());
		}

        [[nodiscard]] bool operator==(const String& other) const {
            return detail::cubs_string_eql(&this->string, &other.string);
        }

        [[nodiscard]] bool operator==(string_view view) const { 
            detail::CubsStringSlice slice;
            slice.str = view.data();
            slice.len = view.size();
            return detail::cubs_string_eql_slice(&this->string, slice);
        }

        [[nodiscard]] bool operator==(const char* str) const {
            const string_view sv{str};
            return *this == sv;
        }

        [[nodiscard]] bool operator<(const String& other) const {
            return detail::cubs_string_cmp(&this->string, &other.string) == detail::cubsOrderingLess;
        }

        [[nodiscard]] bool operator>(const String& other) const {
            return detail::cubs_string_cmp(&this->string, &other.string) == detail::cubsOrderingGreater;
        }

        [[nodiscard]] bool operator<=(const String& other) const {
            const detail::CubsOrdering result = detail::cubs_string_cmp(&this->string, &other.string);
            return (result == detail::cubsOrderingLess) || (result == detail::cubsOrderingEqual);
        }

        [[nodiscard]] bool operator>=(const String& other) const {
            const bool result = detail::cubs_string_cmp(&this->string, &other.string);
            return (result == detail::cubsOrderingGreater) || (result == detail::cubsOrderingEqual);
        }

        [[nodiscard]] size_t hash() const {
            return detail::cubs_string_hash(&this->string);
        }

        [[nodiscard]] size_t find(const String& other, size_t startIndex = 0) const {
            const detail::CubsStringSlice slice = detail::cubs_string_as_slice(&other.string);
            return detail::cubs_string_find(&this->string, slice, startIndex);
        }

        [[nodiscard]] size_t find(string_view view, size_t startIndex = 0) const {   
            detail::CubsStringSlice slice;
            slice.str = view.data();
            slice.len = view.size();
            return detail::cubs_string_find(&this->string, slice, startIndex);
        }

        [[nodiscard]] size_t find(const char* str, size_t startIndex = 0) const {
            return this->find(string_view(str), startIndex);
        }

        [[nodiscard]] size_t rfind(const String& other, size_t startIndex) const {
            const detail::CubsStringSlice slice = detail::cubs_string_as_slice(&other.string);
            return detail::cubs_string_rfind(&this->string, slice, startIndex);
        }

        [[nodiscard]] size_t rfind(string_view view, size_t startIndex) const {   
            detail::CubsStringSlice slice;
            slice.str = view.data();
            slice.len = view.size();
            return detail::cubs_string_rfind(&this->string, slice, startIndex);
        }

        [[nodiscard]] size_t rfind(const char* str, size_t startIndex) const {
            return this->rfind(string_view(str), startIndex);
        }

        [[nodiscard]] String operator+ (const String& other) const {
            String out;
            out.string = detail::cubs_string_concat(&this->string, &other.string);
            return out;
        }

        [[nodiscard]] String operator+ (string_view view) const {
            String out;
            detail::CubsStringSlice slice;
            slice.str = view.data();
            slice.len = view.size();
            out.string = detail::cubs_string_concat_slice_unchecked(&this->string, slice);
            return out;
        }

        [[nodiscard]] String operator+ (const char* str) const {
            return *this + string_view(str);
        }

        [[nodiscard]] Error substr(String& out, size_t startInclusive, size_t endExclusive) const {
            const Error result = static_cast<Error>(detail::cubs_string_substr(&out.string, &this->string, startInclusive, endExclusive));
            return result;
        }

        [[nodiscard]] static String fromBool(bool b) {
            String out;
            out.string = detail::cubs_string_from_bool(b);
            return out;
        }

        [[nodiscard]] static String fromInt(int64_t b) {
            String out;
            out.string = detail::cubs_string_from_int(b);
            return out;
        }

        [[nodiscard]] static String fromFloat(double b) {
            String out;
            out.string = detail::cubs_string_from_float(b);
            return out;
        }

        [[nodiscard]] Error toBool(bool& out) const {
            const Error result = static_cast<Error>(detail::cubs_string_to_bool(reinterpret_cast<bool*>(out), &this->string));
            return result;
        }

    private:
        detail::CubsString string;
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

