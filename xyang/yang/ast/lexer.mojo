## Lexer for surface syntax when building a raw YANG `YangConstruct` tree.
##
## `AstLexer` walks a UTF-8 `ByteView` (no ownership), maintains `pos` and a 1-based `line` for
## diagnostics, and yields `AstToken` values: `{` `}` `;` `+`, double- or single-quoted `STRING`,
## `EOF`, and unquoted identifier runs.
##
## **Skip layer.** Before each token, `skip_ws_and_comments` consumes ASCII whitespace (space, tab,
## CR, LF—incrementing `line` on LF), `//` line comments to EOL, and C-style `/* … */` block
## comments (tracking newlines inside the block). YANG does not treat comments as significant;
## this matches typical scanner behavior for statement-oriented text.
##
## **Identifiers.** A maximal byte run that does not hit whitespace, `{}`, `;`, `+`, or an
## opening quote becomes `IDENTIFIER`. This is a lightweight token for statement keywords and
## unquoted arguments; it is not a full YANG identifier or XPath lexer.
##
## **Strings.** Quoted literals allow `\` escapes; the next byte is consumed verbatim (including
## another newline for line continuation). Unterminated quotes and a trailing `\` at EOF raise.
## Token `start`/`length` include the delimiters; `AstToken.text*` can strip them.
##
## **Out of scope.** Numeric literals, unquoted strings other than identifier scans, `..`, `@`, and
## other YANG-specific lexemes are not separate token kinds here—only what the construct-tree parser
## needs.

from std.memory import Span


comptime ByteView = Span[Byte, _]


@always_inline
def _to_byte[s: StaticString]() -> Byte:
    comptime assert s.byte_length() == 1, "expected one character string"
    comptime byte = s.as_bytes()[0]
    return byte


comptime `"` = _to_byte['"']()
comptime `'` = _to_byte["'"]()
comptime `{` = _to_byte["{"]()
comptime `}` = _to_byte["}"]()
comptime `;` = _to_byte[";"]()
comptime `+` = _to_byte["+"]()
comptime `/` = _to_byte["/"]()
comptime `*` = _to_byte["*"]()
comptime ` ` = _to_byte[" "]()

comptime `\n` = _to_byte["\n"]()
comptime `\t` = _to_byte["\t"]()
comptime `\\` = _to_byte["\\"]()
comptime `\r` = _to_byte["\r"]()


@always_inline
def token_table[*tokens: Byte]() -> InlineArray[Bool, 256]:
    var t = InlineArray[Bool, 256](fill=False)
    comptime for i in range(len(tokens)):
        t[tokens[i]] = True
    return t^


@fieldwise_init
struct AstToken(Copyable):
    comptime Type = UInt8

    comptime IDENTIFIER: Self.Type = 0
    comptime LBRACE: Self.Type = 1
    comptime RBRACE: Self.Type = 2
    comptime SEMICOLON: Self.Type = 3
    comptime PLUS: Self.Type = 4
    comptime STRING: Self.Type = 5
    comptime EOF: Self.Type = 6

    @always_inline
    @staticmethod
    def byte_to_token_table[
        *tuples: Tuple[Byte, Self.Type]
    ](default: Self.Type = Self.IDENTIFIER) -> InlineArray[Self.Type, 256]:
        var t = InlineArray[Self.Type, 256](fill=default)
        comptime for i in range(len(tuples)):
            t[tuples[i][0]] = tuples[i][1]
        return t^

    var type: Self.Type
    var start: Int
    var length: Int
    var line: Int

    def text_slice[
        origin: ImmutOrigin
    ](
        self, source: ByteView[origin], strip_quotes: Bool = False
    ) -> StringSlice[origin]:
        var start = self.start
        var end = self.start + self.length
        if strip_quotes and self.type == Self.STRING and self.length >= 2:
            start += 1
            end -= 1
        return StringSlice(unsafe_from_utf8=source[start:end])

    def text[
        origin: ImmutOrigin
    ](self, source: ByteView[origin], strip_quotes: Bool = False) -> String:
        return String(self.text_slice(source, strip_quotes))

    def __str__(ref self) -> String:
        return "AstToken(type=" + String(self.type) + ")"


struct AstLexer[origin: ImmutOrigin]:
    var input: ByteView[Self.origin]
    var pos: Int
    var line: Int

    def __init__(out self, input: ByteView[Self.origin]):
        self.input = input
        self.pos = 0
        self.line = 1

    def eof(ref self) -> Bool:
        return self.pos >= len(self.input)

    def skip_ws_and_comments(mut self):
        comptime WHITESPACE_SCAN_STOP = token_table[` `, `\n`, `\t`, `\r`]()

        while not self.eof():
            var ch = self.input[self.pos]
            if WHITESPACE_SCAN_STOP[Int(ch)]:
                if ch == `\n`:
                    self.line += 1
                self.pos += 1
            elif ch == `/` and self.pos + 1 < len(self.input):
                var next_ch = self.input[self.pos + 1]
                if next_ch == `/`:
                    self.pos += 2
                    while not self.eof():
                        var line_ch = self.input[self.pos]
                        if line_ch == `\n` or line_ch == `\r`:
                            break
                        self.pos += 1
                elif next_ch == `*`:
                    self.pos += 2
                    while not self.eof():
                        var block_ch = self.input[self.pos]
                        if (
                            block_ch == `*`
                            and self.pos + 1 < len(self.input)
                            and self.input[self.pos + 1] == `/`
                        ):
                            self.pos += 2
                            break
                        if block_ch == `\n`:
                            self.line += 1
                        self.pos += 1
                else:
                    return
            else:
                return

    def scan_identifier(mut self) raises -> Int:
        comptime IDENTIFIER_SCAN_STOP = token_table[
            ` `, `\n`, `\t`, `\r`, `{`, `}`, `;`, `+`, `"`, `'`
        ]()

        var start = self.pos
        while not self.eof():
            var ch = self.input[self.pos]
            if IDENTIFIER_SCAN_STOP[Int(ch)]:
                break
            self.pos += 1

        if self.pos == start:
            raise Error("Expected YANG IDENTIFIER")

        return self.pos - start

    def scan_quoted_string(mut self) raises -> Int:
        var start = self.pos
        var quote = self.input[self.pos]
        self.pos += 1

        while not self.eof():
            var ch = self.input[self.pos]
            self.pos += 1
            if ch == quote:
                return self.pos - start

            if ch == `\n`:
                self.line += 1

            if ch == `\\`:
                if self.eof():
                    raise Error("Trailing escape in string literal")
                var escaped = self.input[self.pos]
                self.pos += 1
                if escaped == `\n`:
                    self.line += 1

        raise Error("Unterminated string literal")

    def next_token(mut self) raises -> AstToken:
        comptime TOKEN_TYPES = AstToken.byte_to_token_table[
            (`{`, AstToken.LBRACE),
            (`}`, AstToken.RBRACE),
            (`;`, AstToken.SEMICOLON),
            (`+`, AstToken.PLUS),
            (`"`, AstToken.STRING),
            (`'`, AstToken.STRING),
        ](default=AstToken.IDENTIFIER)

        self.skip_ws_and_comments()

        if self.eof():
            return AstToken(
                type=AstToken.EOF, start=self.pos, length=0, line=self.line
            )

        var token_type = TOKEN_TYPES[Int(self.input[self.pos])]

        if token_type == AstToken.STRING:
            var start = self.pos
            var line = self.line
            return AstToken(
                type=AstToken.STRING,
                start=start,
                length=self.scan_quoted_string(),
                line=line,
            )
        if token_type != AstToken.IDENTIFIER:
            self.pos += 1
            return AstToken(
                type=token_type, start=self.pos - 1, length=1, line=self.line
            )

        var start = self.pos
        return AstToken(
            type=AstToken.IDENTIFIER,
            start=start,
            length=self.scan_identifier(),
            line=self.line,
        )
