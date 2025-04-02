#include "sync_block.h"
#include "../parse/tokenizer.h"
#include "../stack_variables.h"
#include "../graph/function_dependency_graph.h"
#include "../graph/scope.h"
#include "../../platform/mem.h"

void sync_block_node_deinit(SyncBlockNode* self) {
    FREE_TYPE_ARRAY(SyncVariable, self->variablesToSync, self->variablesLen);
    ast_node_array_deinit(&self->statements);
    cubs_scope_deinit(self->scope);
    
    *self = (SyncBlockNode){0};
    FREE_TYPE(SyncBlockNode, self);
}

static AstNodeVTable sync_node_node_vtable = {
    .nodeType = astNodeTypeSyncBlock,
    .deinit = (AstNodeDeinit)&sync_block_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = NULL,
    .defineType = NULL,
    .resolveTypes = NULL,
    .endsWithReturn = NULL,
};

AstNode cubs_sync_block_node_init(
    TokenIter* iter,
    StackVariablesArray* variables,
    FunctionDependencies* dependencies,
    Scope* outerScope
) {
    return (AstNode){0};
}
