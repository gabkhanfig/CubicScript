#include "option.h"
#include <assert.h>
#include "../../util/global_allocator.h"
#include <string.h>
#include "../primitives_context.h"

CubsOption cubs_option_init_primitive(CubsValueTag tag, void* optionalValue)
{  
    assert(tag != cubsValueTagUserClass && "Use cubs_option_init_user_class for user defined classes");
    return cubs_option_init_user_class(cubs_primitive_context_for_tag(tag), optionalValue);
}

CubsOption cubs_option_init_user_class(const CubsStructContext *context, void *optionalValue)
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

    if(self->context->destructor != NULL) {
        if(self->context->sizeOfType <= sizeof(self->_metadata)) {
            self->context->destructor(&self->_metadata);
        } else {
            self->context->destructor(self->_metadata[0]);
            cubs_free(self->_metadata[0], self->context->sizeOfType, _Alignof(size_t));
        }
    }

    memset((void*)self, 0, sizeof(CubsOption));
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
