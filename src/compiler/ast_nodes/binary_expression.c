#include "binary_expression.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../../program/program_internal.h"

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
    const ExprValueDst lhsSrc = cubs_expr_value_build_function(&self->lhs, builder, stackAssignment);
    assert(lhsSrc.hasDst);
    const ExprValueDst rhsSrc = cubs_expr_value_build_function(&self->rhs, builder, stackAssignment);
    assert(rhsSrc.hasDst);
    const uint16_t dst = stackAssignment->positions[self->outputVariableIndex];

    switch(self->operation) {
        case Equal: {
            const Bytecode equalBytecode = cubs_operands_make_compare(COMPARE_OP_EQUAL, dst, lhsSrc.dst, rhsSrc.dst);
            cubs_function_builder_push_bytecode(builder, equalBytecode);
        } break;
        case Add: {
            const Bytecode addBytecode = operands_make_add_dst(false, dst, lhsSrc.dst, rhsSrc.dst);
            cubs_function_builder_push_bytecode(builder, addBytecode);
        } break;
    }
}

static void binary_expr_node_resolve_types(
    BinaryExprNode* self, CubsProgram* program, const FunctionBuilder* builder, StackVariablesArray* variables
) {
    const CubsTypeContext* lhsContext = cubs_expr_node_resolve_type(&self->lhs, program, builder, variables);
    const CubsTypeContext* rhsContext = cubs_expr_node_resolve_type(&self->rhs, program, builder, variables);

    assert(lhsContext == rhsContext);

    TypeResolutionInfo* typeInfo = &variables->variables[self->outputVariableIndex].typeInfo;

    switch(self->operation) {
        case Equal: {
            // if(typeInfo->knownContext != NULL) {
            //     assert(typeInfo->knownContext == &CUBS_BOOL_CONTEXT);
            if(typeInfo->tag != TypeInfoUnknown) {
                typeInfo->tag = TypeInfoBool;
                //assert(typeInfo->knownContext == &CUBS_BOOL_CONTEXT);
            } else {
                assert(typeInfo->tag == TypeInfoBool);
                //typeInfo->knownContext = &CUBS_BOOL_CONTEXT;
            }
        } break;
        case Add: {
            //if(typeInfo->knownContext != NULL) {
            //    assert(typeInfo->knownContext == lhsContext);
            if(typeInfo->tag != TypeInfoUnknown) {
                assert(cubs_type_resolution_info_get_context(typeInfo, program) == lhsContext);
            // } else if(typeInfo->typeName.len > 0) {
            //     const CubsStringSlice typeName = typeInfo->typeName;
            //     const CubsTypeContext* resultingContext = cubs_program_find_type_context(program, typeName);
            //     assert(resultingContext != NULL);
            //     typeInfo->knownContext = resultingContext;
            } else {
                // TODO actual type inference
                typeInfo->tag = TypeInfoInt;
            }
        } break;
    }
}

static AstNodeVTable binary_expr_node_vtable = {
    .nodeType = astNodeBinaryExpression,
    .deinit = (AstNodeDeinit)&binary_expr_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = (AstNodeBuildFunction)&binary_expr_node_build_function,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&binary_expr_node_resolve_types,
    .endsWithReturn = NULL,
};

AstNode cubs_binary_expr_node_init(
    struct StackVariablesArray* variables,
    size_t outputVariableIndex,
    BinaryExprOp operation,
    ExprValue lhs,
    ExprValue rhs
) {
    BinaryExprNode* self = MALLOC_TYPE(BinaryExprNode);
    *self = (BinaryExprNode){0};

    self->outputVariableIndex = outputVariableIndex;
    self->operation = operation;
    self->lhs = lhs;
    self->rhs = rhs;

    const AstNode node = {.ptr = (void*)self, .vtable = &binary_expr_node_vtable};
    return node;
}
