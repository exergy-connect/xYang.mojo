## Two-layer YANG construct specs: typed compile-time `YangConstructSpecTrait`
## implementations lowered into monomorphic `RuntimeConstructSpec` table rows.

import xyang.yang.arguments as yarg
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.arguments import YangArgument
from xyang.yang.cardinality import `0`, `1`, `0..1`, `0..n`, `1..n`
from xyang.yang.keyword import Keyword, `<INVALID>`
from xyang.yang.runtime_spec import (
    RuntimeConstructSpec,
    RuleTable,
    YangConstructSpecTrait,
    fields,
    keyword_spelling,
)


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


struct YangConstructSpec[
    kw: Keyword,
    arg_t: YangArgument,
    allowed_fields_table: RuleTable,
](Movable, YangConstructSpecTrait):
    comptime KEYWORD: Keyword = Self.kw
    comptime ARGUMENT_TYPE: YangArgument = Self.arg_t

    @staticmethod
    def allowed_fields() -> RuleTable:
        return Self.allowed_fields_table

    def __init__(out self):
        pass


## Source: RFC 7950 section 7.1.1, "The module's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.1.1
comptime MODULE_TYPED_SPEC = YangConstructSpec[
    `module`,
    yarg.IdentifierArgument,
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
]
comptime CONTAINER_TYPED_SPEC = YangConstructSpec[
    `container`,
    yarg.IdentifierArgument,
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
]
comptime LIST_TYPED_SPEC = YangConstructSpec[
    `list`,
    yarg.IdentifierArgument,
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
]
comptime LEAF_TYPED_SPEC = YangConstructSpec[
    `leaf`,
    yarg.IdentifierArgument,
    fields[6](
        (`when`, `0..1`),
        (`type`, `1`),
        (`must`, `0..n`),
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`mandatory`, `0..1`),
    ),
]
comptime LEAF_LIST_TYPED_SPEC = YangConstructSpec[
    `leaf-list`,
    yarg.IdentifierArgument,
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
]
comptime TYPEDEF_TYPED_SPEC = YangConstructSpec[
    `typedef`,
    yarg.IdentifierArgument,
    fields[4](
        (`type`, `1`),
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`reference`, `0..1`),
    ),
]
comptime TYPE_TYPED_SPEC = YangConstructSpec[
    `type`,
    yarg.IdentifierArgument,
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
]
comptime ENUM_STMT_TYPED_SPEC = YangConstructSpec[
    `enum`,
    yarg.IdentifierArgument,
    fields[2](
        (`description`, `0..1`),
        (`reference`, `0..1`),
    ),
]
comptime LENGTH_STMT_TYPED_SPEC = YangConstructSpec[
    `length`,
    yarg.LengthArgument,
    fields[3](
        (`description`, `0..1`),
        (`error-message`, `0..1`),
        (`reference`, `0..1`),
    ),
]
comptime PATTERN_STMT_TYPED_SPEC = YangConstructSpec[
    `pattern`,
    yarg.PatternArgument,
    fields[4](
        (`description`, `0..1`),
        (`error-message`, `0..1`),
        (`reference`, `0..1`),
        (`modifier`, `0..1`),
    ),
]
comptime GROUPING_TYPED_SPEC = YangConstructSpec[
    `grouping`,
    yarg.IdentifierArgument,
    fields[7](
        (`description`, `0..1`),
        (`uses`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`choice`, `0..n`),
    ),
]
comptime CHOICE_TYPED_SPEC = YangConstructSpec[
    `choice`,
    yarg.IdentifierArgument,
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
]
comptime CASE_TYPED_SPEC = YangConstructSpec[
    `case`,
    yarg.IdentifierArgument,
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
]
comptime REVISION_TYPED_SPEC = YangConstructSpec[
    `revision`,
    yarg.RevisionDateArgument,
    fields[1]((`description`, `0..1`)),
]
comptime MUST_TYPED_SPEC = YangConstructSpec[
    `must`,
    yarg.XPathExpressionArgument,
    fields[2](
        (`error-message`, `0..1`),
        (`description`, `0..1`),
    ),
]


def build_spec_table() raises -> RuntimeConstructSpec.Table:
    var specs = RuntimeConstructSpec.Table(
        fill=RuntimeConstructSpec.scalar[`<INVALID>`, yarg.NoArgument]()
    )

    def add_spec[Spec: YangConstructSpecTrait]() {mut specs}:
        specs[Spec.KEYWORD] = RuntimeConstructSpec.from_comptime[Spec]()

    def add_scalar_spec[kw: Keyword, arg_t: YangArgument]() {mut specs}:
        specs[kw] = RuntimeConstructSpec.scalar[kw, arg_t]()

    add_scalar_spec[`anydata`, yarg.IdentifierArgument]()
    add_scalar_spec[`anyxml`, yarg.IdentifierArgument]()
    add_scalar_spec[`augment`, yarg.PathArgument]()
    add_scalar_spec[`base`, yarg.QNameArgument]()
    add_scalar_spec[`bit`, yarg.IdentifierArgument]()
    add_spec[CASE_TYPED_SPEC]()
    add_spec[CHOICE_TYPED_SPEC]()
    add_scalar_spec[`config`, yarg.BoolArgument]()
    add_scalar_spec[`contact`, yarg.StringArgument]()
    add_spec[CONTAINER_TYPED_SPEC]()
    add_scalar_spec[`default`, yarg.StringArgument]()
    add_scalar_spec[`description`, yarg.StringArgument]()
    add_scalar_spec[`deviation`, yarg.PathArgument]()
    add_spec[ENUM_STMT_TYPED_SPEC]()
    add_scalar_spec[`error-message`, yarg.StringArgument]()
    add_scalar_spec[`extension`, yarg.IdentifierArgument]()
    add_scalar_spec[`feature`, yarg.IdentifierArgument]()
    add_scalar_spec[`fraction-digits`, yarg.FractionDigitsArgument]()
    add_spec[GROUPING_TYPED_SPEC]()
    add_scalar_spec[`identity`, yarg.IdentifierArgument]()
    add_scalar_spec[`if-feature`, yarg.StringArgument]()
    add_scalar_spec[`import`, yarg.IdentifierArgument]()
    add_scalar_spec[`include`, yarg.IdentifierArgument]()
    add_scalar_spec[`key`, yarg.IdentifierArgument]()
    add_spec[LEAF_TYPED_SPEC]()
    add_spec[LEAF_LIST_TYPED_SPEC]()
    add_spec[LENGTH_STMT_TYPED_SPEC]()
    add_spec[LIST_TYPED_SPEC]()
    add_scalar_spec[`mandatory`, yarg.BoolArgument]()
    add_scalar_spec[`max-elements`, yarg.MaxElementsArgument]()
    add_scalar_spec[`min-elements`, yarg.MinElementsArgument]()
    add_scalar_spec[`modifier`, yarg.ModifierArgument]()
    add_spec[MODULE_TYPED_SPEC]()
    add_spec[MUST_TYPED_SPEC]()
    add_scalar_spec[`namespace`, yarg.StringArgument]()
    add_scalar_spec[`notification`, yarg.IdentifierArgument]()
    add_scalar_spec[`organization`, yarg.StringArgument]()
    add_scalar_spec[`path`, yarg.PathArgument]()
    add_spec[PATTERN_STMT_TYPED_SPEC]()
    add_scalar_spec[`prefix`, yarg.IdentifierArgument]()
    add_scalar_spec[`presence`, yarg.StringArgument]()
    add_scalar_spec[`range-stmt`, yarg.RangeArgument]()
    add_scalar_spec[`reference`, yarg.StringArgument]()
    add_spec[REVISION_TYPED_SPEC]()
    add_scalar_spec[`rpc`, yarg.IdentifierArgument]()
    add_scalar_spec[`status`, yarg.StatusArgument]()
    add_spec[TYPE_TYPED_SPEC]()
    add_spec[TYPEDEF_TYPED_SPEC]()
    add_scalar_spec[`uses`, yarg.QNameArgument]()
    add_scalar_spec[`when`, yarg.XPathExpressionArgument]()
    add_scalar_spec[`yang-version`, yarg.YangVersionArgument]()

    for i in range(len(specs)):
        var expected_kw = Keyword(i)
        if specs[i].kw != expected_kw:
            raise Error(
                "build_spec_table: missing or wrong spec for `"
                + keyword_spelling(expected_kw)
                + "` (index "
                + String(i)
                + ")"
            )
    return specs


def lookup_spec(
    read node: YangConstruct, read specs: RuntimeConstructSpec.Table
) raises -> RuntimeConstructSpec:
    if node.spec == `<INVALID>`:
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "Construct `"
            + node.keyword
            + "` has not been validated"
        )
    return specs[Int(node.spec)]
