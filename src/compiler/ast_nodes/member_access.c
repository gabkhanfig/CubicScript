#include "member_access.h"
#include "../ast.h"
#include "../parse/tokenizer.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include <assert.h>

static void member_access_node_deinit(MemberAccessNode* self) {
    FREE_TYPE_ARRAY(CubsStringSlice, self->members, self->len);
    FREE_TYPE_ARRAY(size_t, self->destinations, self->len);
    FREE_TYPE(MemberAccessNode, self);
}

static AstNodeVTable member_access_node_vtable = {
    .nodeType = astNodeTypeConditional,
    .deinit = (AstNodeDeinit)&member_access_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = NULL,
    .defineType = NULL,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

AstNode cubs_member_access_node_init(TokenIter *iter, StackVariablesArray *variables)
{
    assert(iter->current.tag == IDENTIFIER);
    const CubsStringSlice identifier = iter->current.value.identifier;
    size_t foundVariableIndex = -1;
    const bool didFindVariable = cubs_stack_variables_array_find(variables, &foundVariableIndex, identifier);
    assert(didFindVariable);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == PERIOD_SYMBOL);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == IDENTIFIER && "Expected identifier for struct member access");

    /// Preallocate
    size_t capacity = 8;
    CubsStringSlice* members = MALLOC_TYPE_ARRAY(CubsStringSlice, capacity);
    size_t* destinations = MALLOC_TYPE_ARRAY(size_t, capacity);
    size_t len = 0;

    while(iter->current.tag == IDENTIFIER) {
        if(len == capacity) {
            const size_t newCapacity = capacity * 2;
            CubsStringSlice* newMembers = MALLOC_TYPE_ARRAY(CubsStringSlice, newCapacity);
            size_t* newDestinations = MALLOC_TYPE_ARRAY(size_t, newCapacity);
            for(size_t i = 0; i < len; i++) {
                newMembers[i] = members[i];
                newDestinations[i] = destinations[i];
            } 
            // known to be valid pointers
            FREE_TYPE_ARRAY(CubsStringSlice, members, capacity);
            FREE_TYPE_ARRAY(size_t, destinations, capacity);
            members = newMembers;
            destinations = newDestinations;
        }

        members[len] = iter->current.value.identifier;
        
        CubsString initial = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpStructMember", .len = 16});
        CubsString number = cubs_string_from_int(len);
        const CubsString variableName = cubs_string_concat(&initial, &number);

        cubs_string_deinit(&initial);
        cubs_string_deinit(&number);

        StackVariableInfo temporaryVariable = {
            .name = variableName,
            .isTemporary = true,
            .isMutable = false,
            .typeInfo = (TypeResolutionInfo){.tag = TypeInfoUnknown, .value._unknown = NULL},
        };

        const size_t dst = variables->len;
        destinations[len] = dst;
        len += 1;

        // variables->len will be increased by 1
        cubs_stack_variables_array_push_temporary(variables, temporaryVariable);

        
        const TokenType peekToken = cubs_token_iter_peek(iter);
        if(peekToken == PERIOD_SYMBOL) {
            (void)cubs_token_iter_next(iter); // step to period
            (void)cubs_token_iter_next(iter); // step past period
            assert(iter->current.tag == IDENTIFIER);
        }
    }

    CubsStringSlice* shrunkMembers = MALLOC_TYPE_ARRAY(CubsStringSlice, len);
    size_t* shrunkDestinations = MALLOC_TYPE_ARRAY(size_t, len);
    for(size_t i = 0; i < len; i++) {
        shrunkMembers[i] = members[i];
        shrunkDestinations[i] = destinations[i];
    } 
    // known to be valid pointers
    FREE_TYPE_ARRAY(CubsStringSlice, members, capacity);
    FREE_TYPE_ARRAY(size_t, destinations, capacity);

    const MemberAccessNode value = {
        .sourceVariableIndex = foundVariableIndex,
        .members = shrunkMembers,
        .destinations = shrunkDestinations,
        .len = len,
    };

    MemberAccessNode* self = MALLOC_TYPE(MemberAccessNode);
    *self = value;

    const AstNode node = {.ptr = (void*)self, .vtable = &member_access_node_vtable};
    return node;
}