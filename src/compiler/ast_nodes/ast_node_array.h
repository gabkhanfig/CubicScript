#pragma once

#include "../ast.h"
#include <stdint.h>
#include <assert.h>
#include "../../platform/mem.h"

static const size_t NODE_ALIGN = 8;

/// Should be zero initialized.
typedef struct AstNodeArray {
    AstNode* nodes;
    /// Doesn't make sense to store more than 4 billion nodes
    uint32_t len;
    /// Similar to `len`, doesn't make sense to store more than 4 billion nodes
    uint32_t capacity;
} AstNodeArray;

inline static void ast_node_array_deinit(AstNodeArray* self) {
    if(self->capacity == 0) {
        return;
    }

    assert(self->nodes != NULL);
    for(uint32_t i = 0; i < self->len; i++) {
        ast_node_deinit(&self->nodes[i]);
    }
    cubs_free((void*)self->nodes, sizeof(AstNode) * self->capacity, NODE_ALIGN);
}

inline static void ast_node_array_push(AstNodeArray* self, AstNode node) {
    if(self->len == self->capacity) {
        const size_t newCapacity = self->capacity == 0 ? 2 : self->capacity << 1;
        AstNode* newNodes = (AstNode*)cubs_malloc(sizeof(AstNode) * newCapacity, NODE_ALIGN);
        if(self->nodes != NULL) {
            for(uint32_t i = 0; i < self->len; i++) {
                newNodes[i] = self->nodes[i];
            }
            cubs_free((void*)self->nodes, sizeof(AstNode) * self->capacity, NODE_ALIGN);
        }
        self->nodes = newNodes;
        self->capacity = newCapacity;
    }

    self->nodes[self->len] = node;
    self->len += 1;
}
