#include "struct_node.h"
#include "member_variable.h"
#include "../../platform/mem.h"
#include <assert.h>
#include "../../program/program_type_context.h"
#include "../../program/program_internal.h"
#include "../script_types/struct_memory_layout.h"
#include "../../util/panic.h"

static void struct_node_deinit(StructNode* self) {
    ast_node_array_deinit(&self->memberVariables);
    FREE_TYPE(StructNode, self);
}

static void struct_node_define_type(const StructNode* self, CubsProgram* program) {
    CubsTypeContext* context = cubs_program_malloc_script_context(program);

    CubsTypeMemberContext* memberContexts = 
        cubs_program_malloc_member_context_array(program, self->memberVariables.len);
    
    StructMemoryLayout layout = {0};
    for(uint32_t i = 0; i < self->memberVariables.len; i++) {
        assert(self->memberVariables.nodes[i].vtable->nodeType == astNodeTypeMemberVariable);
        const MemberVariableNode* memberNode = (const MemberVariableNode*)self->memberVariables.nodes[i].ptr;

        CubsTypeMemberContext memberContext = {0};

        assert(memberNode->typeInfo.knownContext != NULL);
        memberContext.context = memberNode->typeInfo.knownContext;

        memberContext.byteOffset = struct_memory_layout_next(&layout, memberContext.context);
        memberContext.name = cubs_program_malloc_copy_string_slice(program, memberNode->name);
        memberContexts[i] = memberContext;
    }

    const CubsStringSlice structName = cubs_program_malloc_copy_string_slice(program, self->name);
    context->name = structName.str;
    context->nameLength = structName.len;
    context->sizeOfType = layout.structSize;
    // TODO handle alignment
    context->members = memberContexts;
    context->membersLen = self->memberVariables.len;

    const ProgramTypeContext programContext = {.isScriptContext = true, .context.scriptContext = context};
    cubs_program_context_insert(program, programContext);
}

static AstNodeVTable struct_node_vtable = {
    .nodeType = astNodeTypeStruct,
    .deinit = (AstNodeDeinit)&struct_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = NULL,
    .defineType = (AstNodeDefineType)&struct_node_define_type,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

AstNode cubs_struct_node_init(TokenIter* iter) {
    // TODO extern?
    assert(iter->current.tag == STRUCT_KEYWORD);

    StructNode* self = MALLOC_TYPE(StructNode);
    *self = (StructNode){0};

    { // struct name
        const TokenType tokenType = cubs_token_iter_next(iter);
        assert(tokenType == IDENTIFIER);

        self->name = iter->current.value.identifier;
    }

    { // opening bracket
        const TokenType tokenType = cubs_token_iter_next(iter);
        assert(tokenType == LEFT_BRACE_SYMBOL);
    }

    TokenType memberVariableToken = cubs_token_iter_next(iter);
    assert(memberVariableToken == IDENTIFIER);
    while(memberVariableToken == IDENTIFIER) {
        AstNode memberVariable = cubs_member_variable_init(iter);
        ast_node_array_push(&self->memberVariables, memberVariable);

        // member variables must end with semicolons
        assert(iter->current.tag == SEMICOLON_SYMBOL);

        memberVariableToken = cubs_token_iter_next(iter);
    }

    assert(memberVariableToken == RIGHT_BRACE_SYMBOL);

    { // struct definition ends with semicolon 
        const TokenType tokenType = cubs_token_iter_next(iter);
        assert(tokenType == SEMICOLON_SYMBOL);
    }

    const AstNode node = {.ptr = (void*)self, .vtable = &struct_node_vtable};
    return node;
}