## XPath expression tokenizer for Mojo.

from std.collections import List
from std.collections.string import Codepoint
from std.memory import ArcPointer
from xyang.xpath.token import Token
from sys.intrinsics import likely, unlikely

comptime Arc = ArcPointer

# Comptime Codepoint constants for single-character checks
comptime CP_PAREN_OPEN = Codepoint.ord("(")
comptime CP_PAREN_CLOSE = Codepoint.ord(")")
comptime CP_BRACKET_OPEN = Codepoint.ord("[")
comptime CP_BRACKET_CLOSE = Codepoint.ord("]")
comptime CP_COMMA = Codepoint.ord(",")
comptime CP_DOT = Codepoint.ord(".")
comptime CP_SLASH = Codepoint.ord("/")
comptime CP_EQUALS = Codepoint.ord("=")
comptime CP_BANG = Codepoint.ord("!")
comptime CP_LT = Codepoint.ord("<")
comptime CP_GT = Codepoint.ord(">")
comptime CP_PLUS = Codepoint.ord("+")
comptime CP_MINUS = Codepoint.ord("-")
comptime CP_STAR = Codepoint.ord("*")
comptime CP_DQUOTE = Codepoint.ord('"')
comptime CP_SQUOTE = Codepoint.ord("'")
comptime CP_BACKSLASH = Codepoint.ord("\\")
comptime CP_UNDERSCORE = Codepoint.ord("_")
comptime CP_COLON = Codepoint.ord(":")
comptime CP_NEWLINE = Codepoint.ord("\n")


struct XPathTokenizer(Movable):
    var expression: String
    var pos: Int
    var line: Int

    def __init__(out self, ref expression: String):
        self.expression = expression
        self.pos = 0
        self.line = 1

    ## Return the next token and advance. Parser calls this repeatedly (incremental).
    ## Tokens are span-based (start, length, line); use .text(expression) or token_text() for lexeme.
    def next_token(mut self) -> Token:
        if unlikely(_skip_whitespace(self)):
            return Token(type=Token.EOF, start=self.pos, length=0, line=self.line)
        return _scan_one_token(self)

    ## Return the lexeme string for token t from the expression this tokenizer was built from.
    def token_text(ref self, t: Token) -> String:
        return t.text(self.expression)

    ## Return the lexeme with quotes stripped; for STRING tokens gives the inner value.
    def token_unquoted_string_text(ref self, t: Token) -> String:
        return t.text(self.expression, strip_quotes=True)

    ## Tokenize the whole expression into a list (e.g. for tests). Uses next_token() internally.
    def tokenize(mut self) -> List[Arc[Token]]:
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
    return self.pos >= len(self.expression)

comptime CP_EOF = Codepoint(0)

def _peek(ref self: XPathTokenizer) -> Codepoint:
    if _at_end(self):
        return CP_EOF
    return Codepoint.ord(self.expression[self.pos:self.pos + 1])

def _peek_next(ref self: XPathTokenizer) -> Codepoint:
    if unlikely(self.pos + 1 >= len(self.expression)):
        return CP_EOF
    return Codepoint.ord(self.expression[self.pos + 1:self.pos + 2])


def _advance(mut self: XPathTokenizer, delta: Int = 1):
    for _ in range(delta):
        if not _at_end(self) and _peek(self) == CP_NEWLINE:
            self.line += 1
        self.pos += 1


def _skip_whitespace(mut self: XPathTokenizer) -> Bool:
    var n = len(self.expression)
    while self.pos < n:
        var c = Codepoint.ord(self.expression[self.pos:self.pos + 1])
        if not _is_space(c):
            return False
        if c == CP_NEWLINE:
            self.line += 1
        self.pos += 1
    return True


def _scan_one_token(mut self: XPathTokenizer) -> Token:
    var start = self.pos
    var line_start = self.line
    var c = _peek(self)

    if c == CP_PAREN_OPEN:
        _advance(self)
        return Token(type=Token.PAREN_OPEN, start=start, length=1, line=line_start)
    if c == CP_PAREN_CLOSE:
        _advance(self)
        return Token(type=Token.PAREN_CLOSE, start=start, length=1, line=line_start)
    if c == CP_BRACKET_OPEN:
        _advance(self)
        return Token(type=Token.BRACKET_OPEN, start=start, length=1, line=line_start)
    if c == CP_BRACKET_CLOSE:
        _advance(self)
        return Token(type=Token.BRACKET_CLOSE, start=start, length=1, line=line_start)
    if c == CP_COMMA:
        _advance(self)
        return Token(type=Token.COMMA, start=start, length=1, line=line_start)

    if c == CP_DOT and _peek_next(self) == CP_DOT:
        _advance(self, 2)
        return Token(type=Token.DOTDOT, start=start, length=2, line=line_start)
    if c == CP_SLASH and _peek_next(self) == CP_SLASH:
        _advance(self, 2)
        return Token(type=Token.SLASH, start=start, length=2, line=line_start)

    if c == CP_DOT:
        _advance(self)
        return Token(type=Token.DOT, start=start, length=1, line=line_start)
    if c == CP_SLASH:
        _advance(self)
        return Token(type=Token.SLASH, start=start, length=1, line=line_start)

    if c == CP_EQUALS:
        _advance(self)
        return Token(type=Token.OPERATOR, start=start, length=1, line=line_start)
    if c == CP_BANG and _peek_next(self) == CP_EQUALS:
        _advance(self, 2)
        return Token(type=Token.OPERATOR, start=start, length=2, line=line_start)
    if c == CP_LT:
        _advance(self)
        if _peek(self) == CP_EQUALS:
            _advance(self)
            return Token(type=Token.OPERATOR, start=start, length=2, line=line_start)
        return Token(type=Token.OPERATOR, start=start, length=1, line=line_start)
    if c == CP_GT:
        _advance(self)
        if _peek(self) == CP_EQUALS:
            _advance(self)
            return Token(type=Token.OPERATOR, start=start, length=2, line=line_start)
        return Token(type=Token.OPERATOR, start=start, length=1, line=line_start)
    if c == CP_PLUS or c == CP_MINUS or c == CP_STAR:
        _advance(self)
        return Token(type=Token.OPERATOR, start=start, length=1, line=line_start)

    if _is_digit(c):
        return _read_number(self)
    if c == CP_DQUOTE or c == CP_SQUOTE:
        return _read_string(self)
    if _is_identifier_start(c):
        return _read_identifier(self)

    raise Error("Unexpected character at position " + String(start) + " (line " + String(line_start) + "): " + String(c))


# -----------------------------
# Character predicates
# -----------------------------

def _is_space(c: Codepoint) -> Bool:
    return c.is_posix_space()


def _is_digit(c: Codepoint) -> Bool:
    return c.is_ascii_digit()


def _is_identifier_start(c: Codepoint) -> Bool:
    return c.is_ascii_upper() or c.is_ascii_lower() or c == CP_UNDERSCORE or c == CP_COLON


def _is_identifier_part(c: Codepoint) -> Bool:
    return (
        c.is_ascii_upper() or c.is_ascii_lower() or c.is_ascii_digit()
        or c == CP_UNDERSCORE or c == CP_MINUS or c == CP_COLON
    )


# -----------------------------
# Lexemes
# -----------------------------

def _read_number(mut self: XPathTokenizer) -> Token:
    var start = self.pos
    var line_start = self.line
    var is_float = False
    while not _at_end(self) and _is_digit(_peek(self)):
        _advance(self)
    if not _at_end(self) and _peek(self) == CP_DOT:
        var next = _peek_next(self)
        if _is_digit(next):
            _advance(self)
            is_float = True
            while not _at_end(self) and _is_digit(_peek(self)):
                _advance(self)
    var tok_type = Token.FLOAT_NUMBER if is_float else Token.NUMBER
    return Token(type=tok_type, start=start, length=self.pos - start, line=line_start)


def _read_string(mut self: XPathTokenizer) -> Token:
    var start = self.pos
    var line_start = self.line
    var quote = _peek(self)
    _advance(self)
    while not _at_end(self) and _peek(self) != quote:
        if _peek(self) == CP_BACKSLASH:
            _advance(self)
            if not _at_end(self):
                _advance(self)
        else:
            _advance(self)
    if not _at_end(self):
        _advance(self)
    return Token(type=Token.STRING, start=start, length=self.pos - start, line=line_start)


def _read_identifier(mut self: XPathTokenizer) -> Token:
    var start = self.pos
    var line_start = self.line
    while not _at_end(self) and _is_identifier_part(_peek(self)):
        _advance(self)
    return Token(type=Token.IDENTIFIER, start=start, length=self.pos - start, line=line_start)
