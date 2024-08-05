#include "reference.h"
#include <assert.h>
#include "../primitives_context.h"

bool cubs_const_ref_eql(const CubsConstRef *self, const CubsConstRef *other)
{
    assert(self->context == other->context);
    assert(self->context->eql != NULL);
    return self->context->eql(self->ref, other->ref);
}

bool cubs_const_ref_eql_value(const CubsConstRef* self, const void* other) 
{
    assert(other != NULL);
    assert(self->context->eql != NULL);
    return self->context->eql(self->ref, other);
}

size_t cubs_const_ref_hash(const CubsConstRef *self)
{
    assert(self->context->hash != NULL);
    return self->context->hash(self->ref);
}

bool cubs_mut_ref_eql(const CubsMutRef *self, const CubsMutRef *other)
{
    assert(self->context == other->context);
    assert(self->context->eql != NULL);
    return self->context->eql(self->ref, other->ref);
}

bool cubs_mut_ref_eql_value(const CubsMutRef *self, const void *other)
{
    assert(other != NULL);
    assert(self->context->eql != NULL);
    return self->context->eql(self->ref, other);
}

size_t cubs_mut_ref_hash(const CubsMutRef *self)
{
    assert(self->context->hash != NULL);
    return self->context->hash(self->ref);
}
