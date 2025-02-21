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
    cubs_expr_value_build_function(&self->newValue, builder, stackAssignment);
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

    { // Cannot assign to variable that is not mutable
        const StackVariableInfo* variableInfo = &variables->variables[foundVariableIndex];
        assert(variableInfo->isMutable);
    }

    { // after variable name, expect '='
        const TokenType equalSymbolNext = cubs_token_iter_next(iter);
        assert(equalSymbolNext == ASSIGN_OPERATOR);
    }

    (void)cubs_token_iter_next(iter); // step over to next
    ExprValue expression = cubs_parse_expression(iter, variables, dependencies, true, foundVariableIndex);
    cubs_expr_value_update_destination(&expression, foundVariableIndex);

    VariableAssignmentNode* self = MALLOC_TYPE(VariableAssignmentNode);
    *self = (VariableAssignmentNode){.variableIndex = foundVariableIndex, .newValue = expression};

    const AstNode node = {.ptr = (void*)self, .vtable = &variable_assignment_node_vtable};
    return node;
}