#pragma once

#include "../primitives/string/string.h"

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
;
.

*/

typedef enum Token {
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
    STR_KEYWORD,
    CHAR_KEYWORD,
    IMPORT_KEYWORD,
    MOD_KEYWORD,
    AND_KEYWORD,
    OR_KEYWORD,
    
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
    SEMICOLON_SYMBOL,
    PERIOD_SYMBOL,
    COMMA_SYMBOL,
    REFERENCE_SYMBOL, // TODO figure out clarify between this and bit and
    //POINTER_SYMBOL, // TODO is necessary?

    INT_LITERAL,
    FLOAT_LITERAL,
    CHAR_LITERAL,
    STR_LITERAL,

    IDENTIFIER,

} Token;

/// A very simple walkthrough parser that allocates no memory.
typedef struct ParserIter {
    CubsStringSlice source;
    size_t currentPosition;
    /// Source code line number
    size_t currentLine;
    /// Source code column
    size_t currentColumn;
    Token current;
    Token next;
} ParserIter;

ParserIter cubs_parser_iter_init(CubsStringSlice source);

/// Returns `TOKEN_NONE` if there is no next. Moves the iterator forward.
Token cubs_parser_iter_next(ParserIter* self);

/// Returns `TOKEN_NONE` if there is no next. Does not move the iterator forward.
Token cubs_parser_iter_peek(const ParserIter* self);
