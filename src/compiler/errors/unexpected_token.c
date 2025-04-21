#include "unexpected_token.h"
#include "../../platform/mem.h"
#include <assert.h>

static void unexpected_token_deinit(UnexpectedToken* self) {
    FREE_TYPE(UnexpectedToken, self);
}

static CompileErrorVTable unexpected_token_vtable = {
    .errType = compileErrorTypeUnexpectedToken,
    .deinit = (CompileErrorDeinit)&unexpected_token_deinit,
};

static CubsString expected_and_found(const UnexpectedToken* self) {
    assert(self->expectedLen > 0);

    CubsString s1;
    CubsString s2;
    if(self->expectedLen > 1) {
        s1 = cubs_string_init_unchecked((CubsStringSlice){.str = "Expected one of [", .len = 17});
    } else {
        s1 = cubs_string_init_unchecked((CubsStringSlice){.str = "Expected ", .len = 9});
    }
    
    for(size_t i = 0; i < (self->expectedLen - 1); i++) {
        const TokenType tokenType = self->expected[i];
        const CubsStringSlice tokenSlice = cubs_token_type_to_string_slice(tokenType);
        if(tokenType != INT_LITERAL || tokenType != FLOAT_LITERAL || tokenType != CHAR_LITERAL || tokenType != STR_LITERAL || tokenType != IDENTIFIER) {
            s2 = cubs_string_concat_slice_unchecked(&s1, (CubsStringSlice){.str = "'", .len = 1});
            cubs_string_deinit(&s1);
            s1 = cubs_string_concat_slice_unchecked(&s2, tokenSlice);
            cubs_string_deinit(&s2);
            s2 = cubs_string_concat_slice_unchecked(&s1, (CubsStringSlice){.str = "'", .len = 1});
        } else {
            s2 = cubs_string_concat_slice_unchecked(&s1, tokenSlice);
        }
        cubs_string_deinit(&s1);
        s1 = cubs_string_concat_slice_unchecked(&s2, (CubsStringSlice){.str = ", ", .len = 2});
        cubs_string_deinit(&s2);
    }
    {
        const TokenType tokenType = self->expected[self->expectedLen - 1];
        const CubsStringSlice tokenSlice = cubs_token_type_to_string_slice(tokenType);
        if(tokenType != INT_LITERAL || tokenType != FLOAT_LITERAL || tokenType != CHAR_LITERAL || tokenType != STR_LITERAL || tokenType != IDENTIFIER) {
            s2 = cubs_string_concat_slice_unchecked(&s1, (CubsStringSlice){.str = "'", .len = 1});
            cubs_string_deinit(&s1);
            s1 = cubs_string_concat_slice_unchecked(&s2, tokenSlice);
            cubs_string_deinit(&s2);
            s2 = cubs_string_concat_slice_unchecked(&s1, (CubsStringSlice){.str = "'", .len = 1});
        } else {
            s2 = cubs_string_concat_slice_unchecked(&s1, tokenSlice);
        }
        cubs_string_deinit(&s1);
    }

    if(self->expectedLen > 1) {
        s1 = cubs_string_concat_slice_unchecked(&s2, (CubsStringSlice){.str = "]. Found ", .len = 2});
    } else {
        s1 = cubs_string_concat_slice_unchecked(&s2, (CubsStringSlice){.str = ". Found ", .len = 2});
    }
    cubs_string_deinit(&s2);
    
    { 
        const TokenType tokenType = self->found;
        const CubsStringSlice tokenSlice = cubs_token_type_to_string_slice(tokenType);
        if(tokenType != INT_LITERAL || tokenType != FLOAT_LITERAL || tokenType != CHAR_LITERAL || tokenType != STR_LITERAL || tokenType != IDENTIFIER) {
            s2 = cubs_string_concat_slice_unchecked(&s1, (CubsStringSlice){.str = "'", .len = 1});
            cubs_string_deinit(&s1);
            s1 = cubs_string_concat_slice_unchecked(&s2, tokenSlice);
            cubs_string_deinit(&s2);
            s2 = cubs_string_concat_slice_unchecked(&s1, (CubsStringSlice){.str = "'", .len = 1});
        } else {
            s2 = cubs_string_concat_slice_unchecked(&s1, tokenSlice);
        }
        cubs_string_deinit(&s1);
    }

    s1 = cubs_string_concat_slice_unchecked(&s2, (CubsStringSlice){.str = ".", .len = 1});
    cubs_string_deinit(&s2);
    return s1;
}


CompileError unexpected_token_init(const TokenIter *iter, const TokenType *expected, size_t expectedLen)
{
    UnexpectedToken* self = MALLOC_TYPE(UnexpectedToken);
    *self = (UnexpectedToken){
        .found = iter->current.tag,
        .expected = expected,
        .expectedLen = expectedLen
    };

    const CubsCompileErrorLocation location = {.fileName = iter->name, .position = iter->position};

    CubsString message = cubs_string_init_unchecked((CubsStringSlice){.str = "Unexpected Token. ", .len = 18});
    { // write message
        CubsString temp = cubs_string_concat_slice_unchecked(&message, location.fileName);
        cubs_string_deinit(&message);
        message = cubs_string_concat_slice_unchecked(&temp, (CubsStringSlice){.str = " ", .len = 1});
        cubs_string_deinit(&temp);
        CubsString posAsString = charPosToString(location.position);
        temp = cubs_string_concat(&message, &posAsString);
        cubs_string_deinit(&message);
        cubs_string_deinit(&posAsString);
        CubsString expAndF = expected_and_found(self);
        message = cubs_string_concat(&temp, &expAndF);
        cubs_string_deinit(&expAndF);
        cubs_string_deinit(&temp);
    }

    return (CompileError){
        .vtable = &unexpected_token_vtable,
        .ptr = (void*)self,
        .location = location,
        .message = message
    };
}