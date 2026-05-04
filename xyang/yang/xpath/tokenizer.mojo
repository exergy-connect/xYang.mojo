## XPath expression tokenizer for Mojo.

from std.collections import List
from std.memory import ArcPointer, Span

import xyang.yang.ast.util as ast_util
from xyang.yang.identifiers import (
    is_digit,
    is_identifier_char,
    is_identifier_start_char,
)
from xyang.yang.xpath.token import Token
from std.sys.intrinsics import likely, unlikely

comptime Arc = ArcPointer

# Single-byte UTF-8 / ASCII punct mapped like `AstLexer` (`byte_to_token_table`).
comptime `(` = ast_util.to_byte["("]()
comptime `)` = ast_util.to_byte[")"]()
comptime `[` = ast_util.to_byte["["]()
comptime `]` = ast_util.to_byte["]"]()
comptime `,` = ast_util.to_byte[","]()
comptime `.` = ast_util.to_byte["."]()
comptime `/` = ast_util.to_byte["/"]()
comptime `+` = ast_util.to_byte["+"]()
comptime `-` = ast_util.to_byte["-"]()
comptime `*` = ast_util.to_byte["*"]()
comptime `=` = ast_util.to_byte["="]()
comptime `<` = ast_util.to_byte["<"]()
comptime `>` = ast_util.to_byte[">"]()
comptime `!` = ast_util.to_byte["!"]()
comptime `\n` = ast_util.to_byte["\n"]()
comptime `\t` = ast_util.to_byte["\t"]()
comptime `\r` = ast_util.to_byte["\r"]()
comptime ` ` = ast_util.to_byte[" "]()

comptime `"` = ast_util.to_byte['"']()
comptime `'` = ast_util.to_byte["'"]()
comptime `\\` = ast_util.to_byte["\\"]()
comptime `:` = ast_util.to_byte[":"]()
comptime SINGLE_BYTE_TOKEN = Token.byte_to_token_table[
    (`(`, Token.PAREN_OPEN),
    (`)`, Token.PAREN_CLOSE),
    (`[`, Token.BRACKET_OPEN),
    (`]`, Token.BRACKET_CLOSE),
    (`,`, Token.COMMA),
    (`.`, Token.DOT),
    (`/`, Token.SLASH),
    (`+`, Token.PLUS),
    (`-`, Token.MINUS),
    (`*`, Token.STAR),
](default=Token.BYTE_DISPATCH_DEFAULT)

comptime WS_BYTES = ast_util.token_table[` `, `\n`, `\t`, `\r`]()


struct XPathTokenizer(Movable):
    var expression: String
    var pos: Int
    var line: Int

    def __init__(out self, ref expression: String):
        self.expression = expression
        self.pos = 0
        self.line = 1

    ## Return the next token and advance. Parser calls this repeatedly (incremental).
    ## Tokens are span-based (start, length, line); use ``.text(expression.as_bytes())`` or ``token_text``.
    def next_token(mut self) raises -> Token:
        if unlikely(_skip_whitespace(self)):
            return Token(
                type=Token.EOF, start=self.pos, length=0, line=self.line
            )
        return _scan_one_token(self)

    ## Return the lexeme string for token t from the expression this tokenizer was built from.
    def token_text(ref self, t: Token) -> String:
        return t.text(self.expression.as_bytes())

    ## Return the lexeme with quotes stripped; for STRING tokens gives the inner value.
    def token_unquoted_string_text(ref self, t: Token) -> String:
        return t.text(self.expression.as_bytes(), strip_quotes=True)

    ## Tokenize the whole expression into a list (e.g. for tests). Uses next_token() internally.
    def tokenize(mut self) raises -> List[Arc[Token]]:
        var tokens = List[Arc[Token]]()
        while True:
            var t = self.next_token()
            if t.type == Token.EOF:
                break
            tokens.append(Arc[Token](t^))
        return tokens^


# -----------------------------
# Cursor helpers
# -----------------------------


def _at_end(ref self: XPathTokenizer) -> Bool:
    return self.pos >= self.expression.byte_length()


def _peek_byte(ref self: XPathTokenizer) -> Byte:
    if _at_end(self):
        return 0
    return self.expression.as_bytes()[self.pos]


def _peek_byte_offset(ref self: XPathTokenizer, off: Int) -> Byte:
    if self.pos + off >= self.expression.byte_length():
        return 0
    return self.expression.as_bytes()[self.pos + off]


def _advance(mut self: XPathTokenizer, delta: Int = 1) raises:
    for _ in range(delta):
        if not _at_end(self) and _peek_byte(self) == `\n`:
            self.line += 1
        self.pos += 1


def _skip_whitespace(mut self: XPathTokenizer) raises -> Bool:
    var n = self.expression.byte_length()
    while self.pos < n:
        var b = self.expression.as_bytes()[self.pos]
        if not WS_BYTES[Int(b)]:
            return False
        if b == `\n`:
            self.line += 1
        self.pos += 1
    return True


def _bad_char_lexeme(ref self: XPathTokenizer) -> String:
    if _at_end(self):
        return "<eof>"
    return String(self.expression[byte = self.pos : self.pos + 1])


def _scan_one_token(mut self: XPathTokenizer) raises -> Token:
    var start = self.pos
    var line_start = self.line
    var b0 = _peek_byte(self)
    var b1 = _peek_byte_offset(self, 1)

    if b0 == `.` and b1 == `.`:
        _advance(self, 2)
        return Token(type=Token.DOTDOT, start=start, length=2, line=line_start)
    if b0 == `/` and b1 == `/`:
        _advance(self, 2)
        return Token(type=Token.SLASH, start=start, length=2, line=line_start)
    if b0 == `!` and b1 == `=`:
        _advance(self, 2)
        return Token(type=Token.NE, start=start, length=2, line=line_start)
    if b0 == `<`:
        _advance(self)
        if _peek_byte(self) == `=`:
            _advance(self)
            return Token(type=Token.LE, start=start, length=2, line=line_start)
        return Token(type=Token.LT, start=start, length=1, line=line_start)
    if b0 == `>`:
        _advance(self)
        if _peek_byte(self) == `=`:
            _advance(self)
            return Token(type=Token.GE, start=start, length=2, line=line_start)
        return Token(type=Token.GT, start=start, length=1, line=line_start)
    if b0 == `=`:
        _advance(self)
        return Token(type=Token.EQ, start=start, length=1, line=line_start)

    var ty = SINGLE_BYTE_TOKEN[Int(b0)]
    if ty != Token.BYTE_DISPATCH_DEFAULT:
        _advance(self)
        return Token(type=ty, start=start, length=1, line=line_start)

    var b = _peek_byte(self)
    if is_digit(b):
        return _read_number(self)
    if b == `"` or b == `'`:
        return _read_string(self)
    if is_identifier_start_char(b):
        return _read_identifier(self)

    raise Error(
        "Unexpected character at position "
        + String(start)
        + " (line "
        + String(line_start)
        + "): "
        + _bad_char_lexeme(self)
    )


# -----------------------------
# Lexemes
# -----------------------------


def _read_number(mut self: XPathTokenizer) raises -> Token:
    var start = self.pos
    var line_start = self.line
    var is_float = False
    while not _at_end(self) and is_digit(_peek_byte(self)):
        _advance(self)
    if not _at_end(self) and _peek_byte(self) == `.`:
        if is_digit(_peek_byte_offset(self, 1)):
            _advance(self)
            is_float = True
            while not _at_end(self) and is_digit(_peek_byte(self)):
                _advance(self)
    var tok_type = Token.FLOAT_NUMBER if is_float else Token.NUMBER
    return Token(
        type=tok_type, start=start, length=self.pos - start, line=line_start
    )


def _read_string(mut self: XPathTokenizer) raises -> Token:
    var start = self.pos
    var line_start = self.line
    var quote_b = _peek_byte(self)
    _advance(self)
    while not _at_end(self) and _peek_byte(self) != quote_b:
        if _peek_byte(self) == `\\`:
            _advance(self)
            if not _at_end(self):
                _advance(self)
        else:
            _advance(self)
    if not _at_end(self):
        _advance(self)
    return Token(
        type=Token.STRING, start=start, length=self.pos - start, line=line_start
    )


@always_inline
def _xpath_keyword_token_type_bytes(
    ref bytes: Span[Byte, _], start: Int, length: Int
) -> Token.Type:
    """Map a short NCName span to ``KW_*`` when it is a reserved XPath name; else ``IDENTIFIER``.
    """
    if length == 2:
        if (
            bytes[start] == ast_util.to_byte["o"]()
            and bytes[start + 1] == ast_util.to_byte["r"]()
        ):
            return Token.KW_OR
        return Token.IDENTIFIER
    if length == 3:
        if (
            bytes[start] == ast_util.to_byte["a"]()
            and bytes[start + 1] == ast_util.to_byte["n"]()
            and bytes[start + 2] == ast_util.to_byte["d"]()
        ):
            return Token.KW_AND
        if (
            bytes[start] == ast_util.to_byte["d"]()
            and bytes[start + 1] == ast_util.to_byte["i"]()
            and bytes[start + 2] == ast_util.to_byte["v"]()
        ):
            return Token.KW_DIV
        if (
            bytes[start] == ast_util.to_byte["m"]()
            and bytes[start + 1] == ast_util.to_byte["o"]()
            and bytes[start + 2] == ast_util.to_byte["d"]()
        ):
            return Token.KW_MOD
        return Token.IDENTIFIER
    return Token.IDENTIFIER


def _read_identifier(mut self: XPathTokenizer) -> Token:
    """One ``prefix:local`` QName token, or a keyword / plain NCName as distinct ``Token`` kinds.
    """
    var start = self.pos
    var line_start = self.line
    var b = self.expression.as_bytes()
    var n = len(b)
    self.pos += 1
    while self.pos < n and is_identifier_char(b[self.pos]):
        self.pos += 1
    if self.pos < n and b[self.pos] == `:`:
        var local0 = self.pos + 1
        if local0 < n and is_identifier_start_char(b[local0]):
            self.pos = local0 + 1
            while self.pos < n and is_identifier_char(b[self.pos]):
                self.pos += 1
            return Token(
                type=Token.QNAME,
                start=start,
                length=self.pos - start,
                line=line_start,
            )
    var length = self.pos - start
    var ty = _xpath_keyword_token_type_bytes(b, start, length)
    return Token(type=ty, start=start, length=length, line=line_start)
