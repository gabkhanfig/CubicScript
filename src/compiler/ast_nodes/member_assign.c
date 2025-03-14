#include "member_assign.h"
#include "../ast.h"
#include "../parse/tokenizer.h"
#include "../stack_variables.h"
#include "../../primitives/context.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"
#include "../../interpreter/operations.h"
#include "../../interpreter/bytecode.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../graph/function_dependency_graph.h"
#include <stdio.h>

static void member_assign_node_deinit(MemberAssignNode* self) {
    FREE_TYPE_ARRAY(CubsStringSlice, self->members, self->len);
    FREE_TYPE_ARRAY(size_t, self->destinations, self->len);
    FREE_TYPE_ARRAY(uint16_t, self->memberIndices, self->len);
    expr_value_deinit(&self->newValue);
    FREE_TYPE(MemberAssignNode, self);
}

static void member_assign_node_build_function(
    const MemberAssignNode* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {
    // Get the correct member
    for(size_t i = 0; i < self->len; i++) {    
        const uint16_t memberDst = stackAssignment->positions[self->destinations[i]];
        const uint16_t memberSrc = i == 0 ? 
            self->variableIndex : 
            stackAssignment->positions[self->destinations[i - 1]]; // previous variable
        const Bytecode accessMember = cubs_operands_make_get_member(memberDst, memberSrc, self->memberIndices[i]);
        cubs_function_builder_push_bytecode(builder, accessMember);
    }

    const ExprValueDst expressionSrc = cubs_expr_value_build_function(&self->newValue, builder, stackAssignment);
    assert(expressionSrc.hasDst);

    // Set the members propegating back
    for(size_t i = self->len; i-- > 0;) {
        const uint16_t valueSrc = i == (self->len - 1) ? 
            expressionSrc.dst : 
            stackAssignment->positions[self->destinations[i + 1]];
        const uint16_t memberDst = i == 0 ? 
            self->variableIndex : 
            stackAssignment->positions[self->destinations[i]];
        const Bytecode setMember = cubs_operands_make_set_member(memberDst, valueSrc, self->memberIndices[i]);
        cubs_function_builder_push_bytecode(builder, setMember);
    }
}

static bool string_slice_eql(CubsStringSlice lhs, CubsStringSlice rhs) {
    if(lhs.len != rhs.len) {
        return false;
    }

    for(size_t i = 0; i < lhs.len; i++) {
        if(lhs.str[i] != rhs.str[i]) {
            return false;
        }
    }

    return true;
}

/// Returns -1 if not found
static size_t context_get_member_index(const CubsTypeContext* context, CubsStringSlice name) {
    for(size_t i = 0; i < context->membersLen; i++) {
        if(string_slice_eql(context->members[i].name, name)) {
            return i;
        }
    }
    return -1;
}

static void member_assign_node_resolve_types(
    MemberAssignNode* self,
    CubsProgram* program,
    const FunctionBuilder* builder,
    StackVariablesArray* variables
) {
    TypeResolutionInfo* typeInfo = &variables->variables[self->variableIndex].typeInfo;

    assert(typeInfo->tag != TypeInfoUnknown);
    const CubsTypeContext* sourceContext = NULL;
    if(self->updatingReference) {
        assert(typeInfo->tag == TypeInfoReference);
        sourceContext = cubs_type_resolution_info_get_context(typeInfo->value.reference.child, program);
    } else {
        sourceContext = cubs_type_resolution_info_get_context(typeInfo, program);
    }

    uint16_t* indices = MALLOC_TYPE_ARRAY(uint16_t, self->len);
    
    for(size_t i = 0; i < self->len; i++) {
        assert(sourceContext != NULL);
        assert(sourceContext->membersLen > 0);

        const size_t foundMember = context_get_member_index(sourceContext, self->members[i]);
        assert(foundMember != -1);
        assert(foundMember <= UINT16_MAX);

        const uint16_t index = (uint16_t)foundMember;
        indices[i] = index;
        sourceContext = sourceContext->members[index].context; // nested types

        // also resolve types for temporary variables
        TypeResolutionInfo* temporaryTypeInfo = 
            &variables->variables[self->destinations[i]].typeInfo;
        if(temporaryTypeInfo->tag != TypeInfoUnknown) {
            continue;
        }

        temporaryTypeInfo->tag = TypeInfoKnownContext;
        temporaryTypeInfo->value.knownContext = sourceContext;
    }

    self->memberIndices = indices;
}

static AstNodeVTable member_assign_node_vtable = {
    .nodeType = astNodeTypeMemberAssign,
    .deinit = (AstNodeDeinit)&member_assign_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&member_assign_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&member_assign_node_resolve_types,
    .endsWithReturn = NULL,
};

AstNode cubs_member_assign_node_init(TokenIter *iter, StackVariablesArray *variables, FunctionDependencies* dependencies)
{
    assert(iter->current.tag == IDENTIFIER);
    const CubsStringSlice identifier = iter->current.value.identifier;
    size_t foundVariableIndex = -1;
    const bool didFindVariable = cubs_stack_variables_array_find(variables, &foundVariableIndex, identifier);
    assert(didFindVariable);

    
    bool updatingReference = false;    
    { // validate mutable
        const StackVariableInfo* variableInfo = &variables->variables[foundVariableIndex];
        if(variableInfo->typeInfo.tag == TypeInfoReference) {
            assert(variableInfo->typeInfo.value.reference.isMutable);
            updatingReference = true;
        } else {
            assert(variableInfo->isMutable);
        }
    }

    size_t refVariableIndex = -1;
    if(updatingReference) {
        const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpDeref", .len = 9});
            
        StackVariableInfo temporaryVariable = {
            .name = variableName,
            .isTemporary = true,
            .isMutable = false,
            //.typeInfo = cubs_type_resolution_info_from_context(&CUBS_INT_CONTEXT),
            .typeInfo = cubs_type_resolution_info_clone(variables->variables[foundVariableIndex].typeInfo.value.reference.child),
        };

        // Variable order is preserved
        refVariableIndex = variables->len;

        // variables->len will be increased by 1
        cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
    }

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == PERIOD_SYMBOL);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == IDENTIFIER && "Expected identifier for struct member assignment");


    CubsStringSlice* shrunkMembers = NULL;
    size_t* shrunkDestinations = NULL;
    size_t len = 0;

    { // parse the struct members
        size_t capacity = 8;
        CubsStringSlice* members = MALLOC_TYPE_ARRAY(CubsStringSlice, capacity);
        size_t* destinations = MALLOC_TYPE_ARRAY(size_t, capacity);

        while(true) {
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
            } else {
                break;
            }
        }
    
        shrunkMembers = MALLOC_TYPE_ARRAY(CubsStringSlice, len);
        shrunkDestinations = MALLOC_TYPE_ARRAY(size_t, len);
        for(size_t i = 0; i < len; i++) {
            shrunkMembers[i] = members[i];
            shrunkDestinations[i] = destinations[i];
        } 
        // known to be valid pointers
        FREE_TYPE_ARRAY(CubsStringSlice, members, capacity);
        FREE_TYPE_ARRAY(size_t, destinations, capacity);
    }

    assert(shrunkMembers != NULL);
    assert(shrunkDestinations != NULL);
    assert(len > 0);

    (void)cubs_token_iter_next(iter);
    assert(iter->current.tag == ASSIGN_OPERATOR);
    
    (void)cubs_token_iter_next(iter);
    ExprValue newValue = cubs_parse_expression(iter, variables, dependencies, false, 0);
    { // the last temporary variable is the actual one to update
        const size_t updatingIndex = shrunkDestinations[len - 1];
        cubs_expr_value_update_destination(&newValue, updatingIndex);
    }
    
    MemberAssignNode* self = MALLOC_TYPE(MemberAssignNode);
    *self = (MemberAssignNode){
        .variableIndex = foundVariableIndex,
        .updatingReference = updatingReference,
        .refVariableIndex = refVariableIndex,
        .newValue = newValue,
        .members = shrunkMembers,
        .destinations = shrunkDestinations,
        .memberIndices = NULL,
        .len = len
    };

    const AstNode node = {.ptr = (void*)self, .vtable = &member_assign_node_vtable};
    return node;
}
