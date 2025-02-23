#include "type_resolution_info.h"
#include "../parse/tokenizer.h"
#include "../../primitives/context.h"
#include "../../util/panic.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../util/unreachable.h"
#include <stdio.h>
#include <assert.h>

const CubsStringSlice boolTypeName = {.str = "bool", .len = 4};
const CubsStringSlice intTypeName = {.str = "int", .len = 3};
const CubsStringSlice floatTypeName = {.str = "float", .len = 5};
const CubsStringSlice stringTypeName = {.str = "string", .len = 6};
const CubsStringSlice charTypeName = {.str = "char", .len = 4};

void cubs_type_resolution_info_deinit(TypeResolutionInfo *self)
{
}

TypeResolutionInfo cubs_parse_type_resolution_info(TokenIter *iter)
{
    TypeResolutionInfo self = {0};

    const Token startToken = iter->current;
    switch(startToken.tag) {
        case BOOL_KEYWORD: {
            self.tag = TypeInfoBool;
        } break;
        case INT_KEYWORD: {
            self.tag = TypeInfoInt;
        } break;
        case FLOAT_KEYWORD: {
            self.tag = TypeInfoFloat;
        } break;
        case STRING_KEYWORD: {
            self.tag = TypeInfoString;
        } break;
        case CHAR_KEYWORD: {
            self.tag = TypeInfoChar;
        } break;
        case IDENTIFIER: {
            self.tag = TypeInfoStruct;
            self.value.structType = (struct TypeInfoStructData){.typeName = iter->current.value.identifier};
        } break;
        default: {
            fprintf(stderr, "Expected type. Found %d\n", startToken.tag);
            cubs_panic("Unexpected token encountered");
        }
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
        case TypeInfoReference: {
            if(self->value.reference.isMutable) {
                return &CUBS_MUT_REF_CONTEXT;
            } else {
                return &CUBS_CONST_REF_CONTEXT;
            }
        } 
        case TypeInfoStruct: {
            const CubsTypeContext* foundContext = cubs_program_find_type_context(program, self->value.structType.typeName);
            assert(foundContext != NULL);
            return foundContext;
        }
        default: {
            unreachable();
        }
    }
}

// TypeResolutionInfo cubs_type_resolution_info_from_context(const struct CubsTypeContext* context) {
//     TypeResolutionInfo self = {0};
//     self.knownContext = context;
//     const CubsStringSlice typeName = {.str = context->name, .len = context->nameLength};
//     self.typeName = typeName;
//     return self;
// }