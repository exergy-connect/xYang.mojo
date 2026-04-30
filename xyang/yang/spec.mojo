## Table-driven YANG construct specs, keyword indices, and recursive validation.

from std.memory import UnsafePointer

from xyang.yang.arguments import (
    ArgumentValidator,
    validate_yang_expression,
    validate_yang_identifier,
    validate_yang_path,
    validate_yang_qname,
    validate_yang_range,
    validate_yang_revision_date,
    validate_yang_string,
    validate_yang_type_name,
    validate_yang_version,
)
from xyang.yang.ast.construct import YangConstruct


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
    raise Error(
        ("line " + String(line) + ": " if line > 0 else "")
        + "Unknown YANG keyword `"
        + name
        + "`"
    )


def check_cardinality(
    name: String, card: Cardinality, count: Int, line: Int = 0
) raises:
    if card == `0` and count != 0:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` must not appear, found "
            + String(count)
        )
    if card == `1` and count != 1:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` must appear exactly once, found "
            + String(count)
        )
    if card == `0..1` and count > 1:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` may appear at most once, found "
            + String(count)
        )
    if card == `1..n` and count < 1:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` must appear at least once"
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


def build_spec_table() -> YangConstructSpec.Table:
    var specs = YangConstructSpec.Table(
        fill=scalar_spec(`module`, validate_yang_identifier)
    )
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
    read specs: YangConstructSpec.Table,
) raises:
    var expected_name = keyword_spelling(spec.parent)
    if node.keyword != expected_name:
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "Expected `"
            + expected_name
            + "`, got `"
            + node.keyword
            + "`"
        )
    if not node.argument:
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
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
                (
                    "line " + String(child[].line) + ": " if child[].line
                    > 0 else ""
                )
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
                (
                    "line " + String(child[].line) + ": " if child[].line
                    > 0 else ""
                )
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
            var specs_ptr = UnsafePointer(to=specs).unsafe_origin_cast[
                ImmutAnyOrigin
            ]()
            child_spec_ptr[].validate(child_spec_ptr, child[], specs_ptr)


def validate_construct_callback(
    spec_ptr: UnsafePointer[YangConstructSpec, ImmutAnyOrigin],
    read node: YangConstruct,
    specs_ptr: UnsafePointer[YangConstructSpec.Table, ImmutAnyOrigin],
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
    specs_ptr: UnsafePointer[YangConstructSpec.Table, ImmutAnyOrigin],
) raises -> None:
    raise Error(
        ("line " + String(node.line) + ": " if node.line > 0 else "")
        + "Unexpected recursive validation for scalar `"
        + node.keyword
        + "`"
    )
