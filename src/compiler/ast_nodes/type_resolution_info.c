#include "type_resolution_info.h"
#include "../tokenizer.h"
#include "../../primitives/context.h"
#include "../../util/panic.h"
#include <stdio.h>

const CubsStringSlice boolTypeName = {.str = "bool", .len = 4};
const CubsStringSlice intTypeName = {.str = "int", .len = 3};
const CubsStringSlice floatTypeName = {.str = "float", .len = 5};
const CubsStringSlice stringTypeName = {.str = "string", .len = 6};
const CubsStringSlice charTypeName = {.str = "char", .len = 4};

TypeResolutionInfo cubs_parse_type_resolution_info(TokenIter *iter)
{
    TypeResolutionInfo self = {0};

    const Token startToken = iter->current;
    switch(startToken.tag) {
        case BOOL_KEYWORD: {
            self.typeName = boolTypeName;
            self.knownContext = &CUBS_BOOL_CONTEXT;
        }
        case INT_KEYWORD: {
            self.typeName = intTypeName;
            self.knownContext = &CUBS_INT_CONTEXT;
        } break;
        case FLOAT_KEYWORD: {
            self.typeName = floatTypeName;
            self.knownContext = &CUBS_FLOAT_CONTEXT;
        } break;
        case STRING_KEYWORD: {
            self.typeName = stringTypeName;
            self.knownContext = &CUBS_STRING_CONTEXT;
        } break;
        case CHAR_KEYWORD: {
            self.typeName = charTypeName;
            self.knownContext = &CUBS_CHAR_CONTEXT;
        } break;
        case IDENTIFIER: {
            self.typeName = startToken.value.identifier;
            self.knownContext = NULL;
        } break;
        default: {
            fprintf(stderr, "Expected type. Found %d\n", startToken.tag);
            cubs_panic("Unexpected token encountered");
        }
    }

    (void)cubs_token_iter_next(iter);
    return self;
}