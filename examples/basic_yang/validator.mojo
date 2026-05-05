## Standalone table-driven validator for `basic-device.yang`.
##
## The YANG file is parsed through the generic construct tree from
## `examples/ast.mojo`, then validated with the same compile-time lookup-table
## style used by `examples/lookup_table_subset.mojo`. A tiny JSON parser is
## included so the example stays self-contained aside from shared `to_byte` from
## `xyang.yang.ast.util`.
##
##   pixi run mojo -I . -I examples examples/basic_yang/validator.mojo

from std.memory import ArcPointer, Span, UnsafePointer

import xyang.yang.ast.util as ast_util
from ast import AstLexer, YangConstruct, parse_module

comptime Arc = ArcPointer
comptime ByteView = Span[Byte, _]

comptime YANG_PATH = "examples/basic_yang/basic-device.yang"
comptime DATA_PATH = "examples/basic_yang/basic-device.json"

comptime `"` = ast_util.to_byte['"']()
comptime `-` = ast_util.to_byte["-"]()
comptime `0b` = ast_util.to_byte["0"]()
comptime `9b` = ast_util.to_byte["9"]()
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


comptime Kw = UInt8
comptime `module`: Kw = 0
comptime `yang-version`: Kw = 1
comptime `namespace`: Kw = 2
comptime `prefix`: Kw = 3
comptime `organization`: Kw = 4
comptime `contact`: Kw = 5
comptime `description`: Kw = 6
comptime `revision`: Kw = 7
comptime `grouping`: Kw = 8
comptime `uses`: Kw = 9
comptime `container`: Kw = 10
comptime `list`: Kw = 11
comptime `key`: Kw = 12
comptime `leaf`: Kw = 13
comptime `type`: Kw = 14
comptime `range-stmt`: Kw = 15
comptime `path`: Kw = 16
comptime `default`: Kw = 17
comptime `must`: Kw = 18
comptime `error-message`: Kw = 19
comptime `when`: Kw = 20

comptime KEYWORD_COUNT: Int = 21
comptime SPELLING: InlineArray[String, KEYWORD_COUNT] = [
    "module",
    "yang-version",
    "namespace",
    "prefix",
    "organization",
    "contact",
    "description",
    "revision",
    "grouping",
    "uses",
    "container",
    "list",
    "key",
    "leaf",
    "type",
    "range",
    "path",
    "default",
    "must",
    "error-message",
    "when",
]

comptime Cardinality = UInt8
comptime `0`: Cardinality = 0
comptime `1`: Cardinality = 1
comptime `0..1`: Cardinality = 2
comptime `0..n`: Cardinality = 3
comptime `1..n`: Cardinality = 4


def keyword_spelling(idx: Kw) -> String:
    return SPELLING[Int(idx)]


def keyword_id(name: String, line: Int = 0) raises -> Kw:
    for i in range(KEYWORD_COUNT):
        if name == SPELLING[i]:
            return Kw(i)
    raise Error(line_prefix(line) + "Unknown YANG keyword `" + name + "`")


def check_cardinality(
    name: String, card: Cardinality, count: Int, line: Int = 0
) raises:
    if card == `0` and count != 0:
        raise Error(
            line_prefix(line)
            + "`"
            + name
            + "` must not appear, found "
            + String(count)
        )
    if card == `1` and count != 1:
        raise Error(
            line_prefix(line)
            + "`"
            + name
            + "` must appear exactly once, found "
            + String(count)
        )
    if card == `0..1` and count > 1:
        raise Error(
            line_prefix(line)
            + "`"
            + name
            + "` may appear at most once, found "
            + String(count)
        )
    if card == `1..n` and count < 1:
        raise Error(
            line_prefix(line) + "`" + name + "` must appear at least once"
        )


def is_digit(ch: Byte) -> Bool:
    return ch >= `0b` and ch <= `9b`


def is_alpha(ch: Byte) -> Bool:
    return (
        ch >= ast_util.to_byte["a"]() and ch <= ast_util.to_byte["z"]()
    ) or (ch >= ast_util.to_byte["A"]() and ch <= ast_util.to_byte["Z"]())


def is_identifier_char(ch: Byte) -> Bool:
    return (
        is_alpha(ch)
        or is_digit(ch)
        or ch == `-`
        or ch == ast_util.to_byte["_"]()
    )


def is_identifier(text: String) -> Bool:
    var bytes = text.as_bytes()
    if len(bytes) == 0:
        return False
    if not is_alpha(bytes[0]) and bytes[0] != ast_util.to_byte["_"]():
        return False
    for i in range(1, len(bytes)):
        if not is_identifier_char(bytes[i]):
            return False
    return True


def is_qname(text: String) -> Bool:
    var parts = text.split(":")
    if len(parts) == 1:
        return is_identifier(String(parts[0]))
    if len(parts) == 2:
        return is_identifier(String(parts[0])) and is_identifier(
            String(parts[1])
        )
    return False


def is_revision_date(text: String) -> Bool:
    var bytes = text.as_bytes()
    if len(bytes) != 10:
        return False
    for i in range(len(bytes)):
        if i == 4 or i == 7:
            if bytes[i] != `-`:
                return False
        elif not is_digit(bytes[i]):
            return False
    return True


def is_supported_type_name(text: String) -> Bool:
    return (
        text == "string"
        or text == "boolean"
        or text == "uint16"
        or text == "leafref"
        or is_qname(text)
    )


comptime ArgumentValidator = def(
    name: String, argument: String, line: Int
) raises thin -> None


def line_prefix(line: Int) -> String:
    if line > 0:
        return "line " + String(line) + ": "
    return ""


def json_line_prefix(json_path: String, line: Int) -> String:
    var prefix = String()
    if json_path.byte_length() > 0:
        prefix += json_path + " "
    if line > 0:
        prefix += "line " + String(line) + ": "
    return prefix


def validate_yang_any(name: String, argument: String, line: Int) raises -> None:
    return


def validate_yang_string(
    name: String, argument: String, line: Int
) raises -> None:
    return


def validate_yang_identifier(
    name: String, argument: String, line: Int
) raises -> None:
    if not is_identifier(argument):
        raise Error(
            line_prefix(line) + "`" + name + "` expected identifier argument"
        )


def validate_yang_qname(
    name: String, argument: String, line: Int
) raises -> None:
    if not is_qname(argument):
        raise Error(
            line_prefix(line)
            + "`"
            + name
            + "` expected identifier or prefixed identifier"
        )


def validate_yang_version(
    name: String, argument: String, line: Int
) raises -> None:
    if argument != "1" and argument != "1.1":
        raise Error(
            line_prefix(line) + "`" + name + "` expected YANG version 1 or 1.1"
        )


def validate_yang_revision_date(
    name: String, argument: String, line: Int
) raises -> None:
    if not is_revision_date(argument):
        raise Error(
            line_prefix(line)
            + "`"
            + name
            + "` expected revision date YYYY-MM-DD"
        )


def validate_yang_range(
    name: String, argument: String, line: Int
) raises -> None:
    if len(argument.split("..")) != 2:
        raise Error(
            line_prefix(line) + "`" + name + "` expected basic range expression"
        )


def validate_yang_path(
    name: String, argument: String, line: Int
) raises -> None:
    if argument.byte_length() == 0:
        raise Error(
            line_prefix(line) + "`" + name + "` expected non-empty path"
        )


def validate_yang_type_name(
    name: String, argument: String, line: Int
) raises -> None:
    if not is_supported_type_name(argument):
        raise Error(
            line_prefix(line) + "`" + name + "` expected basic YANG type name"
        )


def validate_yang_expression(
    name: String, argument: String, line: Int
) raises -> None:
    if argument.byte_length() == 0:
        raise Error(
            line_prefix(line) + "`" + name + "` expected non-empty expression"
        )


def validate_yang_bool(
    name: String, argument: String, line: Int
) raises -> None:
    if argument != "true" and argument != "false":
        raise Error(
            line_prefix(line) + "`" + name + "` expected boolean argument"
        )


@fieldwise_init
struct FieldRule(Copyable, ImplicitlyCopyable, Movable):
    var cardinality: Cardinality


comptime RuleTable = InlineArray[FieldRule, KEYWORD_COUNT]
comptime FIELD = Tuple[Kw, Cardinality]


def fields[n: Int](*fieldlist: FIELD) -> RuleTable:
    var table = InlineArray[FieldRule, KEYWORD_COUNT](fill=FieldRule(`0`))
    comptime for i in range(n):
        table[Int(fieldlist[i][0])] = FieldRule(fieldlist[i][1])
    return table


struct YangConstructSpec(Copyable, ImplicitlyCopyable, Movable):
    comptime Table = InlineArray[Self, KEYWORD_COUNT]
    comptime Validate = def(
        UnsafePointer[Self, ImmutAnyOrigin],
        read YangConstruct,
        UnsafePointer[Self.Table, ImmutAnyOrigin],
    ) raises thin -> None

    var parent: Kw
    var argument_type: ArgumentValidator
    var allowed_fields: RuleTable
    var validate: Self.Validate

    def __init__(
        out self,
        parent: Kw,
        argument_type: ArgumentValidator,
        allowed_fields: RuleTable,
        validate: Self.Validate = validate_construct_callback,
    ):
        self.parent = parent
        self.argument_type = argument_type
        self.allowed_fields = allowed_fields
        self.validate = validate


comptime SpecTable = YangConstructSpec.Table


def scalar_spec(
    parent: Kw, argument_type: ArgumentValidator
) -> YangConstructSpec:
    return YangConstructSpec(
        parent,
        argument_type,
        fields[0](),
        validate_scalar_construct_callback,
    )


comptime MODULE_SPEC = YangConstructSpec(
    `module`,
    validate_yang_identifier,
    fields[9](
        (`yang-version`, `0..1`),
        (`namespace`, `1`),
        (`prefix`, `1`),
        (`organization`, `0..1`),
        (`contact`, `0..1`),
        (`description`, `0..1`),
        (`revision`, `0..n`),
        (`grouping`, `0..n`),
        (`container`, `1..n`),
    ),
)
comptime CONTAINER_SPEC = YangConstructSpec(
    `container`,
    validate_yang_identifier,
    fields[5](
        (`description`, `0..1`),
        (`uses`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`list`, `0..n`),
    ),
)
comptime LIST_SPEC = YangConstructSpec(
    `list`,
    validate_yang_identifier,
    fields[7](
        (`must`, `0..n`),
        (`key`, `0..1`),
        (`description`, `0..1`),
        (`uses`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`list`, `0..n`),
    ),
)
comptime LEAF_SPEC = YangConstructSpec(
    `leaf`,
    validate_yang_identifier,
    fields[5](
        (`when`, `0..1`),
        (`type`, `1`),
        (`must`, `0..n`),
        (`default`, `0..1`),
        (`description`, `0..1`),
    ),
)
comptime TYPE_SPEC = YangConstructSpec(
    `type`,
    validate_yang_type_name,
    fields[2](
        (`path`, `0..1`),
        (`range-stmt`, `0..1`),
    ),
)
comptime GROUPING_SPEC = YangConstructSpec(
    `grouping`,
    validate_yang_identifier,
    fields[5](
        (`description`, `0..1`),
        (`uses`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`list`, `0..n`),
    ),
)
comptime REVISION_SPEC = YangConstructSpec(
    `revision`,
    validate_yang_revision_date,
    fields[1]((`description`, `0..1`)),
)
comptime MUST_SPEC = YangConstructSpec(
    `must`,
    validate_yang_expression,
    fields[2](
        (`error-message`, `0..1`),
        (`description`, `0..1`),
    ),
)


def build_spec_table() -> SpecTable:
    var specs = SpecTable(fill=scalar_spec(`module`, validate_yang_identifier))
    specs[`module`] = MODULE_SPEC
    specs[`yang-version`] = scalar_spec(`yang-version`, validate_yang_version)
    specs[Int(`namespace`)] = scalar_spec(`namespace`, validate_yang_string)
    specs[Int(`prefix`)] = scalar_spec(`prefix`, validate_yang_identifier)
    specs[Int(`organization`)] = scalar_spec(
        `organization`, validate_yang_string
    )
    specs[Int(`contact`)] = scalar_spec(`contact`, validate_yang_string)
    specs[Int(`description`)] = scalar_spec(`description`, validate_yang_string)
    specs[Int(`revision`)] = REVISION_SPEC
    specs[Int(`grouping`)] = GROUPING_SPEC
    specs[Int(`uses`)] = scalar_spec(`uses`, validate_yang_qname)
    specs[Int(`container`)] = CONTAINER_SPEC
    specs[Int(`list`)] = LIST_SPEC
    specs[Int(`key`)] = scalar_spec(`key`, validate_yang_identifier)
    specs[Int(`leaf`)] = LEAF_SPEC
    specs[Int(`type`)] = TYPE_SPEC
    specs[Int(`range-stmt`)] = scalar_spec(`range-stmt`, validate_yang_range)
    specs[Int(`path`)] = scalar_spec(`path`, validate_yang_path)
    specs[Int(`default`)] = scalar_spec(`default`, validate_yang_string)
    specs[Int(`must`)] = MUST_SPEC
    specs[Int(`error-message`)] = scalar_spec(
        `error-message`, validate_yang_string
    )
    specs[Int(`when`)] = scalar_spec(`when`, validate_yang_expression)
    return specs


def validate_construct(
    read spec: YangConstructSpec,
    read node: YangConstruct,
    read specs: SpecTable,
) raises:
    var expected_name = keyword_spelling(spec.parent)
    if node.keyword != expected_name:
        raise Error(
            line_prefix(node.line)
            + "Expected `"
            + expected_name
            + "`, got `"
            + node.keyword
            + "`"
        )
    if not node.argument:
        raise Error(
            line_prefix(node.line)
            + "Expected argument for `"
            + expected_name
            + "`"
        )
    spec.argument_type(node.keyword, node.argument.value(), node.line)

    var counts = InlineArray[Int, KEYWORD_COUNT](fill=0)
    for child in node.children:
        var child_kw = keyword_id(child[].keyword, child[].line)
        var rule = spec.allowed_fields[Int(child_kw)]
        if rule.cardinality == `0`:
            raise Error(
                line_prefix(child[].line)
                + "Unknown substatement `"
                + child[].keyword
                + "` in `"
                + expected_name
                + "`"
            )
        counts[Int(child_kw)] += 1

    for i in range(KEYWORD_COUNT):
        check_cardinality(
            keyword_spelling(Kw(i)),
            spec.allowed_fields[i].cardinality,
            counts[i],
            node.line,
        )

    for child in node.children:
        var child_kw = keyword_id(child[].keyword, child[].line)
        ref child_spec = specs[Int(child_kw)]
        if not child[].argument:
            raise Error(
                line_prefix(child[].line)
                + "Expected argument for `"
                + child[].keyword
                + "`"
            )
        child_spec.argument_type(
            child[].keyword, child[].argument.value(), child[].line
        )
        if spec_has_allowed_fields(child_spec) or len(child[].children) != 0:
            var child_spec_ptr = UnsafePointer(
                to=child_spec
            ).unsafe_origin_cast[ImmutAnyOrigin]()
            var nested_specs_ptr = UnsafePointer(to=specs).unsafe_origin_cast[
                ImmutAnyOrigin
            ]()
            child_spec_ptr[].validate(child_spec_ptr, child[], nested_specs_ptr)


def validate_construct_callback(
    spec_ptr: UnsafePointer[YangConstructSpec, ImmutAnyOrigin],
    read node: YangConstruct,
    specs_ptr: UnsafePointer[SpecTable, ImmutAnyOrigin],
) raises -> None:
    validate_construct(spec_ptr[], node, specs_ptr[])


def spec_has_allowed_fields(read spec: YangConstructSpec) -> Bool:
    for i in range(KEYWORD_COUNT):
        if spec.allowed_fields[i].cardinality != `0`:
            return True
    return False


def validate_scalar_construct_callback(
    spec_ptr: UnsafePointer[YangConstructSpec, ImmutAnyOrigin],
    read node: YangConstruct,
    specs_ptr: UnsafePointer[SpecTable, ImmutAnyOrigin],
) raises -> None:
    raise Error(
        line_prefix(node.line)
        + "Unexpected recursive validation for scalar `"
        + node.keyword
        + "`"
    )


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
        raise Error(json_line_prefix(self.source_path, self.line) + message)

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
                self.pos += 1
            out += String(
                StringSlice(
                    unsafe_from_utf8=self.input[self.pos - 1 : self.pos]
                )
            )
        self.syntax_error("Unterminated JSON string")
        return ""

    def parse_int(mut self) raises -> JsonValue:
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
        var text = String(
            StringSlice(unsafe_from_utf8=self.input[start : self.pos])
        )
        var value = make_json(JsonValue.INT, ln)
        value.text = text
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
            return self.parse_int()
        if ch == ast_util.to_byte["t"]():
            self.consume_literal("true")
            var value = make_json(JsonValue.BOOL, ln)
            value.bool_value = True
            return value^
        if ch == ast_util.to_byte["f"]():
            self.consume_literal("false")
            var value = make_json(JsonValue.BOOL, ln)
            value.bool_value = False
            return value^
        if ch == ast_util.to_byte["n"]():
            self.consume_literal("null")
            return make_json(JsonValue.NULL, ln)
        self.syntax_error("Unexpected JSON token at byte " + String(self.pos))
        return make_json(JsonValue.NULL, ln)


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


def find_child(
    read node: YangConstruct, keyword: String
) -> Optional[Arc[YangConstruct]]:
    for child in node.children:
        if child[].keyword == keyword:
            return Optional[Arc[YangConstruct]](child.copy())
    return Optional[Arc[YangConstruct]]()


def find_grouping(
    read module: YangConstruct, name: String
) -> Optional[Arc[YangConstruct]]:
    for child in module.children:
        if (
            child[].keyword == "grouping"
            and child[].argument
            and child[].argument.value() == name
        ):
            return Optional[Arc[YangConstruct]](child.copy())
    return Optional[Arc[YangConstruct]]()


def is_leaf_name_in_uses(
    read module: YangConstruct, read parent: YangConstruct, name: String
) -> Bool:
    for child in parent.children:
        if child[].keyword != "uses" or not child[].argument:
            continue
        var grouping = find_grouping(module, child[].argument.value())
        if not grouping:
            continue
        for gchild in grouping.value()[].children:
            if (
                gchild[].keyword == "leaf"
                and gchild[].argument
                and gchild[].argument.value() == name
            ):
                return True
    return False


def find_effective_leaf(
    read module: YangConstruct,
    read parent: YangConstruct,
    name: String,
) -> Optional[Arc[YangConstruct]]:
    for child in parent.children:
        if (
            child[].keyword == "leaf"
            and child[].argument
            and child[].argument.value() == name
        ):
            return Optional[Arc[YangConstruct]](child.copy())
    for child in parent.children:
        if child[].keyword != "uses" or not child[].argument:
            continue
        var grouping = find_grouping(module, child[].argument.value())
        if not grouping:
            continue
        var leaf = find_effective_leaf(module, grouping.value()[], name)
        if leaf:
            return leaf^
    return Optional[Arc[YangConstruct]]()


def find_effective_child(
    read module: YangConstruct,
    read parent: YangConstruct,
    keyword: String,
    name: String,
) -> Optional[Arc[YangConstruct]]:
    for child in parent.children:
        if (
            child[].keyword == keyword
            and child[].argument
            and child[].argument.value() == name
        ):
            return Optional[Arc[YangConstruct]](child.copy())
    return Optional[Arc[YangConstruct]]()


def leaf_type(read leaf: YangConstruct) -> String:
    var ty = find_child(leaf, "type")
    if ty and ty.value()[].argument:
        return ty.value()[].argument.value()
    return ""


def leaf_range(read leaf: YangConstruct) -> String:
    var ty = find_child(leaf, "type")
    if not ty:
        return ""
    var range_stmt = find_child(ty.value()[], "range")
    if range_stmt and range_stmt.value()[].argument:
        return range_stmt.value()[].argument.value()
    return ""


def leafref_path(read leaf: YangConstruct) -> String:
    var ty = find_child(leaf, "type")
    if not ty:
        return ""
    var path_stmt = find_child(ty.value()[], "path")
    if path_stmt and path_stmt.value()[].argument:
        return path_stmt.value()[].argument.value()
    return ""


def validate_leaf_value(
    read value: JsonValue,
    read leaf: YangConstruct,
    path: String,
    json_path: String,
) raises:
    var ty = leaf_type(leaf)
    var loc = json_line_prefix(json_path, value.source_line)
    if ty == "string":
        if value.kind != JsonValue.STRING:
            raise Error(loc + path + ": expected string")
        if value.text.byte_length() == 0 and find_child(leaf, "must"):
            raise Error(loc + path + ": must expression rejected empty string")
        return
    if ty == "boolean":
        if value.kind != JsonValue.BOOL:
            raise Error(loc + path + ": expected boolean")
        return
    if ty == "uint16":
        if value.kind != JsonValue.INT:
            raise Error(loc + path + ": expected uint16")
        if value.int_value < 0 or value.int_value > 65535:
            raise Error(loc + path + ": uint16 value out of range")
        var range_text = leaf_range(leaf)
        if range_text == "0..300" and value.int_value > 300:
            raise Error(loc + path + ": value outside range 0..300")
        if range_text == "576..9216" and (
            value.int_value < 576 or value.int_value > 9216
        ):
            raise Error(loc + path + ": value outside range 576..9216")
        return
    if ty == "leafref":
        if (
            value.kind != JsonValue.STRING
            and value.kind != JsonValue.INT
            and value.kind != JsonValue.BOOL
        ):
            raise Error(loc + path + ": expected scalar leafref")
        return
    raise Error(loc + path + ": unsupported leaf type `" + ty + "`")


def validate_object_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangConstruct,
    path: String,
    json_path: String,
) raises:
    if data.kind != JsonValue.OBJECT:
        raise Error(
            json_line_prefix(json_path, data.source_line)
            + path
            + ": expected JSON object"
        )

    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var leaf = find_effective_leaf(module, schema, key)
        if leaf:
            validate_leaf_value(
                slot, leaf.value()[], path + "/" + key, json_path
            )
            continue
        var container = find_effective_child(module, schema, "container", key)
        if container:
            validate_object_against_construct(
                slot,
                container.value()[],
                module,
                path + "/" + key,
                json_path,
            )
            continue
        var list_node = find_effective_child(module, schema, "list", key)
        if list_node:
            validate_list_against_construct(
                slot,
                list_node.value()[],
                module,
                path + "/" + key,
                json_path,
            )
            continue
        raise Error(
            json_line_prefix(json_path, slot.source_line)
            + path
            + ": unknown field `"
            + key
            + "`"
        )


def validate_list_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangConstruct,
    path: String,
    json_path: String,
) raises:
    if data.kind != JsonValue.ARRAY:
        raise Error(
            json_line_prefix(json_path, data.source_line)
            + path
            + ": expected JSON array for list"
        )
    var key_stmt = find_child(schema, "key")
    for i in range(len(data.array_values)):
        ref entry = data.array_values[i][]
        var entry_path = path + "[" + String(i) + "]"
        validate_object_against_construct(
            entry, schema, module, entry_path, json_path
        )
        if key_stmt and key_stmt.value()[].argument:
            var key = key_stmt.value()[].argument.value()
            if not json_get(entry, key):
                raise Error(
                    json_line_prefix(json_path, entry.source_line)
                    + entry_path
                    + ": missing list key `"
                    + key
                    + "`"
                )


def path_segment_name(segment: String) -> String:
    var base = String(segment.strip())
    var predicate_parts = base.split("[")
    if len(predicate_parts) > 0:
        base = String(predicate_parts[0])
    var prefix_parts = base.split(":")
    if len(prefix_parts) == 2:
        return String(prefix_parts[1])
    return base^


def path_segments(path: String) -> List[String]:
    var out = List[String]()
    var raw_segments = path.split("/")
    for i in range(len(raw_segments)):
        var segment = path_segment_name(String(raw_segments[i]))
        if segment.byte_length() > 0 and segment != ".":
            out.append(segment^)
    return out^


def collect_path_values_at(
    read node: JsonValue,
    read segments: List[String],
    index: Int,
    mut out: List[String],
):
    if node.kind == JsonValue.ARRAY:
        for i in range(len(node.array_values)):
            collect_path_values_at(node.array_values[i][], segments, index, out)
        return

    if index >= len(segments):
        out.append(json_scalar_text(node))
        return

    if node.kind != JsonValue.OBJECT:
        return

    var child = json_get(node, segments[index])
    if child:
        collect_path_values_at(child.value()[], segments, index + 1, out)


def collect_path_values(read root: JsonValue, path: String) -> List[String]:
    var out = List[String]()
    var segments = path_segments(path)
    collect_path_values_at(root, segments, 0, out)
    return out^


def string_in_list(value: String, read values: List[String]) -> Bool:
    for i in range(len(values)):
        if values[i] == value:
            return True
    return False


def check_leafrefs_in_object(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangConstruct,
    read root: JsonValue,
    path: String,
    json_path: String,
) raises:
    if data.kind != JsonValue.OBJECT:
        return
    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var leaf = find_effective_leaf(module, schema, key)
        if leaf and leaf_type(leaf.value()[]) == "leafref":
            var target_path = leafref_path(leaf.value()[])
            var targets = collect_path_values(root, target_path)
            var actual = json_scalar_text(slot)
            if not string_in_list(actual, targets):
                raise Error(
                    json_line_prefix(json_path, slot.source_line)
                    + path
                    + "/"
                    + key
                    + ": leafref `"
                    + actual
                    + "` does not resolve"
                )
        var container = find_effective_child(module, schema, "container", key)
        if container:
            check_leafrefs_in_object(
                slot,
                container.value()[],
                module,
                root,
                path + "/" + key,
                json_path,
            )
        var list_node = find_effective_child(module, schema, "list", key)
        if list_node:
            check_leafrefs_in_list(
                slot,
                list_node.value()[],
                module,
                root,
                path + "/" + key,
                json_path,
            )


def check_leafrefs_in_list(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangConstruct,
    read root: JsonValue,
    path: String,
    json_path: String,
) raises:
    if data.kind != JsonValue.ARRAY:
        return
    for i in range(len(data.array_values)):
        check_leafrefs_in_object(
            data.array_values[i][],
            schema,
            module,
            root,
            path + "[" + String(i) + "]",
            json_path,
        )


def validate_data(
    read data: JsonValue, read module: YangConstruct, json_path: String
) raises:
    if data.kind != JsonValue.OBJECT:
        raise Error(
            json_line_prefix(json_path, data.source_line)
            + "/: expected top-level JSON object"
        )
    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var container = find_effective_child(module, module, "container", key)
        if not container:
            raise Error(
                json_line_prefix(json_path, slot.source_line)
                + "/: unknown top-level field `"
                + key
                + "`"
            )
        validate_object_against_construct(
            slot, container.value()[], module, "/" + key, json_path
        )
        check_leafrefs_in_object(
            slot,
            container.value()[],
            module,
            data,
            "/" + key,
            json_path,
        )


def main() raises:
    var yang_text: String
    with open(YANG_PATH, "r") as f:
        yang_text = f.read()
    var lexer = AstLexer(yang_text.as_bytes())
    var yang_module = parse_module(lexer)

    var json_text: String
    with open(DATA_PATH, "r") as f:
        json_text = f.read()
    var json_path = String(DATA_PATH)
    var json_parser = JsonParser(json_text.as_bytes(), json_path)
    var data = json_parser.parse_value()

    var specs = build_spec_table()
    validate_construct(specs[Int(`module`)], yang_module, specs)
    validate_data(data, yang_module, json_path)

    print("YANG module: " + yang_module.argument.value())
    print("Data file: " + DATA_PATH)
    print("Validation: valid")
