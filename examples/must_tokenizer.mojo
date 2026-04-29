from std.collections import Dict


@fieldwise_init
struct Token:
    var kind: String
    var text: String

    def __str__(ref self) -> String:
        return self.kind + "(" + self.text + ")"

comptime CP_MINUS = Codepoint.ord("-")


struct Lexer:
    var input: String
    var pos: Int
    var field_index_tables: Dict[String, Dict[String, Int]]

    def __init__(out self, input: String):
        self.input = input
        self.pos = 0
        self.field_index_tables = Dict[String, Dict[String, Int]]()

    def __init__(out self, *, file_path: String) raises:
        with open(file_path, "r") as f:
            self.input = f.read()
        self.pos = 0
        self.field_index_tables = Dict[String, Dict[String, Int]]()

    @staticmethod
    def from_file(file_path: String) raises -> Self:
        return Self(file_path=file_path)

    def get_field_index_table(
        mut self,
        field_name: String,
        populate_method: def(out Dict[String, Int]) thin,
    ) raises -> Dict[String, Int]:
        if field_name not in self.field_index_tables:
            var field_table = populate_method()
            self.field_index_tables[field_name] = field_table^
        return self.field_index_tables[field_name].copy()

    def eof(ref self) -> Bool:
        return self.pos >= self.input.byte_length()

    def peek(ref self) raises -> String:
        if self.eof():
            raise Error("Unexpected end of input")
        return String(self.input[byte=self.pos : self.pos + 1])

    def bump(mut self) raises -> String:
        var ch = self.peek()
        self.pos += 1
        return ch

    def skip_ws(mut self):
        while not self.eof():
            var ch = String(self.input[byte=self.pos : self.pos + 1])
            if ch == " " or ch == "\n" or ch == "\t" or ch == "\r":
                self.pos += 1
            elif (
                ch == "/"
                and self.pos + 1 < self.input.byte_length()
                and String(self.input[byte=self.pos + 1 : self.pos + 2]) == "/"
            ):
                self.pos += 2
                while not self.eof():
                    var line_ch = String(self.input[byte=self.pos : self.pos + 1])
                    if line_ch == "\n" or line_ch == "\r":
                        break
                    self.pos += 1
            elif (
                ch == "/"
                and self.pos + 1 < self.input.byte_length()
                and String(self.input[byte=self.pos + 1 : self.pos + 2]) == "*"
            ):
                self.pos += 2
                while not self.eof():
                    if (
                        String(self.input[byte=self.pos : self.pos + 1]) == "*"
                        and self.pos + 1 < self.input.byte_length()
                        and String(self.input[byte=self.pos + 1 : self.pos + 2]) == "/"
                    ):
                        self.pos += 2
                        break
                    self.pos += 1
            else:
                return
    
    def skip_if(mut self, ch: String) raises -> Bool:
        self.skip_ws()
        if self.eof():
            return False
        if self.peek() == ch:
            _ = self.bump()
            return True
        return False

    def read_ident(mut self) raises -> String:
        var result = String()

        while not self.eof():
            var ch = String(self.input[byte=self.pos : self.pos + 1])

            if (
                (ch >= "a" and ch <= "z")
                or (ch >= "A" and ch <= "Z")
                or (ch >= "0" and ch <= "9")
                or ch == "-"
                or ch == "_"
                or ch == ":"
                or ch == "/"
                or ch == "."
            ):
                result += ch
                self.pos += 1
            else:
                break

        if result.byte_length() == 0:
            raise Error("Expected identifier")

        return result

    def _is_integer_lexeme(ref self, text: String) -> Bool:
        if text.byte_length() == 0:
            return False
        var i = 0
        var saw_digit = False
        for ch in text.codepoints():
            if i == 0 and ch == CP_MINUS:
                i += 1
                continue
            if not ch.is_ascii_digit():
                return False
            saw_digit = True
            i += 1
        return saw_digit

    def read_quoted_string(mut self) raises -> String:
        var quote = self.bump()
        var result = String()

        while not self.eof():
            var rest = String(self.input[byte=self.pos:])
            var consumed_codepoint = False
            for cp_slice in rest.codepoint_slices():
                var ch = String(cp_slice)
                self.pos += cp_slice.byte_length()
                consumed_codepoint = True

                if ch == quote:
                    return result

                # Minimal escape handling, consuming one full UTF-8 codepoint.
                if ch == "\\":
                    if self.eof():
                        raise Error("Trailing escape in string literal")

                    var escape_rest = String(self.input[byte=self.pos:])
                    var consumed_escape = False
                    for escaped_slice in escape_rest.codepoint_slices():
                        var escaped = String(escaped_slice)
                        self.pos += escaped_slice.byte_length()
                        consumed_escape = True

                        if escaped == "n":
                            result += "\n"
                        elif escaped == "t":
                            result += "\t"
                        elif escaped == "r":
                            result += "\r"
                        else:
                            result += escaped
                        break

                    if not consumed_escape:
                        raise Error("Trailing escape in string literal")
                else:
                    result += ch
                break

            if not consumed_codepoint:
                break

        raise Error("Unterminated string literal")

    def next_token(mut self) raises -> Token:
        self.skip_ws()

        if self.eof():
            return Token(kind="eof", text="")

        var ch = self.peek()

        if ch == "{":
            _ = self.bump()
            return Token(kind="{", text="{")

        if ch == "}":
            _ = self.bump()
            return Token(kind="}", text="}")

        if ch == ";":
            _ = self.bump()
            return Token(kind=";", text=";")

        if ch == "+":
            _ = self.bump()
            return Token(kind="+", text="+")

        if ch == "\"" or ch == "'":
            return Token(kind="string", text=self.read_quoted_string())

        var text = self.read_ident()
        if text == "true" or text == "false":
            return Token(kind="bool", text=text)
        if self._is_integer_lexeme(text):
            return Token(kind="int", text=text)
        return Token(kind="ident", text=text)

    def next(mut self) raises -> String:
        return self.next_token().text

    def expect(mut self, expected: String) raises:
        var tok = self.next_token()
        if tok.kind != expected and tok.text != expected:
            raise Error("Expected `" + expected + "`, got `" + tok.text + "`")

    def expect_ident(mut self) raises -> String:
        var tok = self.next_token()
        if tok.kind != "ident":
            raise Error("Expected identifier, got `" + tok.text + "`")
        return tok.text

    def expect_arg(mut self) raises -> String:
        var tok = self.next_token()
        if tok.kind == "ident" or tok.kind == "string" or tok.kind == "int" or tok.kind == "bool":
            return tok.text

        raise Error("Expected argument, got `" + tok.text + "`")

    def expect_string(mut self) raises -> String:
        var tok = self.next_token()
        if tok.kind == "string" or tok.kind == "ident":
            return tok.text
        raise Error("Expected string argument, got `" + tok.text + "`")

    def expect_int(mut self) raises -> Int:
        var tok = self.next_token()
        if tok.kind == "int":
            return atol(tok.text)
        raise Error("Expected integer argument, got `" + tok.text + "`")

    def expect_bool(mut self) raises -> Bool:
        var tok = self.next_token()
        if tok.kind == "bool":
            return tok.text == "true"
        raise Error("Expected boolean argument, got `" + tok.text + "`")

    def skip_statement_tail(mut self) raises:
        var depth = 0

        while True:
            var tok = self.next_token()

            if tok.kind == "eof":
                raise Error("Unexpected end of input while skipping statement")

            if tok.kind == "{":
                depth += 1
                continue

            if tok.kind == "}":
                if depth == 0:
                    return
                depth -= 1
                if depth == 0:
                    return
                continue

            if tok.kind == ";" and depth == 0:
                return
