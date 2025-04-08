#pragma once

#include "../compiler_callbacks.h"
#include "../../primitives/string/string.h"

/* ==== TOKENS ====
https://www.geeksforgeeks.org/tokens-in-c/

! KEYWORDS
const
mut
return
fn
pub
if
else
switch
while
for
break
continue
struct
enum
union (?)
sync
unsafe (?)
true
false
bool
int (? maybe i64)
float (? maybe f64)
str
char
import
mod (? module)
and
or
null

! LITERALS
int literal
float literal
char literal
string literal

! IDENTIFIERS

! OPERATORS
= assign
== equal
!= not equal
! not
<
<=
>
>=
+
-
*
/
>>
<<
~
^

! SYMBOLS
(
)
[
]
{
}
:
;
.
&
*

*/

typedef enum TokenType {
    TOKEN_NONE = 0,

    CONST_KEYWORD,
    MUT_KEYWORD,
    RETURN_KEYWORD,
    FN_KEYWORD,
    PUB_KEYWORD,
    IF_KEYWORD,
    ELSE_KEYWORD,
    SWITCH_KEYWORD,
    WHILE_KEYWORD,
    FOR_KEYWORD,
    BREAK_KEYWORD,
    CONTINUE_KEYWORD,
    STRUCT_KEYWORD,
    INTERFACE_KEYWORD, // TODO should be trait? what are the linguistic differences between "interface" and "trait" ?
    ENUM_KEYWORD,
    UNION_KEYWORD,
    SYNC_KEYWORD,
    UNSAFE_KEYWORD,
    TRUE_KEYWORD,
    FALSE_KEYWORD,
    BOOL_KEYWORD,
    INT_KEYWORD,
    FLOAT_KEYWORD,
    STRING_KEYWORD,
    CHAR_KEYWORD,
    IMPORT_KEYWORD,
    MOD_KEYWORD,
    EXTERN_KEYWORD,
    AND_KEYWORD,
    OR_KEYWORD,
    NULL_KEYWORD,
    UNIQUE_KEYWORD,
    SHARED_KEYWORD,
    WEAK_KEYWORD,
    
    // TODO should modulo be an operator? also should there be a distinction between modulo and remainder?
    // TODO also power?

    ASSIGN_OPERATOR,
    EQUAL_OPERATOR,
    NOT_EQUAL_OPERATOR,
    NOT_OPERATOR,
    LESS_OPERATOR,
    LESS_EQUAL_OPERATOR,
    GREATER_OPERATOR,
    GREATER_EQUAL_OPERATOR,
    ADD_OPERATOR,
    ADD_ASSIGN_OPERATOR,
    SUBTRACT_OPERATOR,
    SUBTRACT_ASSIGN_OPERATOR,
    MULTIPLY_OPERATOR,
    MULTIPLY_ASSIGN_OPERATOR,
    DIVIDE_OPERATOR,
    DIVIDE_ASSIGN_OPERATOR,
    BITSHIFT_LEFT_OPERATOR,
    BITSHIFT_LEFT_ASSIGN_OPERATOR,
    BITSHIFT_RIGHT_OPERATOR,
    BITSHIFT_RIGHT_ASSIGN_OPERATOR,
    BIT_COMPLEMENT_OPERATOR,
    BIT_OR_OPERATOR,
    BIT_OR_ASSIGN_OPERATOR,
    BIT_AND_OPERATOR, // TODO figure out clarify between this and reference
    BIT_AND_ASSIGN_OPERATOR,
    BIT_XOR_OPERATOR,
    BIT_XOR_ASSIGN_OPERATOR,

    LEFT_PARENTHESES_SYMBOL,
    RIGHT_PARENTHESES_SYMBOL,
    LEFT_BRACKET_SYMBOL,
    RIGHT_BRACKET_SYMBOL,
    LEFT_BRACE_SYMBOL,
    RIGHT_BRACE_SYMBOL,
    COLON_SYMBOL,
    SEMICOLON_SYMBOL,
    PERIOD_SYMBOL,
    COMMA_SYMBOL,
    REFERENCE_SYMBOL, // TODO figure out clarify between this and bit and
    POINTER_SYMBOL, // TODO is necessary?

    INT_LITERAL,
    FLOAT_LITERAL,
    CHAR_LITERAL,
    STR_LITERAL,

    IDENTIFIER,

} TokenType;

static inline bool is_token_operator(enum TokenType tokenType) {
    switch(tokenType) {
        case ASSIGN_OPERATOR:
        case EQUAL_OPERATOR:
        case NOT_EQUAL_OPERATOR:
        case NOT_OPERATOR:
        case LESS_OPERATOR:
        case LESS_EQUAL_OPERATOR:
        case GREATER_OPERATOR:
        case GREATER_EQUAL_OPERATOR:
        case ADD_OPERATOR:
        case ADD_ASSIGN_OPERATOR:
        case SUBTRACT_OPERATOR:
        case SUBTRACT_ASSIGN_OPERATOR:
        case MULTIPLY_OPERATOR:
        case MULTIPLY_ASSIGN_OPERATOR:
        case DIVIDE_OPERATOR:
        case DIVIDE_ASSIGN_OPERATOR:
        case BITSHIFT_LEFT_OPERATOR:
        case BITSHIFT_LEFT_ASSIGN_OPERATOR:
        case BITSHIFT_RIGHT_OPERATOR:
        case BITSHIFT_RIGHT_ASSIGN_OPERATOR:
        case BIT_COMPLEMENT_OPERATOR:
        case BIT_OR_OPERATOR:
        case BIT_OR_ASSIGN_OPERATOR:
        case BIT_AND_OPERATOR:
        case BIT_AND_ASSIGN_OPERATOR:
        case BIT_XOR_OPERATOR:
        case BIT_XOR_ASSIGN_OPERATOR: {
            return true;
        } break;
        default: {
            return false;
        }
    }
}

/// Intermediatary struct to denote that special handling is required to convert
/// this into an actual `CubsString`.
typedef struct CubsStringTokenLiteral {
    CubsStringSlice slice;
} CubsStringTokenLiteral;

/// Corresponding with a `enum Token` instance.
/// The active union member depends on which token it is:
/// - `INT_LITERAL` => `intLiteral`
/// - `FLOAT_LITERAL` => `floatLiteral`
/// - `CHAR_LITERAL` => `charLiteral`
/// - `STR_LITERAL` => `strLiteral`
/// - `IDENTIFIER` => `identifier`
/// - other => zeroed, not to be used
typedef union TokenMetadata {
    int64_t intLiteral;
    double floatLiteral;
    CubsChar charLiteral;
    CubsStringTokenLiteral strLiteral;
    CubsStringSlice identifier;
} TokenMetadata;

/// Tagged union
typedef struct Token {
    TokenType tag;
    TokenMetadata value;
} Token;

/// A very simple walkthrough tokenizer that allocates no memory.
typedef struct TokenIter {
    /// Name of the source. Generally it's the file name.
    CubsStringSlice name;
    /// The actual source code.
    CubsStringSlice source;
    CubsSyntaxErrorCallback errCallback;
    CubsSourceFileCharPosition position;
    Token previous;
    Token current;
} TokenIter;

/// # Debug asserts
/// Must be valid utf8
TokenIter cubs_token_iter_init(CubsStringSlice name, CubsStringSlice source, CubsSyntaxErrorCallback errCallback);

/// Returns `TOKEN_NONE` if there is no next. Moves the iterator forward.
TokenType cubs_token_iter_next(TokenIter* self);

/// Peek at the next token type, without actually advancing the iterator.
TokenType cubs_token_iter_peek(const TokenIter* self);
