#include "variable_assignment.h"
#include "../ast.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../util/unreachable.h"
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../../program/program_internal.h"
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
    const uint16_t returnSrc = stackAssignment->positions[self->variableIndex];

    switch(self->newValue.tag) {
        case BoolLit: {
            const Bytecode loadImmediateBool = operands_make_load_immediate(
                LOAD_IMMEDIATE_BOOL,
                returnSrc,
                (int64_t)self->newValue.value.boolLiteral.literal
            );
            cubs_function_builder_push_bytecode(builder, loadImmediateBool);
        } break;
        case IntLit: {
            Bytecode loadImmediateLong[2];
            operands_make_load_immediate_long(
                loadImmediateLong,
                cubsValueTagInt,
                returnSrc,
                *(const size_t*)&self->newValue.value.intLiteral.literal // bit cast
            );
            cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);
        } break;
        case Expression: {
            ast_node_build_function(&self->newValue.value.expression, builder, stackAssignment);
        } break;
        default: {
            assert(false && "Can only handle variable assignment from int literals, bool literals, and expressions");
        }
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

struct AstNode cubs_variable_assignment_node_init(struct TokenIter* iter, struct StackVariablesArray* variables) {
    assert(iter->current.tag == IDENTIFIER);

    size_t foundVariableIndex;
    if(!cubs_stack_variables_array_find(variables, &foundVariableIndex, iter->current.value.identifier)) {
        assert(false && "Cannot assign to variable that hasn't been declared");
    }

    { // after variable name, expect '='
        const TokenType equalSymbolNext = cubs_token_iter_next(iter);
        assert(equalSymbolNext == ASSIGN_OPERATOR);
    }

    (void)cubs_token_iter_next(iter); // step over to next
    const ExprValue expression = cubs_parse_expression(iter, variables, true, foundVariableIndex);

    VariableAssignmentNode* self = MALLOC_TYPE(VariableAssignmentNode);
    *self = (VariableAssignmentNode){.variableIndex = foundVariableIndex, .newValue = expression};

    const AstNode node = {.ptr = (void*)self, .vtable = &variable_assignment_node_vtable};
    return node;
}