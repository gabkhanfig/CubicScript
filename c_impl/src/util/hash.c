#include "hash.h"
#include "unreachable.h"
#include "panic.h"
#include <stdint.h>
#include "../primitives/string.h"

const size_t TEST_SEED_VALUE = 0x4857372859619FAULL;

static void combineHash(size_t* lhs, size_t rhs) {
    // c++ boost hash combine for 64 bit
    *lhs = rhs + 0x517cc1b727220a95ULL + ((*lhs) & ~(0xFC00000000000000ULL)) + ((*lhs) >> 2);
}

// TODO other primitives
size_t cubs_compute_hash(const CubsRawValue *value, CubsValueTag tag)
{
    size_t h = TEST_SEED_VALUE;
    switch(tag) {
        case cubsValueTagBool: {
            combineHash(&h, *((const size_t*)value));
        } break;
        case cubsValueTagInt: {
            combineHash(&h, *((const size_t*)value));
        } break;
        case cubsValueTagFloat: {
            // Floats are goofy so just cast to an int and go from there
            int64_t floatAsInt = (int64_t)(value->floatNum);
            combineHash(&h, *((const size_t*)&floatAsInt));
        } break;
        case cubsValueTagString: {
            combineHash(&h, cubs_string_hash(&value->string));
        } break;
        default: {
            cubs_panic("Hash type not yet implemented");
        } break;
    }
}