#include "array.hpp"
#include "../../doctest.h"

using cubs::Array;

TEST_CASE("jerpo") {
    Array<bool> yer;
}

TEST_CASE("nested") {
    Array<Array<bool>> yer;
}