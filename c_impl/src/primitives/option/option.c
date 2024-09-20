#include "option.h"
#include <assert.h>
#include "../../platform/mem.h"
#include <string.h>
#include "../primitives_context.h"
#include "../../util/hash.h"

// CubsOption cubs_option_init_primitive(CubsValueTag tag, void* optionalValue)
// {  
//     assert(tag != cubsValueTagUserClass && "Use cubs_option_init_user_class for user defined classes");
//     return cubs_option_init_user_class(cubs_primitive_context_for_tag(tag), optionalValue);
// }

CubsOption cubs_option_init(const CubsTypeContext *context, void *optionalValue)
{
    assert(context != NULL);
    if(optionalValue == NULL) {
        const CubsOption option = {._metadata = {0}, .isSome = false, .context = context};
        return option;
    } else {
        CubsOption option = {._metadata = {0}, .isSome = true, .context = context};
        if(context->sizeOfType <= sizeof(option._metadata)) {
            memcpy((void*)&option._metadata, optionalValue, context->sizeOfType);
        } else {
            void* metadataMem = cubs_malloc(context->sizeOfType, _Alignof(size_t));
            memcpy(metadataMem, optionalValue, context->sizeOfType);
            option._metadata[0] = metadataMem;
        }
        return option;
    }
}

void cubs_option_deinit(CubsOption *self)
{
    if(!self->isSome) {
        return;
    }

    if(self->context->destructor.func.externC != NULL) {
        if(self->context->sizeOfType <= sizeof(self->_metadata)) {
            cubs_context_fast_deinit(&self->_metadata, self->context);
        } else {
            cubs_context_fast_deinit(self->_metadata[0], self->context);
            cubs_free(self->_metadata[0], self->context->sizeOfType, _Alignof(size_t));
        }
    }

    memset((void*)self, 0, sizeof(CubsOption));
}

CubsOption cubs_option_clone(const CubsOption *self)
{
    assert(self->context->clone.func.externC != NULL);

    CubsOption out = {._metadata = {0}, .isSome = self->isSome, .context = self->context};
    if(!self->isSome) {
        return out;
    }

    if(self->context->sizeOfType <= sizeof(self->_metadata)) {
        cubs_context_fast_clone((void*)&out._metadata, cubs_option_get(self), self->context);
    } else {
        void* metadataMem = cubs_malloc(self->context->sizeOfType, _Alignof(size_t));
        cubs_context_fast_clone(metadataMem, cubs_option_get(self), self->context);
        out._metadata[0] = metadataMem;
    }
    return out;
}

const void *cubs_option_get(const CubsOption *self)
{
    assert(self->isSome);

    if(self->context->sizeOfType <= sizeof(self->_metadata)) {
        return &self->_metadata;
    } else {
        return self->_metadata[0];
    }
}

void *cubs_option_get_mut(CubsOption *self)
{
    assert(self->isSome);

    if(self->context->sizeOfType <= sizeof(self->_metadata)) {
        return &self->_metadata;
    } else {
        return self->_metadata[0];
    }
}

void cubs_option_take(void *out, CubsOption *self)
{
    assert(self->isSome);

    if(self->context->sizeOfType <= sizeof(self->_metadata)) {
        memcpy(out, &self->_metadata, self->context->sizeOfType);
    } else {
        memcpy(out, self->_metadata[0], self->context->sizeOfType);
        cubs_free(self->_metadata[0], self->context->sizeOfType, _Alignof(size_t));
    }
    memset((void*)self, 0, sizeof(CubsOption));
}

bool cubs_option_eql(const CubsOption *self, const CubsOption *other)
{
    assert(self->context->eql.func.externC == other->context->eql.func.externC);
    assert(self->context->eql.func.externC != NULL);
    assert(self->context->sizeOfType == other->context->sizeOfType);

    if(self->isSome != other->isSome) {
        return false;
    }

    if(self->isSome) {
        return cubs_context_fast_eql(cubs_option_get(self), cubs_option_get(other), self->context);
    } else {
        return true; // both are null
    }
    
}

size_t cubs_option_hash(const CubsOption *self)
{
    assert(self->context->hash.func.externC != NULL);

    if(!self->isSome) {
        return 0;
    }

    const size_t globalHashSeed = cubs_hash_seed();
    const size_t hashed = cubs_context_fast_hash(cubs_option_get(self), self->context);
    return cubs_combine_hash(globalHashSeed, hashed);
}
