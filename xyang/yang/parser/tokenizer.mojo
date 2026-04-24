from std.collections import Dict
from std.collections.string import Codepoint
from xyang.yang.parser.types import YangToken
import xyang.yang.parser.yang_token as tk

comptime CP_NEWLINE = Codepoint.ord("\n")
comptime CP_SLASH = Codepoint.ord("/")
comptime CP_STAR = Codepoint.ord("*")
comptime CP_DQUOTE = Codepoint.ord('"')
comptime CP_SQUOTE = Codepoint.ord("'")
comptime CP_BACKSLASH = Codepoint.ord("\\")
comptime CP_BRACE_OPEN = Codepoint.ord("{")
comptime CP_BRACE_CLOSE = Codepoint.ord("}")
comptime CP_SEMICOLON = Codepoint.ord(";")
comptime CP_COLON = Codepoint.ord(":")
comptime CP_PLUS = Codepoint.ord("+")


def tokenize_yang_impl(source: String) -> List[YangToken]:
    var tokens = List[YangToken]()
    var keyword_types = _make_keyword_type_map()

    var i = 0
    var n = len(source)
    var line = 1

    while i < n:
        var ch = _codepoint_at_byte(source, i)

        if _is_space(ch):
            if ch == CP_NEWLINE:
                line += 1
            i += 1
            continue

        if ch == CP_SLASH and i + 1 < n:
            var nxt = _codepoint_at_byte(source, i + 1)
            if nxt == CP_SLASH:
                i += 2
                while i < n and _codepoint_at_byte(source, i) != CP_NEWLINE:
                    i += 1
                continue
            if nxt == CP_STAR:
                i += 2
                while i < n:
                    var c = _codepoint_at_byte(source, i)
                    if i + 1 < n and c == CP_STAR and _codepoint_at_byte(source, i + 1) == CP_SLASH:
                        i += 2
                        break
                    if c == CP_NEWLINE:
                        line += 1
                    i += 1
                continue

        if _is_symbol(ch):
            tokens.append(
                YangToken(
                    type=_symbol_token_type(ch),
                    start=i,
                    length=1,
                    line=line,
                ),
            )
            i += 1
            continue

        if ch == CP_DQUOTE or ch == CP_SQUOTE:
            var quote = ch
            var start = i
            var token_line = line
            i += 1
            while i < n:
                var c = _codepoint_at_byte(source, i)
                if c == quote:
                    i += 1
                    break
                if c == CP_BACKSLASH and i + 1 < n:
                    i += 2
                    continue
                if c == CP_NEWLINE:
                    line += 1
                i += 1
            tokens.append(
                YangToken(
                    type=YangToken.STRING,
                    start=start,
                    length=i - start,
                    line=token_line,
                ),
            )
            continue

        var start = i
        var token_line = line
        while i < n:
            var c = _codepoint_at_byte(source, i)
            if _is_space(c) or _is_symbol(c) or c == CP_DQUOTE or c == CP_SQUOTE:
                break
            if c == CP_SLASH and i + 1 < n:
                var n2 = _codepoint_at_byte(source, i + 1)
                if n2 == CP_SLASH or n2 == CP_STAR:
                    break
            i += 1
        if i > start:
            tokens.append(
                YangToken(
                    type=_token_type_for_lexeme(
                        String(source[byte=start : i]),
                        keyword_types,
                    ),
                    start=start,
                    length=i - start,
                    line=token_line,
                ),
            )
            continue

        i += 1

    return tokens^


def _is_space(ch: Codepoint) -> Bool:
    return ch.is_posix_space()


def _is_symbol(ch: Codepoint) -> Bool:
    return (
        ch == CP_BRACE_OPEN
        or ch == CP_BRACE_CLOSE
        or ch == CP_SEMICOLON
        or ch == CP_COLON
        or ch == CP_PLUS
    )


def _codepoint_at_byte(source: String, i: Int) -> Codepoint:
    return Codepoint.ord(source[byte=i : i + 1])


def _symbol_token_type(ch: Codepoint) -> Int:
    if ch == CP_BRACE_OPEN:
        return YangToken.LBRACE
    if ch == CP_BRACE_CLOSE:
        return YangToken.RBRACE
    if ch == CP_SEMICOLON:
        return YangToken.SEMICOLON
    if ch == CP_COLON:
        return YangToken.COLON
    if ch == CP_PLUS:
        return YangToken.PLUS
    return YangToken.SLASH


def _token_type_for_lexeme(
    lexeme: String,
    read keyword_types: Dict[String, Int],
) -> Int:
    if _is_integer_lexeme(lexeme):
        return YangToken.INTEGER
    if _is_dotted_number_lexeme(lexeme):
        return YangToken.DOTTED_NUMBER
    return _keyword_type_for_lexeme(lexeme, keyword_types)


def _keyword_type_for_lexeme(
    lexeme: String,
    read keyword_types: Dict[String, Int],
) -> Int:
    var tok_type = keyword_types.get(lexeme)
    if tok_type:
        return tok_type.value()
    return YangToken.IDENTIFIER


def _make_keyword_type_map() -> Dict[String, Int]:
    var d = Dict[String, Int]()

    ## YANG_TYPE_* keywords
    d[tk.YANG_TYPE_LEAFREF] = YangToken.LEAFREF
    d[tk.YANG_TYPE_UNKNOWN] = YangToken.IDENTIFIER
    d[tk.YANG_TYPE_ENUMERATION] = YangToken.ENUMERATION
    d[tk.YANG_TYPE_BINARY] = YangToken.BINARY
    d[tk.YANG_TYPE_BITS] = YangToken.BITS
    d[tk.YANG_TYPE_BOOLEAN] = YangToken.BOOLEAN_KW
    d[tk.YANG_TYPE_DECIMAL64] = YangToken.DECIMAL64
    d[tk.YANG_TYPE_EMPTY] = YangToken.EMPTY
    d[tk.YANG_TYPE_IDENTITYREF] = YangToken.IDENTITYREF
    d[tk.YANG_TYPE_INSTANCE_IDENTIFIER] = YangToken.INSTANCE_IDENTIFIER
    d[tk.YANG_TYPE_INT8] = YangToken.INT8_KW
    d[tk.YANG_TYPE_INT16] = YangToken.INT16_KW
    d[tk.YANG_TYPE_INT32] = YangToken.INT32_KW
    d[tk.YANG_TYPE_INT64] = YangToken.INT64_KW
    d[tk.YANG_TYPE_STRING] = YangToken.STRING_KW
    d[tk.YANG_TYPE_UINT8] = YangToken.UINT8_KW
    d[tk.YANG_TYPE_UINT16] = YangToken.UINT16_KW
    d[tk.YANG_TYPE_UINT32] = YangToken.UINT32_KW
    d[tk.YANG_TYPE_UINT64] = YangToken.UINT64_KW

    ## YANG_BOOL_* keywords
    d[tk.YANG_BOOL_TRUE] = YangToken.TRUE
    d[tk.YANG_BOOL_FALSE] = YangToken.FALSE

    ## YANG_STMT_* keywords
    d[tk.YANG_STMT_MODULE] = YangToken.MODULE
    d[tk.YANG_STMT_NAMESPACE] = YangToken.NAMESPACE
    d[tk.YANG_STMT_PREFIX] = YangToken.PREFIX
    d[tk.YANG_STMT_DESCRIPTION] = YangToken.DESCRIPTION
    d[tk.YANG_STMT_REVISION] = YangToken.REVISION
    d[tk.YANG_STMT_ORGANIZATION] = YangToken.ORGANIZATION
    d[tk.YANG_STMT_CONTACT] = YangToken.CONTACT
    d[tk.YANG_STMT_CONTAINER] = YangToken.CONTAINER
    d[tk.YANG_STMT_GROUPING] = YangToken.GROUPING
    d[tk.YANG_STMT_USES] = YangToken.USES
    d[tk.YANG_STMT_REFINE] = YangToken.REFINE
    d[tk.YANG_STMT_IF_FEATURE] = YangToken.IF_FEATURE
    d[tk.YANG_STMT_AUGMENT] = YangToken.AUGMENT
    d[tk.YANG_STMT_LIST] = YangToken.LIST
    d[tk.YANG_STMT_KEY] = YangToken.KEY
    d[tk.YANG_STMT_LEAF] = YangToken.LEAF
    d[tk.YANG_STMT_LEAF_LIST] = YangToken.LEAF_LIST
    d[tk.YANG_STMT_ANYDATA] = YangToken.ANYDATA
    d[tk.YANG_STMT_ANYXML] = YangToken.ANYXML
    d[tk.YANG_STMT_CHOICE] = YangToken.CHOICE
    d[tk.YANG_STMT_CASE] = YangToken.CASE
    d[tk.YANG_STMT_TYPE] = YangToken.TYPE
    d[tk.YANG_STMT_UNION] = YangToken.UNION
    d[tk.YANG_STMT_ENUM] = YangToken.ENUM
    d[tk.YANG_STMT_MANDATORY] = YangToken.MANDATORY
    d[tk.YANG_STMT_DEFAULT] = YangToken.DEFAULT
    d[tk.YANG_STMT_MUST] = YangToken.MUST
    d[tk.YANG_STMT_WHEN] = YangToken.WHEN
    d[tk.YANG_STMT_RANGE] = YangToken.RANGE
    d[tk.YANG_STMT_PATH] = YangToken.PATH
    d[tk.YANG_STMT_FRACTION_DIGITS] = YangToken.FRACTION_DIGITS
    d[tk.YANG_STMT_BIT] = YangToken.BIT
    d[tk.YANG_STMT_BASE] = YangToken.BASE
    d[tk.YANG_STMT_POSITION] = YangToken.POSITION
    d[tk.YANG_STMT_REQUIRE_INSTANCE] = YangToken.REQUIRE_INSTANCE
    d[tk.YANG_STMT_ERROR_MESSAGE] = YangToken.ERROR_MESSAGE
    d[tk.YANG_STMT_MIN_ELEMENTS] = YangToken.MIN_ELEMENTS
    d[tk.YANG_STMT_MAX_ELEMENTS] = YangToken.MAX_ELEMENTS
    d[tk.YANG_STMT_ORDERED_BY] = YangToken.ORDERED_BY
    d[tk.YANG_STMT_UNIQUE] = YangToken.UNIQUE

    return d^


def _is_integer_lexeme(lexeme: String) -> Bool:
    if len(lexeme) == 0:
        return False
    var i = 0
    if lexeme[byte=0 : 1] == "-":
        if len(lexeme) == 1:
            return False
        i = 1
    while i < len(lexeme):
        var c = _codepoint_at_byte(lexeme, i)
        if not c.is_ascii_digit():
            return False
        i += 1
    return True


def _is_dotted_number_lexeme(lexeme: String) -> Bool:
    var n = len(lexeme)
    if n < 3:
        return False
    var i = 0
    var saw_dot = False
    var saw_digit = False
    while i < n:
        var c = _codepoint_at_byte(lexeme, i)
        if c.is_ascii_digit():
            saw_digit = True
            i += 1
            continue
        if c == Codepoint.ord("."):
            if i == 0 or i + 1 >= n:
                return False
            var next_c = _codepoint_at_byte(lexeme, i + 1)
            if not next_c.is_ascii_digit():
                return False
            saw_dot = True
            i += 1
            continue
        return False
    return saw_dot and saw_digit
