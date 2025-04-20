#pragma once
#ifndef RESULT_NODE_H
#define RESULT_NODE_H

#include "../c_basic_types.h"
#include "ast.h"
#include "errors/compile_error.h"

union ResultAstNodeData {
    AstNode astNode;
    CompileError compileErr;
};

typedef struct ResultAstNode {
    /// If true, `data.compileErr` is valid.
    /// Otherwise, `data.astNode` is valid.
    bool                    isErr;
    /// See `isErr`.
    union ResultAstNodeData data; 
} ResultAstNode;

#endif