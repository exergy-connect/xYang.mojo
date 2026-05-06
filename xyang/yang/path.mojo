## Parser and structure for RFC 7950 YANG path arguments.
##
## Supports absolute and relative schema-node paths plus leafref predicates of
## the form `[key = current()/../target]`.

from std.memory import Span

import xyang.yang.ast.util as ast_util
from xyang.yang.identifiers import is_alpha, is_identifier_char


comptime ByteView = Span[Byte, _]


comptime `/` = ast_util.to_byte["/"]()
comptime `.` = ast_util.to_byte["."]()
comptime `:` = ast_util.to_byte[":"]()
comptime `[` = ast_util.to_byte["["]()
comptime `]` = ast_util.to_byte["]"]()
comptime `=` = ast_util.to_byte["="]()
comptime `(` = ast_util.to_byte["("]()
comptime `)` = ast_util.to_byte[")"]()
comptime ` ` = ast_util.to_byte[" "]()
comptime `\n` = ast_util.to_byte["\n"]()
comptime `\t` = ast_util.to_byte["\t"]()
comptime `\r` = ast_util.to_byte["\r"]()


def _is_ws(ch: Byte) -> Bool:
    return ch == ` ` or ch == `\n` or ch == `\t` or ch == `\r`


def _line_prefix(line: UInt) -> String:
    if line > 0:
        return "line " + String(line) + ": "
    return ""


@fieldwise_init
struct YangQName(Copyable, Movable):
    var text: String
    var prefix: Optional[String]
    var local_name: String

    def has_prefix(read self) -> Bool:
        return self.prefix != None


@fieldwise_init
struct YangPathKeyExpression(Copyable, Movable):
    var text: String
    var parent_steps: Int
    var segments: List[YangQName]


@fieldwise_init
struct YangPathPredicate(Copyable, Movable):
    var text: String
    var key: YangQName
    var target: YangPathKeyExpression


@fieldwise_init
struct YangPathStep(Copyable, Movable):
    var text: String
    var node: YangQName
    var predicates: List[YangPathPredicate]


@fieldwise_init
struct YangPath(Copyable, Movable):
    var text: String
    var absolute: Bool
    var parent_steps: Int
    var segments: List[YangPathStep]


def parse_yang_qname(text: String) raises -> YangQName:
    var bytes = text.as_bytes()
    var parser = YangPathParser(bytes, 0)
    var qname = parser.parse_qname()
    parser.skip_ws()
    if not parser.eof():
        parser.syntax_error("unexpected token after QName")
    return qname^


def parse_yang_path(text: String, line: UInt = 0, allow_absolute: Bool = True) raises -> YangPath:
    var bytes = text.as_bytes()
    var parser = YangPathParser(bytes, line)
    return parser.parse(allow_absolute)


struct YangPathParser[origin: ImmutOrigin]:
    var input: ByteView[Self.origin]
    var pos: Int
    var source_line: UInt

    def __init__(out self, input: ByteView[Self.origin], source_line: UInt):
        self.input = input
        self.pos = 0
        self.source_line = source_line

    def eof(read self) -> Bool:
        return self.pos >= len(self.input)

    def skip_ws(mut self):
        while not self.eof() and _is_ws(self.input[self.pos]):
            self.pos += 1

    def syntax_error(read self, message: String) raises:
        raise Error(
            _line_prefix(self.source_line)
            + "invalid YANG path at byte "
            + String(self.pos)
            + ": "
            + message
        )

    def slice_text(read self, start: Int, end: Int) -> String:
        return String(StringSlice(unsafe_from_utf8=self.input[start:end]))

    def consume(mut self, ch: Byte, message: String) raises:
        self.skip_ws()
        if self.eof() or self.input[self.pos] != ch:
            self.syntax_error(message)
        self.pos += 1

    def starts_parent_ref(read self) -> Bool:
        return (
            self.pos + 2 < len(self.input)
            and self.input[self.pos] == `.`
            and self.input[self.pos + 1] == `.`
            and self.input[self.pos + 2] == `/`
        )

    def consume_key_parent_ref(mut self) raises -> Bool:
        self.skip_ws()
        if (
            self.pos + 1 >= len(self.input)
            or self.input[self.pos] != `.`
            or self.input[self.pos + 1] != `.`
        ):
            return False
        self.pos += 2
        self.consume(`/`, "expected `/` after `..` in path predicate target")
        return True

    def parse(mut self, allow_absolute: Bool = True) raises -> YangPath:
        self.skip_ws()
        var absolute = False
        var parent_steps = 0

        if not self.eof() and self.input[self.pos] == `/`:
            if not allow_absolute:
                self.syntax_error("absolute path not allowed")
            absolute = True
            self.pos += 1
        else:
            while self.starts_parent_ref():
                parent_steps += 1
                self.pos += 3

        var segments = List[YangPathStep]()
        segments.append(self.parse_step())
        while True:
            self.skip_ws()
            if self.eof() or self.input[self.pos] != `/`:
                break
            self.pos += 1
            if self.eof():
                self.syntax_error("path must not end with `/`")
            segments.append(self.parse_step())

        self.skip_ws()
        if not self.eof():
            self.syntax_error("unexpected token after path")
        if absolute and len(segments) == 0:
            self.syntax_error("absolute path requires at least one node")
        return YangPath(
            self.slice_text(0, len(self.input)),
            absolute,
            parent_steps,
            segments^,
        )

    def parse_step(mut self) raises -> YangPathStep:
        self.skip_ws()
        var start = self.pos
        var node = self.parse_qname()
        var predicates = List[YangPathPredicate]()
        while True:
            self.skip_ws()
            if self.eof() or self.input[self.pos] != `[`:
                break
            predicates.append(self.parse_predicate())
        return YangPathStep(
            self.slice_text(start, self.pos), node^, predicates^
        )

    def parse_qname(mut self) raises -> YangQName:
        self.skip_ws()
        var start = self.pos
        self.parse_identifier()
        var prefix = Optional[String]()
        if not self.eof() and self.input[self.pos] == `:`:
            prefix = Optional[String](self.slice_text(start, self.pos))
            self.pos += 1
            self.parse_identifier()
        var text = self.slice_text(start, self.pos)
        var local_start = start
        if prefix:
            local_start += prefix.value().byte_length() + 1
        return YangQName(text^, prefix^, self.slice_text(local_start, self.pos))

    def parse_identifier(mut self) raises:
        if self.eof():
            self.syntax_error("expected identifier")
        if (
            not is_alpha(self.input[self.pos])
            and self.input[self.pos] != ast_util.to_byte["_"]()
        ):
            self.syntax_error("expected identifier")
        self.pos += 1
        while not self.eof() and is_identifier_char(self.input[self.pos]):
            self.pos += 1

    def parse_predicate(mut self) raises -> YangPathPredicate:
        self.skip_ws()
        var start = self.pos
        self.consume(`[`, "expected `[`")
        var key = self.parse_qname()
        self.consume(`=`, "expected `=` in path predicate")
        self.consume_current_call()
        self.consume(`/`, "expected `/` after `current()`")
        var target = self.parse_key_expression()
        self.consume(`]`, "expected `]` after path predicate")
        return YangPathPredicate(
            self.slice_text(start, self.pos), key^, target^
        )

    def consume_current_call(mut self) raises:
        self.skip_ws()
        var literal = "current"
        var bytes = literal.as_bytes()
        for i in range(len(bytes)):
            if self.eof() or self.input[self.pos] != bytes[i]:
                self.syntax_error("expected `current()` in path predicate")
            self.pos += 1
        self.consume(`(`, "expected `(` after `current`")
        self.consume(`)`, "expected `)` after `current(`")

    def parse_key_expression(mut self) raises -> YangPathKeyExpression:
        self.skip_ws()
        var start = self.pos
        var parent_steps = 0
        while self.consume_key_parent_ref():
            parent_steps += 1
            self.skip_ws()
        if parent_steps == 0:
            self.syntax_error("path predicate target must start with `../`")

        var segments = List[YangQName]()
        segments.append(self.parse_qname())
        while True:
            self.skip_ws()
            if self.eof() or self.input[self.pos] != `/`:
                break
            self.pos += 1
            segments.append(self.parse_qname())
        return YangPathKeyExpression(
            self.slice_text(start, self.pos), parent_steps, segments^
        )
