## Table-driven YANG construct specs, keyword indices, and recursive validation.

from std.memory import UnsafePointer

import xyang.yang.arguments as yarg
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.keyword import Keyword, `<INVALID>`

comptime ArgumentValidator = def(mut YangConstruct) raises thin -> None


## Thin wrappers so `YangConstructSpec` stores monomorphic `ArgumentValidator`
## callbacks; `YangArgument::validate` is typed with `YangArgumentHost`, not
## concrete `YangConstruct`.
@always_inline
def _validate_identifier(mut node: YangConstruct) raises -> None:
    yarg.IdentifierArgument.validate(node)


@always_inline
def _validate_string(mut node: YangConstruct) raises -> None:
    yarg.StringArgument.validate(node)


@always_inline
def _validate_qname(mut node: YangConstruct) raises -> None:
    yarg.QNameArgument.validate(node)


@always_inline
def _validate_type_name(mut node: YangConstruct) raises -> None:
    yarg.TypeNameArgument.validate(node)


@always_inline
def _validate_length(mut node: YangConstruct) raises -> None:
    yarg.LengthArgument.validate(node)


@always_inline
def _validate_pattern(mut node: YangConstruct) raises -> None:
    yarg.PatternArgument.validate(node)


@always_inline
def _validate_revision_date(mut node: YangConstruct) raises -> None:
    yarg.RevisionDateArgument.validate(node)


@always_inline
def _validate_xpath(mut node: YangConstruct) raises -> None:
    yarg.XPathExpressionArgument.validate(node)


@always_inline
def _validate_range(mut node: YangConstruct) raises -> None:
    yarg.RangeArgument.validate(node)


@always_inline
def _validate_path(mut node: YangConstruct) raises -> None:
    yarg.PathArgument.validate(node)


@always_inline
def _validate_modifier(mut node: YangConstruct) raises -> None:
    yarg.ModifierArgument.validate(node)


@always_inline
def _validate_fraction_digits(mut node: YangConstruct) raises -> None:
    yarg.FractionDigitsArgument.validate(node)


@always_inline
def _validate_yang_version(mut node: YangConstruct) raises -> None:
    yarg.YangVersionArgument.validate(node)


comptime `anydata`: Keyword = 1
comptime `anyxml`: Keyword = 2
comptime `augment`: Keyword = 3
comptime `choice`: Keyword = 4
comptime `contact`: Keyword = 5
comptime `container`: Keyword = 6
comptime `default`: Keyword = 7
comptime `description`: Keyword = 8
comptime `deviation`: Keyword = 9
comptime `error-message`: Keyword = 10
comptime `extension`: Keyword = 11
comptime `feature`: Keyword = 12
comptime `grouping`: Keyword = 13
comptime `identity`: Keyword = 14
comptime `import`: Keyword = 15
comptime `include`: Keyword = 16
comptime `key`: Keyword = 17
comptime `leaf`: Keyword = 18
comptime `leaf-list`: Keyword = 19
comptime `list`: Keyword = 20
comptime `module`: Keyword = 21
comptime `must`: Keyword = 22
comptime `namespace`: Keyword = 23
comptime `notification`: Keyword = 24
comptime `organization`: Keyword = 25
comptime `path`: Keyword = 26
comptime `prefix`: Keyword = 27
comptime `range-stmt`: Keyword = 28
comptime `reference`: Keyword = 29
comptime `revision`: Keyword = 30
comptime `rpc`: Keyword = 31
comptime `type`: Keyword = 32
comptime `typedef`: Keyword = 33
comptime `uses`: Keyword = 34
comptime `when`: Keyword = 35
comptime `yang-version`: Keyword = 36
comptime `length`: Keyword = 37
comptime `pattern`: Keyword = 38
comptime `modifier`: Keyword = 39
comptime `fraction-digits`: Keyword = 40
comptime `enum`: Keyword = 41
comptime `bit`: Keyword = 42
comptime `base`: Keyword = 43

comptime KEYWORD_COUNT: Int = 44
comptime SPELLING: InlineArray[String, KEYWORD_COUNT] = [
    "<INVALID>",
    "anydata",
    "anyxml",
    "augment",
    "choice",
    "contact",
    "container",
    "default",
    "description",
    "deviation",
    "error-message",
    "extension",
    "feature",
    "grouping",
    "identity",
    "import",
    "include",
    "key",
    "leaf",
    "leaf-list",
    "list",
    "module",
    "must",
    "namespace",
    "notification",
    "organization",
    "path",
    "prefix",
    "range",
    "reference",
    "revision",
    "rpc",
    "type",
    "typedef",
    "uses",
    "when",
    "yang-version",
    "length",
    "pattern",
    "modifier",
    "fraction-digits",
    "enum",
    "bit",
    "base",
]

comptime Cardinality = UInt8
comptime `0`: Cardinality = 0
comptime `1`: Cardinality = 1
comptime `0..1`: Cardinality = 2
comptime `0..n`: Cardinality = 3
comptime `1..n`: Cardinality = 4


def keyword_spelling(idx: Keyword) -> String:
    return SPELLING[Int(idx)]


def keyword_id(name: String, line: UInt = 0) raises -> Keyword:
    for i in range(KEYWORD_COUNT):
        if name == SPELLING[i]:
            return Keyword(i)
    raise Error(
        ("line " + String(line) + ": " if line > 0 else "")
        + "Unknown YANG keyword `"
        + name
        + "`"
    )


def check_cardinality(
    name: String, card: Cardinality, count: Int, line: UInt = 0
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
comptime FIELD = Tuple[Keyword, Cardinality]


def fields[n: Int](*fieldlist: FIELD) -> RuleTable:
    var table = InlineArray[FieldRule, KEYWORD_COUNT](fill=FieldRule(`0`))
    comptime for i in range(n):
        table[Int(fieldlist[i][0])] = FieldRule(fieldlist[i][1])
    return table


struct YangConstructSpec(Copyable, ImplicitlyCopyable, Movable):
    comptime Table = InlineArray[Self, KEYWORD_COUNT]
    comptime Validate = def(
        UnsafePointer[Self, ImmutAnyOrigin],
        mut YangConstruct,
        UnsafePointer[Self.Table, ImmutAnyOrigin],
    ) raises thin -> None

    var parent: Keyword
    var argument_type: ArgumentValidator
    var allowed_fields: RuleTable
    var validate: Self.Validate

    def __init__(
        out self,
        parent: Keyword,
        argument_type: ArgumentValidator,
        allowed_fields: RuleTable,
        validate: Self.Validate = validate_construct_callback,
    ):
        self.parent = parent
        self.argument_type = argument_type
        self.allowed_fields = allowed_fields
        self.validate = validate


def scalar_spec(
    parent: Keyword, argument_type: ArgumentValidator
) -> YangConstructSpec:
    return YangConstructSpec(
        parent,
        argument_type,
        fields[0](),
        validate_scalar_construct_callback,
    )


## Source: RFC 7950 section 7.1.1, "The module's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.1.1
comptime MODULE_SPEC = YangConstructSpec(
    `module`,
    _validate_identifier,
    fields[27](
        (`anydata`, `0..n`),
        (`anyxml`, `0..n`),
        (`augment`, `0..n`),
        (`choice`, `0..n`),
        (`contact`, `0..1`),
        (`container`, `0..n`),
        (`description`, `0..1`),
        (`deviation`, `0..n`),
        (`extension`, `0..n`),
        (`feature`, `0..n`),
        (`grouping`, `0..n`),
        (`identity`, `0..n`),
        (`import`, `0..n`),
        (`include`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`namespace`, `1`),
        (`notification`, `0..n`),
        (`organization`, `0..1`),
        (`prefix`, `1`),
        (`reference`, `0..1`),
        (`revision`, `0..n`),
        (`rpc`, `0..n`),
        (`typedef`, `0..n`),
        (`uses`, `0..n`),
        (`yang-version`, `1`),
    ),
)
comptime CONTAINER_SPEC = YangConstructSpec(
    `container`,
    _validate_identifier,
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
    _validate_identifier,
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
    _validate_identifier,
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
    _validate_type_name,
    fields[9](
        (`path`, `0..1`),
        (`range-stmt`, `0..1`),
        (`length`, `0..1`),
        (`pattern`, `0..n`),
        (`fraction-digits`, `0..1`),
        (`enum`, `0..n`),
        (`bit`, `0..n`),
        (`type`, `0..n`),
        (`base`, `0..n`),
    ),
)
comptime LENGTH_STMT_SPEC = YangConstructSpec(
    `length`,
    _validate_length,
    fields[3](
        (`description`, `0..1`),
        (`error-message`, `0..1`),
        (`reference`, `0..1`),
    ),
)
comptime PATTERN_STMT_SPEC = YangConstructSpec(
    `pattern`,
    _validate_pattern,
    fields[4](
        (`description`, `0..1`),
        (`error-message`, `0..1`),
        (`reference`, `0..1`),
        (`modifier`, `0..1`),
    ),
)
comptime GROUPING_SPEC = YangConstructSpec(
    `grouping`,
    _validate_identifier,
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
    _validate_revision_date,
    fields[1]((`description`, `0..1`)),
)
comptime MUST_SPEC = YangConstructSpec(
    `must`,
    _validate_xpath,
    fields[2](
        (`error-message`, `0..1`),
        (`description`, `0..1`),
    ),
)


def build_spec_table() -> YangConstructSpec.Table:
    var specs = YangConstructSpec.Table(
        fill=scalar_spec(`<INVALID>`, _validate_identifier)
    )
    specs[`module`] = MODULE_SPEC
    specs[`yang-version`] = scalar_spec(`yang-version`, _validate_yang_version)
    specs[Int(`namespace`)] = scalar_spec(`namespace`, _validate_string)
    specs[Int(`prefix`)] = scalar_spec(`prefix`, _validate_identifier)
    specs[Int(`organization`)] = scalar_spec(`organization`, _validate_string)
    specs[Int(`contact`)] = scalar_spec(`contact`, _validate_string)
    specs[Int(`description`)] = scalar_spec(`description`, _validate_string)
    specs[Int(`revision`)] = REVISION_SPEC
    specs[Int(`grouping`)] = GROUPING_SPEC
    specs[Int(`uses`)] = scalar_spec(`uses`, _validate_qname)
    specs[Int(`container`)] = CONTAINER_SPEC
    specs[Int(`list`)] = LIST_SPEC
    specs[Int(`key`)] = scalar_spec(`key`, _validate_identifier)
    specs[Int(`leaf`)] = LEAF_SPEC
    specs[Int(`type`)] = TYPE_SPEC
    specs[Int(`range-stmt`)] = scalar_spec(`range-stmt`, _validate_range)
    specs[Int(`path`)] = scalar_spec(`path`, _validate_path)
    specs[Int(`default`)] = scalar_spec(`default`, _validate_string)
    specs[Int(`must`)] = MUST_SPEC
    specs[Int(`error-message`)] = scalar_spec(`error-message`, _validate_string)
    specs[Int(`when`)] = scalar_spec(`when`, _validate_xpath)
    specs[Int(`anydata`)] = scalar_spec(`anydata`, _validate_identifier)
    specs[Int(`anyxml`)] = scalar_spec(`anyxml`, _validate_identifier)
    specs[Int(`augment`)] = scalar_spec(`augment`, _validate_path)
    specs[Int(`choice`)] = scalar_spec(`choice`, _validate_identifier)
    specs[Int(`deviation`)] = scalar_spec(`deviation`, _validate_path)
    specs[Int(`extension`)] = scalar_spec(`extension`, _validate_identifier)
    specs[Int(`feature`)] = scalar_spec(`feature`, _validate_identifier)
    specs[Int(`identity`)] = scalar_spec(`identity`, _validate_identifier)
    specs[Int(`import`)] = scalar_spec(`import`, _validate_identifier)
    specs[Int(`include`)] = scalar_spec(`include`, _validate_identifier)
    specs[Int(`leaf-list`)] = scalar_spec(`leaf-list`, _validate_identifier)
    specs[Int(`notification`)] = scalar_spec(
        `notification`, _validate_identifier
    )
    specs[Int(`reference`)] = scalar_spec(`reference`, _validate_string)
    specs[Int(`rpc`)] = scalar_spec(`rpc`, _validate_identifier)
    specs[Int(`typedef`)] = scalar_spec(`typedef`, _validate_identifier)
    specs[Int(`length`)] = LENGTH_STMT_SPEC
    specs[Int(`pattern`)] = PATTERN_STMT_SPEC
    specs[Int(`modifier`)] = scalar_spec(`modifier`, _validate_modifier)
    specs[Int(`fraction-digits`)] = scalar_spec(
        `fraction-digits`, _validate_fraction_digits
    )
    specs[Int(`enum`)] = scalar_spec(`enum`, _validate_identifier)
    specs[Int(`bit`)] = scalar_spec(`bit`, _validate_identifier)
    specs[Int(`base`)] = scalar_spec(`base`, _validate_qname)
    return specs


def construct_spec(
    read node: YangConstruct, read specs: YangConstructSpec.Table
) raises -> YangConstructSpec:
    if node.spec == `<INVALID>`:
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "Construct `"
            + node.keyword
            + "` has not been validated"
        )
    return specs[Int(node.spec)]


def validate_construct(
    read spec: YangConstructSpec,
    mut node: YangConstruct,
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
    if not node.has_argument():
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "Expected argument for `"
            + expected_name
            + "`"
        )
    spec.argument_type(node)

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
            keyword_spelling(Keyword(i)),
            spec.allowed_fields[i].cardinality,
            counts[i],
            node.line,
        )

    node.spec = spec.parent
    for child in node.children:
        var child_kw = keyword_id(child[].keyword, child[].line)
        ref child_spec = specs[Int(child_kw)]
        var child_spec_ptr = UnsafePointer(to=child_spec).unsafe_origin_cast[
            ImmutAnyOrigin
        ]()
        var specs_ptr = UnsafePointer(to=specs).unsafe_origin_cast[
            ImmutAnyOrigin
        ]()
        child_spec_ptr[].validate(child_spec_ptr, child[], specs_ptr)


def validate_construct_callback(
    spec_ptr: UnsafePointer[YangConstructSpec, ImmutAnyOrigin],
    mut node: YangConstruct,
    specs_ptr: UnsafePointer[YangConstructSpec.Table, ImmutAnyOrigin],
) raises -> None:
    validate_construct(spec_ptr[], node, specs_ptr[])


def validate_scalar_construct_callback(
    spec_ptr: UnsafePointer[YangConstructSpec, ImmutAnyOrigin],
    mut node: YangConstruct,
    specs_ptr: UnsafePointer[YangConstructSpec.Table, ImmutAnyOrigin],
) raises -> None:
    var expected_name = keyword_spelling(spec_ptr[].parent)
    if node.keyword != expected_name:
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "Expected `"
            + expected_name
            + "`, got `"
            + node.keyword
            + "`"
        )
    if not node.has_argument():
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "Expected argument for `"
            + expected_name
            + "`"
        )
    spec_ptr[].argument_type(node)
    for child in node.children:
        raise Error(
            ("line " + String(child[].line) + ": " if child[].line > 0 else "")
            + "Unknown substatement `"
            + child[].keyword
            + "` in `"
            + expected_name
            + "`"
        )
    node.spec = spec_ptr[].parent
