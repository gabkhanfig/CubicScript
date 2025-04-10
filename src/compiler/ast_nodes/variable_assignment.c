#include "variable_assignment.h"
#include "../ast.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../util/unreachable.h"
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../../program/program_internal.h"
#include "../graph/function_dependency_graph.h"
#include <stdio.h>
#include <assert.h>

static void variable_assignment_node_deinit(VariableAssignmentNode* self) {
    expr_value_deinit(&self->newValue);
    FREE_TYPE(VariableAssignmentNode, self);
}

static void variable_assignment_node_build_function(
    const VariableAssignmentNode* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {
    const ExprValueDst expressionSrc = cubs_expr_value_build_function(&self->newValue, builder, stackAssignment);
    assert(expressionSrc.hasDst);
    if(self->updateType != VariableAssignmentUpdateTypeValue) {
        const size_t actualRefDst = stackAssignment->positions[self->variableIndex];
        const Bytecode setRef = cubs_operands_make_set_reference(actualRefDst, expressionSrc.dst);
        cubs_function_builder_push_bytecode(builder, setRef);
    }
}

static AstNodeVTable variable_assignment_node_vtable = {
    .nodeType = astNodeVariableAssignment,
    .deinit = (AstNodeDeinit)&variable_assignment_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&variable_assignment_node_build_function,
    .defineType = NULL,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

struct AstNode cubs_variable_assignment_node_init(
    TokenIter* iter, 
    StackVariablesArray* variables, 
    FunctionDependencies* dependencies
) {
    assert(iter->current.tag == IDENTIFIER);

    size_t foundVariableIndex;
    if(!cubs_stack_variables_array_find(variables, &foundVariableIndex, iter->current.value.identifier)) {
        assert(false && "Cannot assign to variable that hasn't been declared");
    }

    VariableAssignmentUpdateType updateType = VariableAssignmentUpdateTypeValue;
    { // validate mutable
        const StackVariableInfo* variableInfo = &variables->variables[foundVariableIndex];
        const enum TypeResolutionInfoTag tag = variableInfo->typeInfo.tag;
        switch(tag) {
            case TypeInfoReference: {
                assert(variableInfo->typeInfo.value.reference.isMutable);
                updateType = VariableAssignmentUpdateTypeReference;
            } break;
            // TODO sync block mutable access validation
            case TypeInfoUnique: {
                updateType = VariableAssignmentUpdateTypeUnique;
            } break;
            case TypeInfoShared: {
                updateType = VariableAssignmentUpdateTypeShared;
            } break;
            case TypeInfoWeak: {
                updateType = VariableAssignmentUpdateTypeWeak;
            } break;
            default: {
                assert(variableInfo->isMutable);
            }
        }
    }

    { // after variable name, expect '='
        const TokenType equalSymbolNext = cubs_token_iter_next(iter);
        assert(equalSymbolNext == ASSIGN_OPERATOR);
    }

    (void)cubs_token_iter_next(iter); // step over to next
    ExprValue expression = cubs_parse_expression(iter, variables, dependencies, true, foundVariableIndex);
    if(updateType != VariableAssignmentUpdateTypeValue) {
        const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpDeref", .len = 9});
            
        const TypeResolutionInfo* childType = NULL;
        switch(variables->variables[foundVariableIndex].typeInfo.tag) {
            case TypeInfoReference: {
                childType = variables->variables[foundVariableIndex].typeInfo.value.reference.child;
            } break;
            case TypeInfoUnique: {
                childType = variables->variables[foundVariableIndex].typeInfo.value.unique.child;
            } break;
            case TypeInfoShared: {
                childType = variables->variables[foundVariableIndex].typeInfo.value.shared.child;
            } break;
            case TypeInfoWeak: {
                childType = variables->variables[foundVariableIndex].typeInfo.value.weak.child;
            } break;
            default: {
                unreachable();
            }
        }
        StackVariableInfo temporaryVariable = {
            .name = variableName,
            .isTemporary = true,
            .isMutable = false,
            //.typeInfo = cubs_type_resolution_info_from_context(&CUBS_INT_CONTEXT),
            .typeInfo = cubs_type_resolution_info_clone(childType),
        };

        // Variable order is preserved
        const size_t newDestinationIndex = variables->len;

        // variables->len will be increased by 1
        cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
        cubs_expr_value_update_destination(&expression, newDestinationIndex);
    } else {
        cubs_expr_value_update_destination(&expression, foundVariableIndex);
    }

    VariableAssignmentNode* self = MALLOC_TYPE(VariableAssignmentNode);
    *self = (VariableAssignmentNode){
        .variableIndex = foundVariableIndex,
        .newValue = expression,
        .updateType = updateType
    };

    const AstNode node = {.ptr = (void*)self, .vtable = &variable_assignment_node_vtable};
    return node;
}