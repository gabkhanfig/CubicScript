#include "script_value.h"
#include "../util/panic.h"
#include "../util/unreachable.h"
#include "string.h"
#include "array.h"
#include "map.h"
#include "set/set.h"

void cubs_raw_value_deinit(CubsRawValue *self, CubsValueTag tag)
{
    switch(tag) {
        case cubsValueTagNone: break;
        case cubsValueTagBool: break;
        case cubsValueTagInt: break;
        case cubsValueTagFloat: break;
        case cubsValueTagConstRef: break;
        case cubsValueTagMutRef: break;
        case cubsValueTagInterfaceRef: break;
        case cubsValueTagFunctionPtr: break;
        case cubsValueTagString: 
            cubs_string_deinit(&self->string);
            break;
        case cubsValueTagArray:
            cubs_array_deinit(&self->arr);
            break;
        case cubsValueTagSet:
            cubs_set_deinit(&self->set);
            break;
        case cubsValueTagMap:
            cubs_map_deinit(&self->map);
            break;
        default:
            unreachable();
    }
}

CubsRawValue cubs_raw_value_clone(const CubsRawValue *self, CubsValueTag tag)
{
    CubsRawValue temp;
    switch(tag) {
        case cubsValueTagBool:
            temp.boolean = self->boolean;
            break;
        case cubsValueTagInt: 
            temp.intNum = self->intNum;
            break;
        case cubsValueTagFloat: 
            temp.floatNum = self->floatNum;
            break;
        case cubsValueTagMutRef: break;
        case cubsValueTagInterfaceRef: break;
        case cubsValueTagFunctionPtr: break;
        case cubsValueTagString: 
            temp.string = cubs_string_clone(&self->string);
            break;
        default:
            unreachable();
    }
}

bool cubs_raw_value_eql(const CubsRawValue *self, const CubsRawValue *other, CubsValueTag tag)
{
    switch(tag) {
        case cubsValueTagBool:
            return self->boolean == other->boolean;
        case cubsValueTagInt: 
            return self->intNum == other->intNum;
        case cubsValueTagFloat: 
            return self->floatNum == other->floatNum;
        case cubsValueTagString:
            return cubs_string_eql(&self->string, &other->string);
        default:
            unreachable();
    }
}

void cubs_tagged_value_deinit(CubsTaggedValue *self)
{
    cubs_raw_value_deinit(&self->value, self->tag);
}

CubsTaggedValue cubs_tagged_value_clone(const CubsTaggedValue *self)
{
    const CubsRawValue value = cubs_raw_value_clone(&self->value, self->tag);
    CubsTaggedValue tagged;
    tagged.tag = self->tag;
    tagged.value = value;
    return tagged;
}

bool cubs_tagged_value_eql(const CubsTaggedValue *self, const CubsTaggedValue *other)
{   
    if(self->tag != other->tag) {
        return false;
    }
    return cubs_raw_value_eql(&self->value, &other->value, self->tag);
}
