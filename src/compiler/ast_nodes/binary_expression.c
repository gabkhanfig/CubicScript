#include "binary_expression.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"

static void binary_expr_node_deinit(BinaryExprNode* self) {
    expr_value_deinit(&self->lhs);
    expr_value_deinit(&self->rhs);
    FREE_TYPE(BinaryExprNode, self);
}

static void binary_expr_node_build_function(
    const BinaryExprNode* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {  

}

static AstNodeVTable binary_expr_node_vtable = {
    .nodeType = 0,
    .deinit = (AstNodeDeinit)&binary_expr_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&binary_expr_node_build_function,
};

AstNode cubs_binary_expr_node_init(
    struct StackVariablesArray* variables,
    CubsStringSlice optionalOutputName,
    BinaryExprOp operation,
    ExprValue lhs,
    ExprValue rhs
) {
    BinaryExprNode* self = MALLOC_TYPE(BinaryExprNode);
    *self = (BinaryExprNode){0};

    if(optionalOutputName.len == 0) { // empty string
        const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tempBinaryExpr", .len = 15});
            
        StackVariableInfo temporaryVariable = {
            .name = variableName,
            .isTemporary = true,
            .context = &CUBS_INT_CONTEXT,
            .taggedName = {0},
        };
        
        // Variable order is preserved
        self->outputVariableIndex = variables->len;
        // variables->len will be increased by 1
        cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
    } else {
        bool foundVariableNameIndex = false;
        for(size_t i = 0; i < variables->len; i++) {
            if(cubs_string_eql_slice(&variables->variables[i].name, optionalOutputName)) {
                foundVariableNameIndex = true;
                self->outputVariableIndex = i;
                break;
            }
        }
        assert(foundVariableNameIndex);
    }

    self->operation = operation;
    self->lhs = lhs;
    self->rhs = rhs;

    const AstNode node = {.ptr = (void*)self, .vtable = &binary_expr_node_vtable};
    return node;
}
