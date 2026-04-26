from std.collections import Dict
from std.collections.string import Codepoint
from xyang.yang.parser.yang_token import YangToken
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


# Outside string literals, YANG is ASCII. UTF-8 (codepoint) handling applies only
# to quoted string bodies: `_scan_quoted_string_body`.
def _codepoint_at_ascii_byte(read source: String, i: Int) -> Codepoint:
    return Codepoint.ord(source[byte=i : i + 1])


# Returns byte offset after the closing quote, or `n` if unclosed, and the updated
# `line` count (embedded newlines in the string).
def _scan_quoted_string_body(
    read source: String, n: Int, start: Int, start_line: Int, quote: Codepoint
) -> Tuple[Int, Int]:
    var i = start
    var line = start_line
    while i < n:
        var rest = String(source[byte=i:n])
        for cp_slice in rest.codepoint_slices():
            var c = Codepoint.ord(cp_slice)
            var w = len(cp_slice)
            if c == quote:
                return Tuple[Int, Int](i + w, line)
            if c == CP_BACKSLASH:
                i += w
                if i < n:
                    var esc_part = String(source[byte=i:n])
                    for esc in esc_part.codepoint_slices():
                        if Codepoint.ord(esc) == CP_NEWLINE:
                            line += 1
                        i += len(esc)
                        # Consume exactly one escaped codepoint, not the entire remainder.
                        break
                break
            if c == CP_NEWLINE:
                line += 1
            i += w
            break
    return Tuple[Int, Int](i, line)


def tokenize_yang_impl(source: String) -> List[YangToken]:
    var tokens = List[YangToken]()
    var keyword_types = make_keyword_type_map()
    var n = len(source)
    var i = 0
    var line = 1

    while i < n:
        var ch = _codepoint_at_ascii_byte(source, i)

        if _is_space(ch):
            if ch == CP_NEWLINE:
                line += 1
            i += 1
            continue

        if ch == CP_SLASH and i + 1 < n:
            var nxt = _codepoint_at_ascii_byte(source, i + 1)
            if nxt == CP_SLASH:
                i += 2
                while i < n and _codepoint_at_ascii_byte(source, i) != CP_NEWLINE:
                    i += 1
                continue
            if nxt == CP_STAR:
                i += 2
                while i < n:
                    var c = _codepoint_at_ascii_byte(source, i)
                    if i + 1 < n and c == CP_STAR and _codepoint_at_ascii_byte(
                        source, i + 1
                    ) == CP_SLASH:
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
            var t_start = i
            var token_line = line
            i += 1
            var r = _scan_quoted_string_body(source, n, i, line, ch)
            i = r[0]
            line = r[1]
            tokens.append(
                YangToken(
                    type=YangToken.STRING,
                    start=t_start,
                    length=i - t_start,
                    line=token_line,
                ),
            )
            continue

        var t_start = i
        var token_line = line
        while i < n:
            var c = _codepoint_at_ascii_byte(source, i)
            if _is_space(c) or _is_symbol(c) or c == CP_DQUOTE or c == CP_SQUOTE:
                break
            if c == CP_SLASH and i + 1 < n:
                var n2 = _codepoint_at_ascii_byte(source, i + 1)
                if n2 == CP_SLASH or n2 == CP_STAR:
                    break
            i += 1
        if i > t_start:
            tokens.append(
                YangToken(
                    type=_token_type_for_lexeme(
                        String(source[byte=t_start:i]),
                        keyword_types,
                    ),
                    start=t_start,
                    length=i - t_start,
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
    var cp_count = 0
    var c0 = Optional[Codepoint]()
    var c1 = Optional[Codepoint]()
    for cp in lexeme.codepoints():
        if cp_count == 0:
            c0 = Optional(cp)
        elif cp_count == 1:
            c1 = Optional(cp)
        cp_count += 1

    if cp_count == 0:
        return False
    if c0.value().is_ascii_digit():
        return True
    if c0.value() == CP_MINUS and cp_count > 1:
        return c1.value().is_ascii_digit()
    return False


def _starts_identifier_lexeme(lexeme: String) -> Bool:
    var c0 = Optional[Codepoint]()
    for cp in lexeme.codepoints():
        c0 = Optional(cp)
        break
    if not c0:
        return False
    return (
        c0.value().is_ascii_upper()
        or c0.value().is_ascii_lower()
        or c0.value() == CP_UNDERSCORE
    )


def _is_integer_lexeme(lexeme: String) -> Bool:
    var i = 0
    var saw_minus = False
    var saw_digit = False
    for c in lexeme.codepoints():
        if i == 0 and c == CP_MINUS:
            saw_minus = True
            i += 1
            continue
        if not c.is_ascii_digit():
            return False
        saw_digit = True
        i += 1
    if i == 0:
        return False
    if saw_minus and not saw_digit:
        return False
    return saw_digit


def _is_dotted_number_lexeme(lexeme: String) -> Bool:
    var i = 0
    var saw_dot = False
    var saw_digit = False
    var prev_was_dot = False
    for c in lexeme.codepoints():
        if c.is_ascii_digit():
            saw_digit = True
            prev_was_dot = False
            i += 1
            continue
        if c == CP_DOT:
            if i == 0 or prev_was_dot:
                return False
            saw_dot = True
            prev_was_dot = True
            i += 1
            continue
        return False
    if i < 3:
        return False
    if prev_was_dot:
        return False
    return saw_dot and saw_digit
