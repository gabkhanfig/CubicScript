#include "member_variable.h"
#include "../../platform/mem.h"
#include <assert.h>
#include "../../primitives/context.h"
#include "../../util/unreachable.h"

static void member_variable_node_deinit(MemberVariableNode* self) {
    FREE_TYPE(MemberVariableNode, self);
}

static AstNodeVTable member_variable_node_vtable = {
    .nodeType = astNodeTypeMemberVariable,
    .deinit = (AstNodeDeinit)&member_variable_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = NULL,
    .defineType = NULL,
};

AstNode cubs_member_variable_init(TokenIter* iter) {
    // TODO accessbility modifiers
    assert(iter->current.tag == IDENTIFIER);

    MemberVariableNode* self = MALLOC_TYPE(MemberVariableNode);
    *self = (MemberVariableNode){0};

    self->name = iter->current.value.identifier;

    { // expect colon after variable name
        const TokenType tokenType = cubs_token_iter_next(iter);
        assert(tokenType == COLON_SYMBOL);
    }

    (void)cubs_token_iter_next(iter);
    self->typeInfo = cubs_parse_type_resolution_info(iter);

    // ends with semicolon
    assert(iter->current.tag == SEMICOLON_SYMBOL);

    const AstNode node = {.ptr = (void*)self, .vtable = &member_variable_node_vtable};
    return node;
}