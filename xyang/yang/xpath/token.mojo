## Span-based XPath token: references the source expression by position instead of owning lexeme text.
## Tokens are lightweight (type, start, length, line); use ``.text(source.as_bytes())`` (same origin
## pattern as ``AstToken`` / ``AstLexer``).

from std.memory import Span

comptime ByteView = Span[Byte, _]


@fieldwise_init
struct Token(Copyable):
    comptime Type = UInt8

    comptime IDENTIFIER: Self.Type = 0
    comptime NUMBER: Self.Type = 1
    comptime FLOAT_NUMBER: Self.Type = 2
    comptime STRING: Self.Type = 3
    comptime EQ: Self.Type = 4
    comptime NE: Self.Type = 5
    comptime LT: Self.Type = 6
    comptime GT: Self.Type = 7
    comptime LE: Self.Type = 8
    comptime GE: Self.Type = 9
    comptime PLUS: Self.Type = 10
    comptime MINUS: Self.Type = 11
    comptime STAR: Self.Type = 12
    comptime PAREN_OPEN: Self.Type = 13
    comptime PAREN_CLOSE: Self.Type = 14
    comptime BRACKET_OPEN: Self.Type = 15
    comptime BRACKET_CLOSE: Self.Type = 16
    comptime DOT: Self.Type = 17
    comptime DOTDOT: Self.Type = 18
    comptime SLASH: Self.Type = 19
    comptime COMMA: Self.Type = 20
    comptime KW_OR: Self.Type = 21
    comptime KW_AND: Self.Type = 22
    comptime KW_DIV: Self.Type = 23
    comptime KW_MOD: Self.Type = 24
    comptime QNAME: Self.Type = 25
    comptime EOF: Self.Type = 26
    ## Table fill only; never stored on a yielded `Token`.
    comptime BYTE_DISPATCH_DEFAULT: Self.Type = 255

    var type: Self.Type
    var start: Int
    var length: Int
    var line: Int

    def text_slice[
        origin: ImmutOrigin
    ](
        self, source: ByteView[origin], strip_quotes: Bool = False
    ) -> StringSlice[origin]:
        var s = self.start
        var e = self.start + self.length
        if strip_quotes and self.type == Self.STRING and self.length >= 2:
            s += 1
            e -= 1
        return StringSlice(unsafe_from_utf8=source[s:e])

    ## Lexeme as ``String``; ``source`` is the UTF-8 byte view of the expression (e.g. ``expr.as_bytes()``).
    def text[
        origin: ImmutOrigin
    ](self, source: ByteView[origin], strip_quotes: Bool = False) -> String:
        return String(self.text_slice(source, strip_quotes))

    @always_inline
    @staticmethod
    def byte_to_token_table[
        *tuples: Tuple[Byte, Self.Type]
    ](default: Self.Type) -> InlineArray[Self.Type, 256]:
        var t = InlineArray[Self.Type, 256](fill=default)
        comptime for i in range(len(tuples)):
            t[tuples[i][0]] = tuples[i][1]
        return t^

    ## Return the type name string for the given type constant (e.g. "IDENTIFIER", "EOF").
    @staticmethod
    def type_name(type_value: Self.Type) -> String:
        if type_value == Self.IDENTIFIER:
            return "IDENTIFIER"
        if type_value == Self.NUMBER:
            return "NUMBER"
        if type_value == Self.FLOAT_NUMBER:
            return "FLOAT_NUMBER"
        if type_value == Self.STRING:
            return "STRING"
        if type_value == Self.EQ:
            return "EQ"
        if type_value == Self.NE:
            return "NE"
        if type_value == Self.LT:
            return "LT"
        if type_value == Self.GT:
            return "GT"
        if type_value == Self.LE:
            return "LE"
        if type_value == Self.GE:
            return "GE"
        if type_value == Self.PLUS:
            return "PLUS"
        if type_value == Self.MINUS:
            return "MINUS"
        if type_value == Self.STAR:
            return "STAR"
        if type_value == Self.PAREN_OPEN:
            return "PAREN_OPEN"
        if type_value == Self.PAREN_CLOSE:
            return "PAREN_CLOSE"
        if type_value == Self.BRACKET_OPEN:
            return "BRACKET_OPEN"
        if type_value == Self.BRACKET_CLOSE:
            return "BRACKET_CLOSE"
        if type_value == Self.DOT:
            return "DOT"
        if type_value == Self.DOTDOT:
            return "DOTDOT"
        if type_value == Self.SLASH:
            return "SLASH"
        if type_value == Self.COMMA:
            return "COMMA"
        if type_value == Self.KW_OR:
            return "KW_OR"
        if type_value == Self.KW_AND:
            return "KW_AND"
        if type_value == Self.KW_DIV:
            return "KW_DIV"
        if type_value == Self.KW_MOD:
            return "KW_MOD"
        if type_value == Self.QNAME:
            return "QNAME"
        if type_value == Self.EOF:
            return "EOF"
        if type_value == Self.BYTE_DISPATCH_DEFAULT:
            return "BYTE_DISPATCH_DEFAULT"
        return "UNKNOWN"
