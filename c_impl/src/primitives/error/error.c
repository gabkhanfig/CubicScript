#include "error.h"
#include "../primitives_context.h"
#include "../../util/mem.h"
#include <assert.h>
#include <string.h>
#include "../string/string.h"
#include "../../util/hash.h"

// CubsError cubs_error_init_primitive(CubsString name, void *optionalMetadata, CubsValueTag optionalTag)
// {
//     if(optionalMetadata == NULL) {
//         return cubs_error_init_user_class(name, NULL, NULL);
//     } else {
//         return cubs_error_init_user_class(name, optionalMetadata, cubs_primitive_context_for_tag(optionalTag));
//     }
// }

CubsError cubs_error_init(CubsString name, void *optionalMetadata, const CubsTypeContext *optionalContext)
{
    if(optionalMetadata == NULL) {
        const CubsError err = {.name = name, .metadata = NULL, .context = NULL};
        return err;
    } else {
        assert(optionalContext != NULL);
        void* mem = cubs_malloc(optionalContext->sizeOfType, _Alignof(size_t));
        memcpy(mem, optionalMetadata, optionalContext->sizeOfType);
        const CubsError err = {.name = name, .metadata = mem, .context = optionalContext};
        return err;
    }
}

void cubs_error_deinit(CubsError *self)
{
    cubs_string_deinit(&self->name);

    if(self->metadata == NULL) {
        return;
    }

    cubs_free(self->metadata, self->context->sizeOfType, _Alignof(size_t));
    self->metadata = NULL;
}

CubsError cubs_error_clone(const CubsError *self)
{
    if(self->metadata == NULL) {
        const CubsError err = {.name = cubs_string_clone(&self->name), .metadata = NULL, .context = self->context};
        return err;
    } else {
        assert(self->context != NULL);
        assert(self->context->clone != NULL);
        
        void* mem = cubs_malloc(self->context->sizeOfType, _Alignof(size_t));
        self->context->clone(mem, self->metadata);
        const CubsError err = {.name = cubs_string_clone(&self->name), .metadata = mem, .context = self->context};
        return err;
    }
}

void cubs_error_take_metadata(void *out, CubsError *self)
{
    assert(self->context != NULL);
    assert(self->metadata != NULL);

    memcpy(out, self->metadata, self->context->sizeOfType);
    cubs_free(self->metadata, self->context->sizeOfType, _Alignof(size_t));
    self->metadata = NULL;
}

bool cubs_error_eql(const CubsError *self, const CubsError *other)
{
    assert(self->context == other->context);

    if(!cubs_string_eql(&self->name, &other->name)) {
        return false;
    }

    if(self->context == NULL) {
        return true;
    }

    if(self->metadata == NULL) {
        return other->metadata == NULL;
    } 
    else if(other->metadata == NULL) {
        return false; // self metadata is non-null, therefore they cannot be equal
    }
    // both are non null
    return self->context->eql(self->metadata, other->metadata);
}

size_t cubs_error_hash(const CubsError *self)
{
    size_t h = cubs_string_hash(&self->name); // Already seeded
    
    if(self->metadata != NULL) {
        assert(self->context != NULL);
        assert(self->context->hash != NULL);

        h = cubs_combine_hash(h, self->context->hash(self->metadata));
    }
    
    return h;
}
