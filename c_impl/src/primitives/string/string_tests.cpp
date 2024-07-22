#include "string.hpp"
#include "../../doctest.h"

using cubs::String;

TEST_CASE("default constructor") {
    String s;
    CHECK_EQ(s.len(), 0);
}

TEST_CASE("string view constructor") {
    String s = std::string_view("hello world!");
    CHECK_EQ(s, std::string_view("hello world!"));
}

TEST_CASE("const char* constructor") {
    String s = "hello world!";
    CHECK_EQ(s, "hello world!");
}