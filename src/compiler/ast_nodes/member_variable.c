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

    { // type
        (void)cubs_token_iter_next(iter);
        const Token token = iter->current;
        switch(token.tag) {
            case INT_KEYWORD: {
                self->typeInfo.tag = VariableTypeInfoKnown;
                self->typeInfo.info.knownContext = &CUBS_INT_CONTEXT;
            } break;
            case IDENTIFIER: {
                self->typeInfo.tag = VariableTypeInfoTypeName;
                self->typeInfo.info.typeName = token.value.identifier;
            } break;
            default: {
                unreachable();
            }
        }
    }

    { // ends with semicolon
        const TokenType tokenType = cubs_token_iter_next(iter);
        assert(tokenType == SEMICOLON_SYMBOL);
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &member_variable_node_vtable};
    return node;
}