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
    uint16_t lhsSrc;
    uint16_t rhsSrc;

    // If lhs and rhs are literal values, they need to be loaded
    if(self->lhs.tag == IntLit) {
        const union ExprValueMetadata value = self->lhs.value;
        lhsSrc = stackAssignment->positions[value.intLiteral.variableIndex];
        Bytecode loadImmediateLong[2];
        operands_make_load_immediate_long(loadImmediateLong, cubsValueTagInt, lhsSrc, (size_t)value.intLiteral.literal);
        cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);
    } else if(self->lhs.tag == Variable) {
        lhsSrc = stackAssignment->positions[self->lhs.value.variableIndex];
    }
    if(self->rhs.tag == IntLit) {
        const union ExprValueMetadata value = self->rhs.value;
        rhsSrc = stackAssignment->positions[value.intLiteral.variableIndex];
        Bytecode loadImmediateLong[2];
        operands_make_load_immediate_long(loadImmediateLong, cubsValueTagInt, rhsSrc, (size_t)value.intLiteral.literal);
        cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);    
    }
    else if(self->rhs.tag == Variable) {
        rhsSrc = stackAssignment->positions[self->rhs.value.variableIndex];
    }

    switch(self->operation) {
        case Equal: {
            const Bytecode equalBytecode = cubs_operands_make_compare(COMPARE_OP_EQUAL, self->outputVariableIndex, lhsSrc, rhsSrc);
            cubs_function_builder_push_bytecode(builder, equalBytecode);
        } break;
        case Add: {
            const Bytecode addBytecode = operands_make_add_dst(false, self->outputVariableIndex, lhsSrc, rhsSrc);
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
            if(typeInfo->knownContext != NULL) {
                assert(typeInfo->knownContext == &CUBS_BOOL_CONTEXT);
            } else {
                typeInfo->knownContext = &CUBS_BOOL_CONTEXT;
            }
        } break;
        case Add: {
            if(typeInfo->knownContext != NULL) {
                assert(typeInfo->knownContext == lhsContext);
            } else if(typeInfo->typeName.len > 0) {
                const CubsStringSlice typeName = typeInfo->typeName;
                const CubsTypeContext* resultingContext = cubs_program_find_type_context(program, typeName);
                assert(resultingContext != NULL);
                typeInfo->knownContext = resultingContext;
            } else { // empty string
                // the type is the resulting type from the operation. For instance,
                // with an add operation, the resulting type is the same as the 
                // lhs and rhs types.
                typeInfo->knownContext = lhsContext;
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
