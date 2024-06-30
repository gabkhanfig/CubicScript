#include "hash.h"
#include "unreachable.h"
#include "panic.h"
#include <stdint.h>
#include "../primitives/string/string.h"
#include <time.h>
#include "../sync/mutex.h"
#include <stdlib.h>
#include "../sync/atomic.h"

typedef struct {
    /// `0` is used as an invalid seed. This makes it easy to check if it has been set or not pseudo-randomly,
    /// since it only takes a single atomic load to check.
    volatile size_t seed;
    CubsMutex mutex;
} AtomicSeedData;

/// Aligned for cache line
_Alignas(64) AtomicSeedData ATOMIC_SEED = {0};

size_t cubs_hash_seed()
{
    const size_t currentSeed = cubs_atomic_load_64(&ATOMIC_SEED.seed);
    if(currentSeed != 0) {
        return currentSeed;
    }

    // Once lock
    while(true) {
        // Attempt to lock the mutex
        if(!cubs_mutex_try_lock(&ATOMIC_SEED.mutex)) {
                // If unsuccessful to lock, check if the seed was set by another thread
                const size_t currentSeed = cubs_atomic_load_64(&ATOMIC_SEED.seed);
                // If was set by another thread, use it
                if(currentSeed != 0) {
                    return currentSeed;
                }
                // Otherwise try again
                continue;
        }

        // TODO maybe generate a crytpographically secure hash seed?

        _Static_assert(RAND_MAX >= 255, "random number from c stdlib must generate at least 8 random bits");

        srand(time(NULL));
        size_t r = 0;
        while(r == 0) { // Ensure's the seed is never 0.
            /// Extract 8 bits at a time
            for(int i = 0; i < sizeof(size_t); i++) {
                const unsigned int randValue = (unsigned int)rand();
                r = (r << sizeof(size_t)) + (randValue % 255);
            }
        }

        cubs_atomic_store_64(&ATOMIC_SEED.seed, r);
        cubs_mutex_unlock(&ATOMIC_SEED.mutex);

        return r;
    }
}

static void combineHash(size_t* lhs, size_t rhs) {
    // c++ boost hash combine for 64 bit
    *lhs = rhs + 0x517cc1b727220a95ULL + ((*lhs) & ~(0xFC00000000000000ULL)) + ((*lhs) >> 2);
}

// TODO other primitives
size_t cubs_compute_hash(const CubsRawValue *value, CubsValueTag tag)
{
    size_t h = cubs_hash_seed();
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
    return h;
}