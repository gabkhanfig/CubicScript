#include "string_slice.h"
#include "../../util/hash.h"

bool cubs_string_slice_eql(CubsStringSlice lhs, CubsStringSlice rhs)
{
    if(lhs.len != rhs.len) {
        return false;
    }

    for(size_t i = 0; i < lhs.len; i++) {
        if(lhs.str[i] != rhs.str[i]) {
            return false;
        }
    }

    return true;
}

size_t cubs_string_slice_hash(CubsStringSlice self)
{
    return bytes_hash(self.str, self.len);
}
