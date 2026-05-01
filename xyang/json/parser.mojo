## Minimal JSON parser (objects, arrays, strings, integers, bool, null).
##

from std.memory import ArcPointer, Span

comptime Arc = ArcPointer
comptime ByteView = Span[Byte, _]

comptime `"` = _to_byte['"']()
comptime `+b` = _to_byte["+"]()
comptime `-` = _to_byte["-"]()
comptime `.b` = _to_byte["."]()
comptime `0b` = _to_byte["0"]()
comptime `9b` = _to_byte["9"]()
comptime `Eb` = _to_byte["E"]()
comptime `eb` = _to_byte["e"]()
comptime `{b` = _to_byte["{"]()
comptime `}b` = _to_byte["}"]()
comptime `[b` = _to_byte["["]()
comptime `]b` = _to_byte["]"]()
comptime `:b` = _to_byte[":"]()
comptime `,b` = _to_byte[","]()
comptime ` b` = _to_byte[" "]()
comptime `\n` = _to_byte["\n"]()
comptime `\r` = _to_byte["\r"]()
comptime `\t` = _to_byte["\t"]()
comptime `\\` = _to_byte["\\"]()


@always_inline
def _to_byte[s: StaticString]() -> Byte:
    comptime assert s.byte_length() == 1, "expected one character string"
    comptime byte = s.as_bytes()[0]
    return byte


@fieldwise_init
struct JsonValue(ImplicitlyDestructible, Movable):
    comptime Kind = UInt8
    comptime OBJECT: Self.Kind = 0
    comptime ARRAY: Self.Kind = 1
    comptime STRING: Self.Kind = 2
    comptime INT: Self.Kind = 3
    comptime BOOL: Self.Kind = 4
    comptime NULL: Self.Kind = 5
    comptime ValueList = List[Arc[JsonValue]]

    var kind: Self.Kind
    var text: String
    var int_value: Int64
    var bool_value: Bool
    var object_keys: List[String]
    var object_values: Self.ValueList
    var array_values: Self.ValueList
    var source_line: Int


def make_json(kind: JsonValue.Kind, source_line: Int = 0) -> JsonValue:
    return JsonValue(
        kind,
        "",
        0,
        False,
        List[String](),
        JsonValue.ValueList(),
        JsonValue.ValueList(),
        source_line,
    )


struct JsonParser[origin: ImmutOrigin]:
    var input: ByteView[Self.origin]
    var pos: Int
    var line: Int
    var source_path: String

    def __init__(
        out self, input: ByteView[Self.origin], source_path: String = ""
    ):
        self.input = input
        self.pos = 0
        self.line = 1
        self.source_path = source_path

    def eof(ref self) -> Bool:
        return self.pos >= len(self.input)

    def skip_ws(mut self):
        while not self.eof():
            var ch = self.input[self.pos]
            if ch == ` b` or ch == `\n` or ch == `\r` or ch == `\t`:
                if ch == `\n`:
                    self.line += 1
                self.pos += 1
            else:
                return

    def syntax_error(self, message: String) raises:
        var prefix = String()
        if self.source_path.byte_length() > 0:
            prefix += self.source_path + " "
        if self.line > 0:
            prefix += "line " + String(self.line) + ": "
        raise Error(prefix + message)

    def consume(mut self, ch: Byte) raises:
        self.skip_ws()
        if self.eof() or self.input[self.pos] != ch:
            self.syntax_error(
                "Unexpected JSON token at byte " + String(self.pos)
            )
        self.pos += 1

    def consume_literal(mut self, literal: String) raises:
        var bytes = literal.as_bytes()
        for i in range(len(bytes)):
            if self.eof() or self.input[self.pos] != bytes[i]:
                self.syntax_error("Expected JSON literal `" + literal + "`")
            self.pos += 1

    def parse_string(mut self) raises -> String:
        self.consume(`"`)
        var out = String()
        while not self.eof():
            var ch = self.input[self.pos]
            self.pos += 1
            if ch == `\n`:
                self.line += 1
            if ch == `"`:
                return out^
            if ch == `\\`:
                if self.eof():
                    self.syntax_error("Trailing escape in JSON string")
                var escaped = self.input[self.pos]
                self.pos += 1
                if escaped == _to_byte["n"]():
                    out += "\n"
                elif escaped == _to_byte["r"]():
                    out += "\r"
                elif escaped == _to_byte["t"]():
                    out += "\t"
                else:
                    out += String(
                        StringSlice(
                            unsafe_from_utf8=self.input[self.pos - 1 : self.pos]
                        )
                    )
            else:
                out += String(
                    StringSlice(
                        unsafe_from_utf8=self.input[self.pos - 1 : self.pos]
                    )
                )
        self.syntax_error("Unterminated JSON string")
        return ""

    def parse_number(mut self) raises -> JsonValue:
        self.skip_ws()
        var ln = self.line
        var start = self.pos
        if self.input[self.pos] == `-`:
            self.pos += 1
        while (
            not self.eof()
            and self.input[self.pos] >= `0b`
            and self.input[self.pos] <= `9b`
        ):
            self.pos += 1
        if not self.eof() and self.input[self.pos] == `.b`:
            self.pos += 1
            while (
                not self.eof()
                and self.input[self.pos] >= `0b`
                and self.input[self.pos] <= `9b`
            ):
                self.pos += 1
        if not self.eof() and (
            self.input[self.pos] == `eb` or self.input[self.pos] == `Eb`
        ):
            self.pos += 1
            if not self.eof() and (
                self.input[self.pos] == `+b` or self.input[self.pos] == `-`
            ):
                self.pos += 1
            while (
                not self.eof()
                and self.input[self.pos] >= `0b`
                and self.input[self.pos] <= `9b`
            ):
                self.pos += 1
        var text = String(
            StringSlice(unsafe_from_utf8=self.input[start : self.pos])
        )
        var value = make_json(JsonValue.INT, ln)
        value.text = text
        if (
            text.find(".") == -1
            and text.find("e") == -1
            and text.find("E") == -1
        ):
            value.int_value = Int64(atol(text))
        return value^

    def parse_array(mut self) raises -> JsonValue:
        var ln = self.line
        self.consume(`[b`)
        var value = make_json(JsonValue.ARRAY, ln)
        self.skip_ws()
        if not self.eof() and self.input[self.pos] == `]b`:
            self.pos += 1
            return value^
        while True:
            value.array_values.append(Arc[JsonValue](self.parse_value()))
            self.skip_ws()
            if not self.eof() and self.input[self.pos] == `,b`:
                self.pos += 1
                continue
            self.consume(`]b`)
            return value^

    def parse_object(mut self) raises -> JsonValue:
        var ln = self.line
        self.consume(`{b`)
        var value = make_json(JsonValue.OBJECT, ln)
        self.skip_ws()
        if not self.eof() and self.input[self.pos] == `}b`:
            self.pos += 1
            return value^
        while True:
            var key = self.parse_string()
            self.consume(`:b`)
            value.object_keys.append(key^)
            value.object_values.append(Arc[JsonValue](self.parse_value()))
            self.skip_ws()
            if not self.eof() and self.input[self.pos] == `,b`:
                self.pos += 1
                continue
            self.consume(`}b`)
            return value^

    def parse_value(mut self) raises -> JsonValue:
        self.skip_ws()
        if self.eof():
            self.syntax_error("Unexpected EOF in JSON")
        var ch = self.input[self.pos]
        var ln = self.line
        if ch == `{b`:
            return self.parse_object()
        if ch == `[b`:
            return self.parse_array()
        if ch == `"`:
            var value = make_json(JsonValue.STRING, ln)
            value.text = self.parse_string()
            return value^
        if ch == `-` or (ch >= `0b` and ch <= `9b`):
            return self.parse_number()
        if ch == _to_byte["t"]():
            self.consume_literal("true")
            var value = make_json(JsonValue.BOOL, ln)
            value.bool_value = True
            return value^
        if ch == _to_byte["f"]():
            self.consume_literal("false")
            var value = make_json(JsonValue.BOOL, ln)
            value.bool_value = False
            return value^
        if ch == _to_byte["n"]():
            self.consume_literal("null")
            return make_json(JsonValue.NULL, ln)
        self.syntax_error("Unexpected JSON token at byte " + String(self.pos))
        return make_json(JsonValue.NULL, ln)


def parse_json(source: String, source_path: String = "") raises -> JsonValue:
    """Parse a single JSON value from `source`; trailing whitespace allowed."""
    var parser = JsonParser(source.as_bytes(), source_path)
    var root = parser.parse_value()
    parser.skip_ws()
    if not parser.eof():
        parser.syntax_error(
            "Trailing data after JSON value at byte " + String(parser.pos)
        )
    return root^


def json_get(read obj: JsonValue, key: String) -> Optional[Arc[JsonValue]]:
    for i in range(len(obj.object_keys)):
        if obj.object_keys[i] == key:
            return Optional[Arc[JsonValue]](obj.object_values[i].copy())
    return Optional[Arc[JsonValue]]()


def json_scalar_text(read value: JsonValue) -> String:
    if value.kind == JsonValue.STRING or value.kind == JsonValue.INT:
        return value.text
    if value.kind == JsonValue.BOOL:
        return "true" if value.bool_value else "false"
    return "<non-scalar>"
