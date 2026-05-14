## Minimal JSON parser (objects, arrays, strings, numbers, bool, null).
##

from std.memory import ArcPointer, Span

import xyang.yang.ast.util as ast_util

from .value import (
    JsonArray,
    JsonBool,
    JsonInt,
    JsonNull,
    JsonObject,
    JsonPayload,
    JsonReal,
    JsonString,
    JsonValue,
)

comptime Arc = ArcPointer
comptime ByteView = Span[Byte, _]

comptime `"` = ast_util.to_byte['"']()
comptime `+b` = ast_util.to_byte["+"]()
comptime `-` = ast_util.to_byte["-"]()
comptime `.b` = ast_util.to_byte["."]()
comptime `0b` = ast_util.to_byte["0"]()
comptime `9b` = ast_util.to_byte["9"]()
comptime `Eb` = ast_util.to_byte["E"]()
comptime `eb` = ast_util.to_byte["e"]()
comptime `{b` = ast_util.to_byte["{"]()
comptime `}b` = ast_util.to_byte["}"]()
comptime `[b` = ast_util.to_byte["["]()
comptime `]b` = ast_util.to_byte["]"]()
comptime `:b` = ast_util.to_byte[":"]()
comptime `,b` = ast_util.to_byte[","]()
comptime ` b` = ast_util.to_byte[" "]()
comptime `\n` = ast_util.to_byte["\n"]()
comptime `\r` = ast_util.to_byte["\r"]()
comptime `\t` = ast_util.to_byte["\t"]()
comptime `\\` = ast_util.to_byte["\\"]()


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
                if escaped == ast_util.to_byte["n"]():
                    out += "\n"
                elif escaped == ast_util.to_byte["r"]():
                    out += "\r"
                elif escaped == ast_util.to_byte["t"]():
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
        var is_real = False
        if self.input[self.pos] == `-`:
            self.pos += 1
        while (
            not self.eof()
            and self.input[self.pos] >= `0b`
            and self.input[self.pos] <= `9b`
        ):
            self.pos += 1
        if not self.eof() and self.input[self.pos] == `.b`:
            is_real = True
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
            is_real = True
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
        if is_real:
            return JsonValue(JsonValue.REAL, JsonPayload(JsonReal(text=text^)), ln)
        return JsonValue(
            JsonValue.INT, JsonPayload(JsonInt(value=Int64(atol(text)), text=text^)), ln
        )

    def parse_array(mut self) raises -> JsonValue:
        var ln = self.line
        self.consume(`[b`)
        var items = List[Arc[JsonValue]]()
        self.skip_ws()
        if not self.eof() and self.input[self.pos] == `]b`:
            self.pos += 1
            return JsonValue(
                JsonValue.ARRAY, JsonPayload(JsonArray(values=items^)), ln
            )
        while True:
            items.append(Arc[JsonValue](self.parse_value()))
            self.skip_ws()
            if not self.eof() and self.input[self.pos] == `,b`:
                self.pos += 1
                continue
            self.consume(`]b`)
            return JsonValue(
                JsonValue.ARRAY, JsonPayload(JsonArray(values=items^)), ln
            )

    def parse_object(mut self) raises -> JsonValue:
        var ln = self.line
        self.consume(`{b`)
        var keys = List[String]()
        var values = List[Arc[JsonValue]]()
        self.skip_ws()
        if not self.eof() and self.input[self.pos] == `}b`:
            self.pos += 1
            return JsonValue(
                JsonValue.OBJECT,
                JsonPayload(JsonObject(keys=keys^, values=values^)),
                ln,
            )
        while True:
            var key = self.parse_string()
            self.consume(`:b`)
            keys.append(key^)
            values.append(Arc[JsonValue](self.parse_value()))
            self.skip_ws()
            if not self.eof() and self.input[self.pos] == `,b`:
                self.pos += 1
                continue
            self.consume(`}b`)
            return JsonValue(
                JsonValue.OBJECT,
                JsonPayload(JsonObject(keys=keys^, values=values^)),
                ln,
            )

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
            return JsonValue(
                JsonValue.STRING,
                JsonPayload(JsonString(value=self.parse_string())),
                ln,
            )
        if ch == `-` or (ch >= `0b` and ch <= `9b`):
            return self.parse_number()
        if ch == ast_util.to_byte["t"]():
            self.consume_literal("true")
            return JsonValue(
                JsonValue.BOOL, JsonPayload(JsonBool(value=True)), ln
            )
        if ch == ast_util.to_byte["f"]():
            self.consume_literal("false")
            return JsonValue(
                JsonValue.BOOL, JsonPayload(JsonBool(value=False)), ln
            )
        if ch == ast_util.to_byte["n"]():
            self.consume_literal("null")
            return JsonValue(
                JsonValue.NULL, JsonPayload(JsonNull()), ln
            )
        self.syntax_error("Unexpected JSON token at byte " + String(self.pos))
        return JsonValue(
            JsonValue.NULL, JsonPayload(JsonNull()), ln
        )


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


