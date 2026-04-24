from std.collections.string import Codepoint
from xyang.yang.parser.types import YangToken

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

    var i = 0
    var n = len(source)
    var line = 1
    var line_start = 0

    while i < n:
        var ch = _codepoint_at_byte(source, i)

        if _is_space(ch):
            if ch == CP_NEWLINE:
                line += 1
                line_start = i + 1
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
                        line_start = i + 1
                    i += 1
                continue

        if _is_symbol(ch):
            tokens.append(
                YangToken(
                    value=String(source[byte=i : i + 1]),
                    quoted=False,
                    line=line,
                    col=i - line_start,
                ),
            )
            i += 1
            continue

        if ch == CP_DQUOTE or ch == CP_SQUOTE:
            var quote = ch
            var start_col = i - line_start
            i += 1
            var out = ""
            while i < n:
                var c = _codepoint_at_byte(source, i)
                if c == quote:
                    i += 1
                    break
                if c == CP_BACKSLASH and i + 1 < n:
                    out += String(source[byte=i + 1 : i + 2])
                    i += 2
                    continue
                out += String(source[byte=i : i + 1])
                if c == CP_NEWLINE:
                    line += 1
                    line_start = i + 1
                i += 1
            tokens.append(YangToken(value=out, quoted=True, line=line, col=start_col))
            continue

        var start = i
        var col = i - line_start
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
                    value=String(source[byte=start : i]),
                    quoted=False,
                    line=line,
                    col=col,
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
