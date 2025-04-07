#ifndef SYNC_BLOCK_H
#define SYNC_BLOCK_H

#include "../../c_basic_types.h"
#include "ast_node_array.h"
#include "../../primitives/string/string_slice.h"

struct TokenIter;
struct StackVariablesArray;
struct FunctionDependencies;
struct Scope;

/// Specifies a variable to get synchronized. Must be a `unique`, `shared`, or
/// `weak` variable that isn't already synchronized. All of these objects
/// contain RwLocks, so the `isMutable` flag specifies for read-only (shared),
/// or read-write (exclusive) lock acquisition.
typedef struct SyncVariable {
    CubsStringSlice name;
    bool isMutable;
} SyncVariable;

typedef struct ResolvedSyncVariable {
    size_t index;
    bool isMutable;
} ResolvedSyncVariable;

typedef struct SyncBlockNode {
    /// Valid elements and allocation capacity of `variablesToSync`.
    size_t variablesLen;
    /// An array of length `variablesLen`. Signifies which variables within
    /// the sync blocks outer scope (not `self->scope`) get synchronized,
    /// as well as if they are read-only or read-write synced for the objects'
    /// RwLocks.
    SyncVariable* variablesToSync;
    /// An array of length `variablesLen`. Stores the indices of the variables
    /// that will get synchronized, as well as if they are read-only or 
    /// read-write synced for the objects' RwLocks. Is NULL upon
    /// `cubs_sync_block_node_init(...)`, however is set when this node is
    /// resolved.
    ResolvedSyncVariable* resolvedVariablesToSync;
    AstNodeArray statements;
    struct Scope* scope;
} SyncBlockNode;

struct AstNode cubs_sync_block_node_init(
    struct TokenIter* iter,
    struct StackVariablesArray* variables,
    struct FunctionDependencies* dependencies,
    struct Scope* outerScope
);

#endif