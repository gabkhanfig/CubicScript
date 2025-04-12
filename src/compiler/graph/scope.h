#pragma once
#ifndef SCOPE_H
#define SCOPE_H

#include <stdbool.h>
#include <stddef.h>
#include "../../primitives/string/string_slice.h"
#include "../../primitives/string/string.h"

struct SyncVariable;

typedef union ScopeSymbolData {
    CubsString variableSymbol;
    CubsString functionSymbol;
    CubsString structSymbol;
    CubsString globalSymbol;
} ScopeSymbolData;

typedef enum ScopeSymbolType {
    scopeSymbolTypeVariable = 0,
    scopeSymbolTypeFunction = 1,
    scopeSymbolTypeStruct = 2,
    scopeSymbolTypeGlobal = 3,
} ScopeSymbolType;

/// A symbol found within a given scope. Only for named symbols. Unnamed ones
/// such as temporary variables, will not be tracked here.
typedef struct ScopeSymbol {
    ScopeSymbolType symbolType;
    ScopeSymbolData data;
} ScopeSymbol;

struct Scope;

/// All scopes enclosed in 0 or 1 outer scopes. As a result, we can use a 
/// linked-list like architecture in order to chain scopes together.
/// Naturally, any scope can access the symbols of it's parent scopes.
typedef struct Scope {
    /// If this scope is within a function, then variables may be stack variables.
    bool isInFunction;
    /// Notes that this is a sync block, allowing the accessing of `unique`,
    /// `shared`, and `weak` types.
    bool isSync;
    /// Amount of elements in `syncVariables`. Only used if `isSync` is true.
    size_t syncVariablesLen;
    /// Non-owned reference to the variables that will be synchronized. Only
    /// used is `isSync` is true.
    const struct SyncVariable* syncVariables;
    /// Array that's valid up to `len`.
    ScopeSymbol* symbols;
    /// Hash codes that correspond to `symbols` elements.
    size_t* hashCodes;
    /// Number of valid elements within `symbols` and `hashCodes`.
    size_t len;
    /// Allocation capacity of `symbols`.
    size_t capacity;
    /// May be `NULL`.
    struct Scope* optionalParent;
} Scope;

void cubs_scope_deinit(Scope* self);

/// Attempts to add `symbol` to the `self` scope. 
/// @return `false` if the symbol is declared in the `self` scope, or any of
/// its' parent scopes, otherwise `true`.
bool cubs_scope_add_symbol(Scope* self, ScopeSymbol symbol);

typedef struct FoundScopeSymbol {
    bool didFind;
    const ScopeSymbol* symbol;
    const Scope* owningScope;
} FoundScopeSymbol;

/// Returns a valid pointer if the symbol is found in `self`'s scope, or any 
/// of it's parent scopes. Returns `NULL` otherwise.
/// Pointer stability for returned values not guaranteed when mutating either
///  `self`, or the parent scopes of `self`.
FoundScopeSymbol cubs_scope_find_symbol(const Scope* self, CubsStringSlice symbolName);

/// Returns true if the symbol named `symbolName` was defined in this scope,
/// not any of its parent scopes', otherwise returns false.
/// If the symbol is found, `outIndex` will be set to the index where the
/// symbol is within `scope->symbols`. Otherwise, the value will be unmodified.
bool cubs_scope_symbol_defined_in(const Scope* scope, size_t* outIndex, CubsStringSlice symbolName);

/// Returns true if the symbol named `symbolName` is found and synchronized
/// within this scope, or it's parents scopes, otherwise returns false.
/// If it is found, `outVariable` will be set to be the corresponding data.
/// If `self->isSync == false`, returns false.
bool cubs_scope_is_symbol_synced(const Scope* self, struct SyncVariable* outVariable, CubsStringSlice symbolName);

#endif