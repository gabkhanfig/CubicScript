#include "type_resolution_info.h"
#include "../parse/tokenizer.h"
#include "../../primitives/context.h"
#include "../../util/panic.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../util/unreachable.h"
#include "../../platform/mem.h"
#include <stdio.h>
#include <assert.h>

const CubsStringSlice boolTypeName = {.str = "bool", .len = 4};
const CubsStringSlice intTypeName = {.str = "int", .len = 3};
const CubsStringSlice floatTypeName = {.str = "float", .len = 5};
const CubsStringSlice stringTypeName = {.str = "string", .len = 6};
const CubsStringSlice charTypeName = {.str = "char", .len = 4};

void cubs_type_resolution_info_deinit(TypeResolutionInfo *self)
{
    switch(self->tag) {
        case TypeInfoReference: {
            TypeResolutionInfo* childType = self->value.reference.child;
            cubs_type_resolution_info_deinit(childType);
            FREE_TYPE(TypeResolutionInfo, childType);
        } break;
        case TypeInfoUnique: {
            TypeResolutionInfo* childType = self->value.unique.child;
            cubs_type_resolution_info_deinit(childType);
            FREE_TYPE(TypeResolutionInfo, childType);
        } break;
        case TypeInfoShared: {
            TypeResolutionInfo* childType = self->value.shared.child;
            cubs_type_resolution_info_deinit(childType);
            FREE_TYPE(TypeResolutionInfo, childType);
        } break;
        case TypeInfoWeak: {
            TypeResolutionInfo* childType = self->value.weak.child;
            cubs_type_resolution_info_deinit(childType);
            FREE_TYPE(TypeResolutionInfo, childType);
        } break;
        default: {}
    }
}

TypeResolutionInfo cubs_type_resolution_info_clone(const TypeResolutionInfo *self)
{
    switch(self->tag) {
        case TypeInfoUnknown:
        case TypeInfoBool:
        case TypeInfoInt:
        case TypeInfoFloat:
        case TypeInfoChar:
        case TypeInfoString:
        case TypeInfoStruct: {
            return *self;
        } break;
        case TypeInfoReference: {
            TypeResolutionInfo* child = MALLOC_TYPE(TypeResolutionInfo);
            *child = cubs_type_resolution_info_clone(self->value.reference.child);

            const TypeResolutionInfo clone = {
                .tag = TypeInfoReference,
                .value.reference = (struct TypeInfoReferenceData){
                    .isMutable = self->value.reference.isMutable,
                    .child = child,    
                }
            };
            return clone;
        } break;
        default: {
            unreachable();
        }
    }
}

/// Attempts to parse a type without any extra modifiers.
/// For example:
/// - `int`
/// - `float`
/// - `string`
/// - Struct names
///
/// Ignores any modifiers on the type such as `&`, `[]`, etc.
/// @return True if was successfully parsed, otherwise false
static bool try_parse_normal_type(TypeResolutionInfo* out, const TokenIter* iter) {
    TypeResolutionInfo retVal = {0};

    const Token startToken = iter->current;
    switch(startToken.tag) {
        case BOOL_KEYWORD: {
            retVal.tag = TypeInfoBool;
        } break;
        case INT_KEYWORD: {
            retVal.tag = TypeInfoInt;
        } break;
        case FLOAT_KEYWORD: {
            retVal.tag = TypeInfoFloat;
        } break;
        case STRING_KEYWORD: {
            retVal.tag = TypeInfoString;
        } break;
        case CHAR_KEYWORD: {
            retVal.tag = TypeInfoChar;
        } break;
        case IDENTIFIER: {
            retVal.tag = TypeInfoStruct;
            retVal.value.structType = (struct TypeInfoStructData){.typeName = iter->current.value.identifier};
        } break;
        default: {
            return false;
        }
    }

    *out = retVal;
    return true;
}

static bool try_parse_sync_type(TypeResolutionInfo* out, TokenIter* iter) {
    TypeResolutionInfo* child = MALLOC_TYPE(TypeResolutionInfo);
    const TokenType syncType = iter->current.tag;

    (void)cubs_token_iter_next(iter);
    bool success = try_parse_normal_type(child, iter);
    if(!success) {
        FREE_TYPE(TypeResolutionInfo, child);
        return false;
    }

    switch(syncType) {
        case UNIQUE_KEYWORD: {
            out->tag = TypeInfoUnique;
            out->value.unique = (TypeInfoUniqueData){.child = child};
        } break;
        case SHARED_KEYWORD: {
            out->tag = TypeInfoShared;
            out->value.shared = (TypeInfoSharedData){.child = child};
        } break;
        case WEAK_KEYWORD: {
            out->tag = TypeInfoWeak;
            out->value.weak = (TypeInfoWeakData){.child = child};
        } break;
        default: unreachable();
    }

    return true;
}

TypeResolutionInfo cubs_parse_type_resolution_info(TokenIter *iter)
{
    TypeResolutionInfo self = {0};
    if(try_parse_normal_type(&self, iter)) {
        (void)cubs_token_iter_next(iter);
        return self;
    }

    const Token startToken = iter->current;
    if(startToken.tag == REFERENCE_SYMBOL) {
        struct TypeInfoReferenceData referenceData = {.isMutable = false, .child = NULL};

        (void)cubs_token_iter_next(iter);
        if(iter->current.tag == MUT_KEYWORD) {
            referenceData.isMutable = true;
            (void)cubs_token_iter_next(iter);
        }
        
        TypeResolutionInfo childType = {0};
        bool success = false;
        switch(iter->current.tag) {
            case UNIQUE_KEYWORD: case SHARED_KEYWORD: case WEAK_KEYWORD: {
                success = try_parse_sync_type(&childType, iter);
            } break;
            default: {
                success = try_parse_normal_type(&childType, iter);
            }
        }
        assert(success);
        referenceData.child = MALLOC_TYPE(TypeResolutionInfo);
        *referenceData.child = childType;

        self.tag = TypeInfoReference;
        self.value.reference = referenceData;
    } else {
        fprintf(stderr, "Expected type. Found %d\n", startToken.tag);
        cubs_panic("Unexpected token encountered");
    }

    (void)cubs_token_iter_next(iter);
    return self;
}

const CubsTypeContext *cubs_type_resolution_info_get_context(const TypeResolutionInfo *self, const CubsProgram *program)
{
    assert(self->tag != TypeInfoUnknown);

    switch(self->tag) {
        case TypeInfoBool: return &CUBS_BOOL_CONTEXT;
        case TypeInfoInt: return &CUBS_INT_CONTEXT;
        case TypeInfoFloat: return &CUBS_FLOAT_CONTEXT;
        case TypeInfoChar: return &CUBS_CHAR_CONTEXT;
        case TypeInfoString: return &CUBS_STRING_CONTEXT;
        case TypeInfoStruct: {
            const CubsTypeContext* foundContext = cubs_program_find_type_context(program, self->value.structType.typeName);
            assert(foundContext != NULL);
            return foundContext;
        }
        case TypeInfoReference: {
            if(self->value.reference.isMutable) {
                return &CUBS_MUT_REF_CONTEXT;
            } else {
                return &CUBS_CONST_REF_CONTEXT;
            }
        } 
        case TypeInfoUnique: {
            return &CUBS_UNIQUE_CONTEXT;
        } break;
        case TypeInfoShared: {
            return &CUBS_SHARED_CONTEXT;
        } break;
        case TypeInfoWeak: {
            return &CUBS_WEAK_CONTEXT;
        } break;
        case TypeInfoKnownContext: {
            return self->value.knownContext;
        }
        default: {
            unreachable();
        }
    }
}
