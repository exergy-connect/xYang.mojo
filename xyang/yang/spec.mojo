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


@always_inline
def _validate_bool(mut node: YangConstruct) raises -> None:
    yarg.BoolArgument.validate(node)


@always_inline
def _validate_min_elements(mut node: YangConstruct) raises -> None:
    yarg.MinElementsArgument.validate(node)


@always_inline
def _validate_max_elements(mut node: YangConstruct) raises -> None:
    yarg.MaxElementsArgument.validate(node)


@always_inline
def _validate_status(mut node: YangConstruct) raises -> None:
    yarg.StatusArgument.validate(node)


## Keyword ids match `SPELLING` indices; both lists are alphabetical (invalid
## sentinel first, then lexicographic YANG spellings including hyphens).
comptime `anydata`: Keyword = 1
comptime `anyxml`: Keyword = 2
comptime `augment`: Keyword = 3
comptime `base`: Keyword = 4
comptime `bit`: Keyword = 5
comptime `case`: Keyword = 6
comptime `choice`: Keyword = 7
comptime `config`: Keyword = 8
comptime `contact`: Keyword = 9
comptime `container`: Keyword = 10
comptime `default`: Keyword = 11
comptime `description`: Keyword = 12
comptime `deviation`: Keyword = 13
comptime `enum`: Keyword = 14
comptime `error-message`: Keyword = 15
comptime `extension`: Keyword = 16
comptime `feature`: Keyword = 17
comptime `fraction-digits`: Keyword = 18
comptime `grouping`: Keyword = 19
comptime `identity`: Keyword = 20
comptime `if-feature`: Keyword = 21
comptime `import`: Keyword = 22
comptime `include`: Keyword = 23
comptime `key`: Keyword = 24
comptime `leaf`: Keyword = 25
comptime `leaf-list`: Keyword = 26
comptime `length`: Keyword = 27
comptime `list`: Keyword = 28
comptime `mandatory`: Keyword = 29
comptime `max-elements`: Keyword = 30
comptime `min-elements`: Keyword = 31
comptime `modifier`: Keyword = 32
comptime `module`: Keyword = 33
comptime `must`: Keyword = 34
comptime `namespace`: Keyword = 35
comptime `notification`: Keyword = 36
comptime `organization`: Keyword = 37
comptime `path`: Keyword = 38
comptime `pattern`: Keyword = 39
comptime `prefix`: Keyword = 40
comptime `presence`: Keyword = 41
comptime `range-stmt`: Keyword = 42
comptime `reference`: Keyword = 43
comptime `revision`: Keyword = 44
comptime `rpc`: Keyword = 45
comptime `status`: Keyword = 46
comptime `type`: Keyword = 47
comptime `typedef`: Keyword = 48
comptime `uses`: Keyword = 49
comptime `when`: Keyword = 50
comptime `yang-version`: Keyword = 51

comptime KEYWORD_COUNT: Int = 52
comptime SPELLING: InlineArray[String, KEYWORD_COUNT] = [
    "<INVALID>",
    "anydata",
    "anyxml",
    "augment",
    "base",
    "bit",
    "case",
    "choice",
    "config",
    "contact",
    "container",
    "default",
    "description",
    "deviation",
    "enum",
    "error-message",
    "extension",
    "feature",
    "fraction-digits",
    "grouping",
    "identity",
    "if-feature",
    "import",
    "include",
    "key",
    "leaf",
    "leaf-list",
    "length",
    "list",
    "mandatory",
    "max-elements",
    "min-elements",
    "modifier",
    "module",
    "must",
    "namespace",
    "notification",
    "organization",
    "path",
    "pattern",
    "prefix",
    "presence",
    "range",
    "reference",
    "revision",
    "rpc",
    "status",
    "type",
    "typedef",
    "uses",
    "when",
    "yang-version",
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
    fields[9](
        (`must`, `0..n`),
        (`description`, `0..1`),
        (`presence`, `0..1`),
        (`uses`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`choice`, `0..n`),
    ),
)
comptime LIST_SPEC = YangConstructSpec(
    `list`,
    _validate_identifier,
    fields[11](
        (`must`, `0..n`),
        (`key`, `0..1`),
        (`min-elements`, `0..1`),
        (`max-elements`, `0..1`),
        (`description`, `0..1`),
        (`uses`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`choice`, `0..n`),
    ),
)
comptime LEAF_SPEC = YangConstructSpec(
    `leaf`,
    _validate_identifier,
    fields[6](
        (`when`, `0..1`),
        (`type`, `1`),
        (`must`, `0..n`),
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`mandatory`, `0..1`),
    ),
)
comptime LEAF_LIST_SPEC = YangConstructSpec(
    `leaf-list`,
    _validate_identifier,
    fields[8](
        (`when`, `0..1`),
        (`type`, `1`),
        (`must`, `0..n`),
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`mandatory`, `0..1`),
        (`min-elements`, `0..1`),
        (`max-elements`, `0..1`),
    ),
)
## RFC 7950: typedef has `type` plus optional documentation / default.
comptime TYPEDEF_SPEC = YangConstructSpec(
    `typedef`,
    _validate_identifier,
    fields[4](
        (`type`, `1`),
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`reference`, `0..1`),
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
## `enum` name { description?; reference?; value?; status?; } — allow common docs.
comptime ENUM_STMT_SPEC = YangConstructSpec(
    `enum`,
    _validate_identifier,
    fields[2](
        (`description`, `0..1`),
        (`reference`, `0..1`),
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
    fields[7](
        (`description`, `0..1`),
        (`uses`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`choice`, `0..n`),
    ),
)
## RFC 7950 §7.9.1, The choice's Substatements.
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.9.1
comptime CHOICE_SPEC = YangConstructSpec(
    `choice`,
    _validate_identifier,
    fields[16](
        (`anydata`, `0..n`),
        (`anyxml`, `0..n`),
        (`case`, `0..n`),
        (`choice`, `0..n`),
        (`config`, `0..1`),
        (`container`, `0..n`),
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`mandatory`, `0..1`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`when`, `0..1`),
    ),
)
## RFC 7950 §7.9.2.1, The case's Substatements.
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.9.2.1
comptime CASE_SPEC = YangConstructSpec(
    `case`,
    _validate_identifier,
    fields[12](
        (`anydata`, `0..n`),
        (`anyxml`, `0..n`),
        (`choice`, `0..n`),
        (`container`, `0..n`),
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`uses`, `0..n`),
        (`when`, `0..1`),
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
    specs[Int(`choice`)] = CHOICE_SPEC
    specs[Int(`case`)] = CASE_SPEC
    specs[Int(`config`)] = scalar_spec(`config`, _validate_bool)
    specs[Int(`if-feature`)] = scalar_spec(`if-feature`, _validate_string)
    specs[Int(`status`)] = scalar_spec(`status`, _validate_status)
    specs[Int(`deviation`)] = scalar_spec(`deviation`, _validate_path)
    specs[Int(`extension`)] = scalar_spec(`extension`, _validate_identifier)
    specs[Int(`feature`)] = scalar_spec(`feature`, _validate_identifier)
    specs[Int(`identity`)] = scalar_spec(`identity`, _validate_identifier)
    specs[Int(`import`)] = scalar_spec(`import`, _validate_identifier)
    specs[Int(`include`)] = scalar_spec(`include`, _validate_identifier)
    specs[Int(`leaf-list`)] = LEAF_LIST_SPEC
    specs[Int(`notification`)] = scalar_spec(
        `notification`, _validate_identifier
    )
    specs[Int(`reference`)] = scalar_spec(`reference`, _validate_string)
    specs[Int(`rpc`)] = scalar_spec(`rpc`, _validate_identifier)
    specs[Int(`typedef`)] = TYPEDEF_SPEC
    specs[Int(`length`)] = LENGTH_STMT_SPEC
    specs[Int(`pattern`)] = PATTERN_STMT_SPEC
    specs[Int(`modifier`)] = scalar_spec(`modifier`, _validate_modifier)
    specs[Int(`fraction-digits`)] = scalar_spec(
        `fraction-digits`, _validate_fraction_digits
    )
    specs[Int(`enum`)] = ENUM_STMT_SPEC
    specs[Int(`bit`)] = scalar_spec(`bit`, _validate_identifier)
    specs[Int(`base`)] = scalar_spec(`base`, _validate_qname)
    specs[Int(`mandatory`)] = scalar_spec(`mandatory`, _validate_bool)
    specs[Int(`min-elements`)] = scalar_spec(
        `min-elements`, _validate_min_elements
    )
    specs[Int(`max-elements`)] = scalar_spec(
        `max-elements`, _validate_max_elements
    )
    specs[Int(`presence`)] = scalar_spec(`presence`, _validate_string)
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
