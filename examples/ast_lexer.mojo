## Minimal lexer for the raw YANG AST example.
##
## It recognizes only the token shapes needed to build a YangConstruct tree:
## statement names / argument identifiers, quoted strings, `{`, `}`, `;`, `+`, and EOF.

from std.memory import Span

import xyang.yang.ast.util as ast_util


comptime ByteView = Span[Byte, _]


comptime `"` = ast_util.to_byte['"']()
comptime `'` = ast_util.to_byte["'"]()
comptime `{` = ast_util.to_byte["{"]()
comptime `}` = ast_util.to_byte["}"]()
comptime `;` = ast_util.to_byte[";"]()
comptime `+` = ast_util.to_byte["+"]()
comptime `/` = ast_util.to_byte["/"]()
comptime `*` = ast_util.to_byte["*"]()
comptime `\\` = ast_util.to_byte["\\"]()

comptime `\n` = ast_util.to_byte["\n"]()
comptime `\t` = ast_util.to_byte["\t"]()
comptime ` ` = ast_util.to_byte[" "]()
comptime `\r` = ast_util.to_byte["\r"]()


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
        while not self.eof():
            var ch = self.input[self.pos]
            if ch == ` ` or ch == `\n` or ch == `\t` or ch == `\r`:
                if ch == `\n`:
                    self.line += 1
                self.pos += 1
            elif (
                ch == `/`
                and self.pos + 1 < len(self.input)
                and self.input[self.pos + 1] == `/`
            ):
                self.pos += 2
                while not self.eof():
                    var line_ch = self.input[self.pos]
                    if line_ch == `\n` or line_ch == `\r`:
                        break
                    self.pos += 1
            elif (
                ch == `/`
                and self.pos + 1 < len(self.input)
                and self.input[self.pos + 1] == `*`
            ):
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

    def scan_identifier(mut self) raises -> Int:
        var start = self.pos
        while not self.eof():
            var ch = self.input[self.pos]
            if (
                ch == ` `
                or ch == `\n`
                or ch == `\t`
                or ch == `\r`
                or ch == `{`
                or ch == `}`
                or ch == `;`
                or ch == `+`
                or ch == `"`
                or ch == `'`
            ):
                break

            self.pos += 1

        if self.pos == start:
            raise Error("Expected YANG token")

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
        self.skip_ws_and_comments()

        if self.eof():
            return AstToken(
                type=AstToken.EOF, start=self.pos, length=0, line=self.line
            )

        var start = self.pos
        var token_line = self.line
        var ch = self.input[self.pos]

        if ch == `{`:
            self.pos += 1
            return AstToken(
                type=AstToken.LBRACE, start=start, length=1, line=token_line
            )
        if ch == `}`:
            self.pos += 1
            return AstToken(
                type=AstToken.RBRACE, start=start, length=1, line=token_line
            )
        if ch == `;`:
            self.pos += 1
            return AstToken(
                type=AstToken.SEMICOLON, start=start, length=1, line=token_line
            )
        if ch == `+`:
            self.pos += 1
            return AstToken(
                type=AstToken.PLUS, start=start, length=1, line=token_line
            )
        if ch == `"` or ch == `'`:
            return AstToken(
                type=AstToken.STRING,
                start=start,
                length=self.scan_quoted_string(),
                line=token_line,
            )

        var length = self.scan_identifier()
        return AstToken(
            type=AstToken.IDENTIFIER,
            start=start,
            length=length,
            line=token_line,
        )
