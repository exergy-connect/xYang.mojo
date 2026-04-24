from std.collections import Dict
from std.collections.string import Codepoint
from xyang.yang.parser.types import YangToken
from xyang.yang.parser.yang_token import make_keyword_type_map

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
comptime CP_MINUS = Codepoint.ord("-")
comptime CP_UNDERSCORE = Codepoint.ord("_")
comptime CP_DOT = Codepoint.ord(".")


def tokenize_yang_impl(source: String) -> List[YangToken]:
    var tokens = List[YangToken]()
    var keyword_types = make_keyword_type_map()

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
    if _starts_identifier_lexeme(lexeme):
        return _keyword_type_for_lexeme(lexeme, keyword_types)
    if _is_integer_lexeme(lexeme):
        return YangToken.INTEGER
    if _is_dotted_number_lexeme(lexeme):
        return YangToken.DOTTED_NUMBER
    return YangToken.UNKNOWN


def _keyword_type_for_lexeme(
    lexeme: String,
    read keyword_types: Dict[String, Int],
) -> Int:
    return keyword_types.get(lexeme).or_else(YangToken.IDENTIFIER)


def _starts_numeric_lexeme(lexeme: String) -> Bool:
    var n = len(lexeme)
    if n == 0:
        return False
    var c0 = _codepoint_at_byte(lexeme, 0)
    if c0.is_ascii_digit():
        return True
    if c0 == CP_MINUS and n > 1:
        return _codepoint_at_byte(lexeme, 1).is_ascii_digit()
    return False


def _starts_identifier_lexeme(lexeme: String) -> Bool:
    if len(lexeme) == 0:
        return False
    var c0 = _codepoint_at_byte(lexeme, 0)
    return c0.is_ascii_upper() or c0.is_ascii_lower() or c0 == CP_UNDERSCORE


def _is_integer_lexeme(lexeme: String) -> Bool:
    if len(lexeme) == 0:
        return False
    var i = 0
    if _codepoint_at_byte(lexeme, 0) == CP_MINUS:
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
        if c == CP_DOT:
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
