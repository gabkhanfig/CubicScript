#include "script_value.h"
#include "../util/panic.h"
#include "../util/unreachable.h"
#include "string/string.h"
#include "array/array.h"
#include "map/map.h"
#include "set/set.h"

_Static_assert(sizeof(size_t) == sizeof(void*), "CubicScript requires a system with non-segmented addressing");
_Static_assert(sizeof(void*) == 8, "CubicScript is not compatible with non-64 bit architectures");

void cubs_class_opaque_deinit(void *self)
{
}

bool cubs_class_opaque_eql(const void *self, const void *other)
{
    return false;
}

size_t cubs_class_opaque_hash(const void *self)
{
    return 0;
}

void cubs_raw_value_deinit(CubsRawValue *self, CubsValueTag tag)
{
    switch(tag) {
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

void cubs_void_value_deinit(void *value, CubsValueTag tag)
{
    switch(tag) {
        case cubsValueTagBool: break;
        case cubsValueTagInt: break;
        case cubsValueTagFloat: break;
        case cubsValueTagConstRef: break;
        case cubsValueTagMutRef: break;
        case cubsValueTagInterfaceRef: break;
        case cubsValueTagFunctionPtr: break;
        case cubsValueTagString: 
            cubs_string_deinit((CubsString*)value);
            break;
        case cubsValueTagArray:
            cubs_array_deinit((CubsArray*)value);
            break;
        case cubsValueTagSet:
            cubs_set_deinit((CubsSet*)value);
            break;
        case cubsValueTagMap:
            cubs_map_deinit((CubsMap*)value);
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

size_t cubs_size_of_tagged_type(CubsValueTag tag)
{
    switch(tag) {
        case cubsValueTagBool: return sizeof(bool);
        case cubsValueTagInt: return sizeof(int64_t);
        case cubsValueTagFloat: return sizeof(double);
        case cubsValueTagString: return sizeof(CubsString);
        case cubsValueTagArray: return sizeof(CubsArray);
        case cubsValueTagSet: return sizeof(CubsSet);
        case cubsValueTagMap: return sizeof(CubsMap);
        case cubsValueTagOption: return sizeof(CubsOption);
        case cubsValueTagResult: return sizeof(CubsResult);
        //case cubsValueTag: return sizeof();
        //case cubsValueTag: return sizeof();
        default: {
            #if _DEBUG
            cubs_panic("what the heck");
            #else
            unreachable();
            #endif
        }
    }

}
