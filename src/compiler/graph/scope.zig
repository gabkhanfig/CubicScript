const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("compiler/graph/scope.h");
    @cInclude("compiler/ast_nodes/sync_block.h");
});
const string = @import("../../primitives/string/string.zig");
const String = string.String;

fn makeSlice(s: []const u8) c.CubsStringSlice {
    return .{ .str = s.ptr, .len = s.len };
}
const cubs_string_slice_eql = c.cubs_string_slice_eql;
const ScopeSymbolData = c.ScopeSymbolData;
const ScopeSymbol = c.ScopeSymbol;
const Scope = c.Scope;
const cubs_scope_deinit = c.cubs_scope_deinit;
const cubs_scope_add_symbol = c.cubs_scope_add_symbol;
const FoundScopeSymbol = c.FoundScopeSymbol;
const cubs_scope_find_symbol = c.cubs_scope_find_symbol;
const cubs_scope_symbol_defined_in = c.cubs_scope_symbol_defined_in;

test "empty deinit" {
    var scope = Scope{};
    cubs_scope_deinit(&scope);
}

test "add 1 symbol" {
    const symbolName = makeSlice("someVar");

    const symbol = ScopeSymbol{
        .symbolType = c.scopeSymbolTypeVariable,
        .data = ScopeSymbolData{ .variableSymbol = @bitCast(String.initUnchecked("someVar")) },
    };

    var scope = Scope{};
    defer cubs_scope_deinit(&scope);

    try expect(cubs_scope_add_symbol(&scope, symbol));

    try expect(scope.len == 1);
    try expect(scope.symbols != null);
    try expect(scope.hashCodes != null);

    const found = cubs_scope_find_symbol(&scope, symbolName);
    try expect(found.didFind);
    try expect(found.symbol.*.symbolType == c.scopeSymbolTypeVariable);
    try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("someVar"));
    try expect(found.owningScope == &scope);

    var index: usize = undefined;
    try expect(cubs_scope_symbol_defined_in(&scope, &index, symbolName));
    try expect(index == 0);
}

test "can't find symbol that wasn't added" {
    const symbol = ScopeSymbol{
        .symbolType = c.scopeSymbolTypeVariable,
        .data = ScopeSymbolData{ .variableSymbol = @bitCast(String.initUnchecked("someVar")) },
    };

    var scope = Scope{};
    defer cubs_scope_deinit(&scope);

    try expect(cubs_scope_add_symbol(&scope, symbol));

    const found = cubs_scope_find_symbol(&scope, makeSlice("otherVar"));
    try expect(found.didFind == false);
    var index: usize = undefined;
    try expect(!cubs_scope_symbol_defined_in(&scope, &index, makeSlice("otherVar")));
}

test "many symbols" {
    var scope = Scope{};
    defer cubs_scope_deinit(&scope);

    var names: [8][4]u8 = undefined;
    {
        var symbolNames: [8]String = undefined;
        for (0..8) |i| {
            _ = try std.fmt.bufPrint(&names[i], "var{}", .{i});
            symbolNames[i] = String.initUnchecked(names[i][0..names[i].len]);
        }

        for (0..8) |i| {
            const symbol = ScopeSymbol{
                .symbolType = c.scopeSymbolTypeVariable,
                .data = ScopeSymbolData{ .variableSymbol = @bitCast(symbolNames[i]) },
            };
            try expect(cubs_scope_add_symbol(&scope, symbol));
        }
    }

    try expect(scope.len == 8);
    try expect(scope.symbols != null);
    try expect(scope.hashCodes != null);

    for (0..8) |i| {
        const found = cubs_scope_find_symbol(&scope, makeSlice(&names[i]));
        try expect(found.didFind);
        try expect(found.symbol.*.symbolType == c.scopeSymbolTypeVariable);
        try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice(&names[i]));
        try expect(found.owningScope == &scope);
        var index: usize = undefined;
        try expect(cubs_scope_symbol_defined_in(&scope, &index, makeSlice(&names[i])));
        try expect(index == i);
        try expect(found.symbol == &scope.symbols[i]);
    }
    { // can't find some other name
        const found = cubs_scope_find_symbol(&scope, makeSlice("var8"));
        try expect(found.didFind == false);
        var index: usize = undefined;
        try expect(!cubs_scope_symbol_defined_in(&scope, &index, makeSlice("var8")));
    }
}

test "duplicate symbols" {
    const symbolName = makeSlice("someVar");

    const symbol1 = ScopeSymbol{
        .symbolType = c.scopeSymbolTypeVariable,
        .data = ScopeSymbolData{ .variableSymbol = @bitCast(String.initUnchecked("someVar")) },
    };
    const symbol2 = ScopeSymbol{
        .symbolType = c.scopeSymbolTypeVariable,
        .data = ScopeSymbolData{ .variableSymbol = @bitCast(String.initUnchecked("someVar")) },
    };

    var scope = Scope{};
    defer cubs_scope_deinit(&scope);

    try expect(cubs_scope_add_symbol(&scope, symbol1));
    try expect(!cubs_scope_add_symbol(&scope, symbol2));

    try expect(scope.len == 1);
    try expect(scope.symbols != null);
    try expect(scope.hashCodes != null);

    const found = cubs_scope_find_symbol(&scope, symbolName);
    try expect(found.didFind);
    try expect(found.symbol.*.symbolType == c.scopeSymbolTypeVariable);
    try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("someVar"));
    try expect(found.owningScope == &scope);

    var index: usize = undefined;
    try expect(cubs_scope_symbol_defined_in(&scope, &index, symbolName));
    try expect(index == 0);
}

test "1 symbol in parent scope" {
    var parent = Scope{};
    defer cubs_scope_deinit(&parent);

    const symbolName = makeSlice("someVar");

    const symbol = ScopeSymbol{
        .symbolType = c.scopeSymbolTypeVariable,
        .data = ScopeSymbolData{ .variableSymbol = @bitCast(String.initUnchecked("someVar")) },
    };
    try expect(cubs_scope_add_symbol(&parent, symbol));

    var scope = Scope{};
    defer cubs_scope_deinit(&scope);
    scope.optionalParent = &parent;

    const found = cubs_scope_find_symbol(&scope, symbolName);
    try expect(found.didFind);
    try expect(found.symbol.*.symbolType == c.scopeSymbolTypeVariable);
    try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("someVar"));
    try expect(found.owningScope == &parent);

    var index: usize = undefined;
    try expect(!cubs_scope_symbol_defined_in(&scope, &index, symbolName));
}

test "1 symbol in each scope" {
    var parent = Scope{};
    defer cubs_scope_deinit(&parent);

    var scope = Scope{};
    defer cubs_scope_deinit(&scope);
    scope.optionalParent = &parent;

    { // parent
        const symbol = ScopeSymbol{
            .symbolType = c.scopeSymbolTypeVariable,
            .data = ScopeSymbolData{ .variableSymbol = @bitCast(String.initUnchecked("parentVar")) },
        };
        try expect(cubs_scope_add_symbol(&parent, symbol));
    }
    { // child
        const symbol = ScopeSymbol{
            .symbolType = c.scopeSymbolTypeVariable,
            .data = ScopeSymbolData{ .variableSymbol = @bitCast(String.initUnchecked("childVar")) },
        };
        try expect(cubs_scope_add_symbol(&scope, symbol));
    }

    { // find parent stuff
        {
            const found = cubs_scope_find_symbol(&parent, makeSlice("parentVar"));
            try expect(found.didFind);
            try expect(found.symbol.*.symbolType == c.scopeSymbolTypeVariable);
            try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("parentVar"));
            try expect(found.owningScope == &parent);
            var index: usize = undefined;
            try expect(cubs_scope_symbol_defined_in(&parent, &index, makeSlice("parentVar")));
            try expect(index == 0);
        }
        {
            const found = cubs_scope_find_symbol(&parent, makeSlice("childVar"));
            try expect(!found.didFind);
            var index: usize = undefined;
            try expect(!cubs_scope_symbol_defined_in(&parent, &index, makeSlice("childVar")));
        }
    }
    { // find child stuff
        {
            const found = cubs_scope_find_symbol(&scope, makeSlice("parentVar"));
            try expect(found.didFind);
            try expect(found.symbol.*.symbolType == c.scopeSymbolTypeVariable);
            try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("parentVar"));
            try expect(found.owningScope == &parent);
            var index: usize = undefined;
            try expect(!cubs_scope_symbol_defined_in(&scope, &index, makeSlice("parentVar")));
        }
        {
            const found = cubs_scope_find_symbol(&scope, makeSlice("childVar"));
            try expect(found.didFind);
            try expect(found.symbol.*.symbolType == c.scopeSymbolTypeVariable);
            try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("childVar"));
            try expect(found.owningScope == &scope);
            var index: usize = undefined;
            try expect(cubs_scope_symbol_defined_in(&scope, &index, makeSlice("childVar")));
            try expect(index == 0);
        }
    }
}

test "function symbol" {
    const symbolName = makeSlice("someFunc");

    const symbol = ScopeSymbol{
        .symbolType = c.scopeSymbolTypeFunction,
        .data = ScopeSymbolData{ .functionSymbol = @bitCast(String.initUnchecked("someFunc")) },
    };

    var scope = Scope{};
    defer cubs_scope_deinit(&scope);

    try expect(cubs_scope_add_symbol(&scope, symbol));

    try expect(scope.len == 1);
    try expect(scope.symbols != null);
    try expect(scope.hashCodes != null);

    const found = cubs_scope_find_symbol(&scope, symbolName);
    try expect(found.didFind);
    try expect(found.symbol.*.symbolType == c.scopeSymbolTypeFunction);
    try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("someFunc"));
    try expect(found.owningScope == &scope);

    var index: usize = undefined;
    try expect(cubs_scope_symbol_defined_in(&scope, &index, symbolName));
    try expect(index == 0);
}

test "struct symbol" {
    const symbolName = makeSlice("someStruct");

    const symbol = ScopeSymbol{
        .symbolType = c.scopeSymbolTypeStruct,
        .data = ScopeSymbolData{ .structSymbol = @bitCast(String.initUnchecked("someStruct")) },
    };

    var scope = Scope{};
    defer cubs_scope_deinit(&scope);

    try expect(cubs_scope_add_symbol(&scope, symbol));

    try expect(scope.len == 1);
    try expect(scope.symbols != null);
    try expect(scope.hashCodes != null);

    const found = cubs_scope_find_symbol(&scope, symbolName);
    try expect(found.didFind);
    try expect(found.symbol.*.symbolType == c.scopeSymbolTypeStruct);
    try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("someStruct"));
    try expect(found.owningScope == &scope);

    var index: usize = undefined;
    try expect(cubs_scope_symbol_defined_in(&scope, &index, symbolName));
    try expect(index == 0);
}

test "global symbol" {
    const symbolName = makeSlice("someGlobal");

    const symbol = ScopeSymbol{
        .symbolType = c.scopeSymbolTypeGlobal,
        .data = ScopeSymbolData{ .structSymbol = @bitCast(String.initUnchecked("someGlobal")) },
    };

    var scope = Scope{};
    defer cubs_scope_deinit(&scope);

    try expect(cubs_scope_add_symbol(&scope, symbol));

    try expect(scope.len == 1);
    try expect(scope.symbols != null);
    try expect(scope.hashCodes != null);

    const found = cubs_scope_find_symbol(&scope, symbolName);
    try expect(found.didFind);
    try expect(found.symbol.*.symbolType == c.scopeSymbolTypeGlobal);
    try expect(@as(*const String, @ptrCast(&found.symbol.*.data.variableSymbol)).eqlSlice("someGlobal"));
    try expect(found.owningScope == &scope);

    var index: usize = undefined;
    try expect(cubs_scope_symbol_defined_in(&scope, &index, symbolName));
    try expect(index == 0);
}

test "sync variable not find" {
    var scope = Scope{};
    var out: c.SyncVariable = undefined;
    try expect(c.cubs_scope_is_symbol_synced(&scope, &out, makeSlice("someVar")) == false);
}

test "sync variable find in same scope" {
    const variables = &[1]c.SyncVariable{c.SyncVariable{ .name = makeSlice("someVar") }};

    var scope = Scope{
        .isSync = true,
        .syncVariablesLen = 1,
        .syncVariables = variables,
    };

    var out: c.SyncVariable = undefined;
    try expect(c.cubs_scope_is_symbol_synced(&scope, &out, variables[0].name));
    try expect(c.cubs_string_slice_eql(out.name, variables[0].name));
    try expect(out.isMutable == variables[0].isMutable);
}

test "sync variable not find but scope has other symbols" {
    const variables = &[1]c.SyncVariable{c.SyncVariable{ .name = makeSlice("someVar") }};

    var scope = Scope{
        .isSync = true,
        .syncVariablesLen = 1,
        .syncVariables = variables,
    };

    var out: c.SyncVariable = undefined;
    try expect(c.cubs_scope_is_symbol_synced(&scope, &out, makeSlice("otherVar")) == false);
}

test "sync variable find in same scope with many symbols" {
    const variables = &[3]c.SyncVariable{
        c.SyncVariable{ .name = makeSlice("someVar0") },
        c.SyncVariable{ .name = makeSlice("someVar1") },
        c.SyncVariable{ .name = makeSlice("someVar2") },
    };

    var scope = Scope{
        .isSync = true,
        .syncVariablesLen = 3,
        .syncVariables = variables,
    };

    var out: c.SyncVariable = undefined;
    try expect(c.cubs_scope_is_symbol_synced(&scope, &out, variables[2].name));
    try expect(c.cubs_string_slice_eql(out.name, variables[2].name));
    try expect(out.isMutable == variables[2].isMutable);
}

test "sync variable in parent scope" {
    const variables = &[1]c.SyncVariable{c.SyncVariable{ .name = makeSlice("someVar") }};

    var parent = Scope{
        .isSync = true,
        .syncVariablesLen = 1,
        .syncVariables = variables,
    };

    var child = Scope{ .isSync = true, .optionalParent = &parent };

    var out: c.SyncVariable = undefined;
    try expect(c.cubs_scope_is_symbol_synced(&child, &out, variables[0].name));
    try expect(c.cubs_string_slice_eql(out.name, variables[0].name));
    try expect(out.isMutable == variables[0].isMutable);
}
