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

## YANG keywords: ids match `SPELLING` in `runtime_spec.mojo` (alphabetical,
## `<INVALID>` at index 0).
comptime `action`: Keyword = 1
comptime `anydata`: Keyword = 2
comptime `anyxml`: Keyword = 3
comptime `augment`: Keyword = 4
comptime `base`: Keyword = 5
comptime `bit`: Keyword = 6
comptime `case`: Keyword = 7
comptime `choice`: Keyword = 8
comptime `config`: Keyword = 9
comptime `contact`: Keyword = 10
comptime `container`: Keyword = 11
comptime `default`: Keyword = 12
comptime `description`: Keyword = 13
comptime `deviation`: Keyword = 14
comptime `enum`: Keyword = 15
comptime `error-app-tag`: Keyword = 16
comptime `error-message`: Keyword = 17
comptime `extension`: Keyword = 18
comptime `feature`: Keyword = 19
comptime `fraction-digits`: Keyword = 20
comptime `grouping`: Keyword = 21
comptime `identity`: Keyword = 22
comptime `if-feature`: Keyword = 23
comptime `import`: Keyword = 24
comptime `include`: Keyword = 25
comptime `key`: Keyword = 26
comptime `leaf`: Keyword = 27
comptime `leaf-list`: Keyword = 28
comptime `length`: Keyword = 29
comptime `list`: Keyword = 30
comptime `mandatory`: Keyword = 31
comptime `max-elements`: Keyword = 32
comptime `min-elements`: Keyword = 33
comptime `modifier`: Keyword = 34
comptime `module`: Keyword = 35
comptime `must`: Keyword = 36
comptime `namespace`: Keyword = 37
comptime `notification`: Keyword = 38
comptime `organization`: Keyword = 39
comptime `ordered-by`: Keyword = 40
comptime `path`: Keyword = 41
comptime `pattern`: Keyword = 42
comptime `position`: Keyword = 43
comptime `prefix`: Keyword = 44
comptime `presence`: Keyword = 45
comptime `range-stmt`: Keyword = 46
comptime `reference`: Keyword = 47
comptime `require-instance`: Keyword = 48
comptime `revision`: Keyword = 49
comptime `rpc`: Keyword = 50
comptime `status`: Keyword = 51
comptime `type`: Keyword = 52
comptime `typedef`: Keyword = 53
comptime `unique`: Keyword = 54
comptime `units`: Keyword = 55
comptime `uses`: Keyword = 56
comptime `value`: Keyword = 57
comptime `when`: Keyword = 58
comptime `yang-version`: Keyword = 59


struct YangConstructSpec[
    kw: Keyword,
    arg_t: YangArgument,
    ordered_data_nodes_table: RuleTable,
    node_specific_fields_table: RuleTable,
](Movable, YangConstructSpecTrait):
    comptime KEYWORD: Keyword = Self.kw
    comptime ARGUMENT_TYPE: YangArgument = Self.arg_t

    @staticmethod
    def ordered_data_nodes() -> RuleTable:
        return Self.ordered_data_nodes_table

    @staticmethod
    def node_specific_fields() -> RuleTable:
        return Self.node_specific_fields_table

    def __init__(out self):
        pass

# Not included: augment, rpc
# TODO: Move notification out of here, treat separately
comptime COMMON_DATA_NODES = fields[9](
        (`anydata`, `0..n`),
        (`anyxml`, `0..n`),
        (`choice`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`notification`, `0..n`),
        (`uses`, `0..n`),
    )

## Source: RFC 7950 section 7.1.1, "The module's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.1.1
comptime MODULE_SPEC = YangConstructSpec[
    `module`,
    yarg.IdentifierArgument,
    COMMON_DATA_NODES,
    fields[18](
        (`augment`, `0..n`),
        (`contact`, `0..1`),
        (`description`, `0..1`),
        (`deviation`, `0..n`),
        (`extension`, `0..n`),
        (`feature`, `0..n`),
        (`grouping`, `0..n`),
        (`identity`, `0..n`),
        (`import`, `0..n`),
        (`include`, `0..n`),
        (`namespace`, `1`),
        (`organization`, `0..1`),
        (`prefix`, `1`),
        (`reference`, `0..1`),
        (`revision`, `0..n`),
        (`rpc`, `0..n`),
        (`typedef`, `0..n`),
        (`yang-version`, `1`),
    ),
]
## Source: RFC 7950 section 7.5.2, "The container's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.5
comptime CONTAINER_SPEC = YangConstructSpec[
    `container`,
    yarg.IdentifierArgument,
    COMMON_DATA_NODES,
    fields[11](
        (`action`, `0..n`),
        (`config`, `0..1`),
        (`description`, `0..1`),
        (`grouping`, `0..n`),
        (`if-feature`, `0..n`),
        (`must`, `0..n`),
        (`presence`, `0..1`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`typedef`, `0..n`),
        (`when`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.8.1, "The list's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.8
comptime LIST_SPEC = YangConstructSpec[
    `list`,
    yarg.IdentifierArgument,
    COMMON_DATA_NODES,
    fields[15](
        (`action`, `0..n`),
        (`config`, `0..1`),
        (`description`, `0..1`),
        (`grouping`, `0..n`),
        (`if-feature`, `0..n`),
        (`key`, `0..1`),
        (`max-elements`, `0..1`),
        (`min-elements`, `0..1`),
        (`must`, `0..n`),
        (`ordered-by`, `0..1`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`typedef`, `0..n`),
        (`unique`, `0..n`),
        (`when`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.6.2, "The leaf's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.6
comptime LEAF_SPEC = YangConstructSpec[
    `leaf`,
    yarg.IdentifierArgument,
    fields[0](),
    fields[11](
        (`config`, `0..1`),
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`mandatory`, `0..1`),
        (`must`, `0..n`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`type`, `1`),
        (`units`, `0..1`),
        (`when`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.7.3, "The leaf-list's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.7
comptime LEAF_LIST_SPEC = YangConstructSpec[
    `leaf-list`,
    yarg.IdentifierArgument,
    fields[0](),
    fields[13](
        (`config`, `0..1`),
        (`default`, `0..n`),
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`max-elements`, `0..1`),
        (`min-elements`, `0..1`),
        (`must`, `0..n`),
        (`ordered-by`, `0..1`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`type`, `1`),
        (`units`, `0..1`),
        (`when`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.3.1, "The typedef's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.3
comptime TYPEDEF_SPEC = YangConstructSpec[
    `typedef`,
    yarg.IdentifierArgument,
    fields[0](),
    fields[6](
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`type`, `1`),
        (`units`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.4.1, "The type's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.4
## The `type` argument is an `identifier-ref` (built-in name or `prefix:typedef`).
comptime TYPE_SPEC = YangConstructSpec[
    `type`,
    yarg.QNameArgument,
    fields[1]((`type`, `0..n`)),
    fields[9](
        (`base`, `0..n`),
        (`bit`, `0..n`),
        (`enum`, `0..n`),
        (`fraction-digits`, `0..1`),
        (`length`, `0..1`),
        (`path`, `0..1`),
        (`pattern`, `0..n`),
        (`range-stmt`, `0..1`),
        (`require-instance`, `0..1`),
    ),
]
## Source: RFC 7950 section 9.6.4.1, "The enum's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-9.6.4
comptime ENUM_STMT_SPEC = YangConstructSpec[
    `enum`,
    yarg.IdentifierArgument,
    fields[0](),
    fields[5](
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`value`, `0..1`),
    ),
]
## Source: RFC 7950 section 9.4.4.1, "The length's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-9.4.4
comptime LENGTH_STMT_SPEC = YangConstructSpec[
    `length`,
    yarg.LengthArgument,
    fields[0](),
    fields[4](
        (`description`, `0..1`),
        (`error-app-tag`, `0..1`),
        (`error-message`, `0..1`),
        (`reference`, `0..1`),
    ),
]
## Source: RFC 7950 section 9.4.5.1, "The pattern's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-9.4.5
comptime PATTERN_STMT_SPEC = YangConstructSpec[
    `pattern`,
    yarg.PatternArgument,
    fields[0](),
    fields[5](
        (`description`, `0..1`),
        (`error-app-tag`, `0..1`),
        (`error-message`, `0..1`),
        (`modifier`, `0..1`),
        (`reference`, `0..1`),
    ),
]
## Source: RFC 7950 section 9.7.4.1, "The bit's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-9.7.4
comptime BIT_SPEC = YangConstructSpec[
    `bit`,
    yarg.IdentifierArgument,
    fields[0](),
    fields[5](
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`position`, `0..1`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
    ),
]
## Source: RFC 7950 section 9.2.4.1, "The range's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-9.2.4
comptime RANGE_STMT_SPEC = YangConstructSpec[
    `range-stmt`,
    yarg.RangeArgument,
    fields[0](),
    fields[4](
        (`description`, `0..1`),
        (`error-app-tag`, `0..1`),
        (`error-message`, `0..1`),
        (`reference`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.12.1, "The grouping's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.12
comptime GROUPING_SPEC = YangConstructSpec[
    `grouping`,
    yarg.IdentifierArgument,
    COMMON_DATA_NODES,
    fields[6](
        (`action`, `0..n`),
        (`description`, `0..1`),
        (`grouping`, `0..n`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`typedef`, `0..n`),
    ),
]
## Source: RFC 7950 section 7.9.1, "The choice's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.9
comptime CHOICE_SPEC = YangConstructSpec[
    `choice`,
    yarg.IdentifierArgument,
    fields[8](
        (`anydata`, `0..n`),
        (`anyxml`, `0..n`),
        (`case`, `0..n`),
        (`choice`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
    ),
    fields[8](
        (`config`, `0..1`),
        (`default`, `0..1`),
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`mandatory`, `0..1`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`when`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.9.2.1, "The case's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.9
comptime CASE_SPEC = YangConstructSpec[
    `case`,
    yarg.IdentifierArgument,
    fields[8](
        (`anydata`, `0..n`),
        (`anyxml`, `0..n`),
        (`choice`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`uses`, `0..n`),
    ),
    fields[5](
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`when`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.1.9.1, "The revision's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.1.9
comptime REVISION_SPEC = YangConstructSpec[
    `revision`,
    yarg.RevisionDateArgument,
    fields[0](),
    fields[2](
        (`description`, `0..1`),
        (`reference`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.5.4, "The must's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.5
comptime MUST_SPEC = YangConstructSpec[
    `must`,
    yarg.XPathExpressionArgument,
    fields[0](),
    fields[4](
        (`description`, `0..1`),
        (`error-app-tag`, `0..1`),
        (`error-message`, `0..1`),
        (`reference`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.18.1, "The identity's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.18
comptime IDENTITY_SPEC = YangConstructSpec[
    `identity`,
    yarg.IdentifierArgument,
    fields[0](),
    fields[5](
        (`base`, `0..n`),
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.20.1, "The feature's Substatements".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.20
comptime FEATURE_SPEC = YangConstructSpec[
    `feature`,
    yarg.IdentifierArgument,
    fields[0](),
    fields[4](
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
    ),
]
## Source: RFC 7950 section 7.17, "The augment Statement".
## https://datatracker.ietf.org/doc/html/rfc7950#section-7.17
comptime AUGMENT_SPEC = YangConstructSpec[
    `augment`,
    yarg.PathArgument,
    fields[10](
        (`action`, `0..n`),
        (`anydata`, `0..n`),
        (`anyxml`, `0..n`),
        (`case`, `0..n`),
        (`choice`, `0..n`),
        (`container`, `0..n`),
        (`leaf`, `0..n`),
        (`leaf-list`, `0..n`),
        (`list`, `0..n`),
        (`notification`, `0..n`),
    ),
    fields[5](
        (`description`, `0..1`),
        (`if-feature`, `0..n`),
        (`reference`, `0..1`),
        (`status`, `0..1`),
        (`when`, `0..1`),
    ),
]


## Table rows for `augment` and `identity` must be composite specs (RFC 7950 §7.17,
## §7.18): a scalar-only row rejects every substatement and breaks real modules.
def build_spec_table() raises -> RuntimeConstructSpec.Table:
    var specs = RuntimeConstructSpec.Table(
        fill=RuntimeConstructSpec.scalar[`<INVALID>`, yarg.NoArgument]()
    )

    def add_spec[Spec: YangConstructSpecTrait]() {mut specs}:
        specs[Spec.KEYWORD] = RuntimeConstructSpec.from_comptime[Spec]()

    def add_scalar_spec[kw: Keyword, arg_t: YangArgument]() {mut specs}:
        specs[kw] = RuntimeConstructSpec.scalar[kw, arg_t]()

    add_scalar_spec[`action`, yarg.IdentifierArgument]()
    add_scalar_spec[`anydata`, yarg.IdentifierArgument]()
    add_scalar_spec[`anyxml`, yarg.IdentifierArgument]()
    add_spec[AUGMENT_SPEC]()
    add_scalar_spec[`base`, yarg.QNameArgument]()
    add_spec[BIT_SPEC]()
    add_spec[CASE_SPEC]()
    add_spec[CHOICE_SPEC]()
    add_scalar_spec[`config`, yarg.BoolArgument]()
    add_scalar_spec[`contact`, yarg.StringArgument]()
    add_spec[CONTAINER_SPEC]()
    add_scalar_spec[`default`, yarg.StringArgument]()
    add_scalar_spec[`description`, yarg.StringArgument]()
    add_scalar_spec[`deviation`, yarg.PathArgument]()
    add_spec[ENUM_STMT_SPEC]()
    add_scalar_spec[`error-app-tag`, yarg.StringArgument]()
    add_scalar_spec[`error-message`, yarg.StringArgument]()
    add_scalar_spec[`extension`, yarg.IdentifierArgument]()
    add_spec[FEATURE_SPEC]()
    add_scalar_spec[`fraction-digits`, yarg.FractionDigitsArgument]()
    add_spec[GROUPING_SPEC]()
    add_spec[IDENTITY_SPEC]()
    add_scalar_spec[`if-feature`, yarg.StringArgument]()
    add_scalar_spec[`import`, yarg.IdentifierArgument]()
    add_scalar_spec[`include`, yarg.IdentifierArgument]()
    add_scalar_spec[`key`, yarg.KeyArgument]()
    add_spec[LEAF_SPEC]()
    add_spec[LEAF_LIST_SPEC]()
    add_spec[LENGTH_STMT_SPEC]()
    add_spec[LIST_SPEC]()
    add_scalar_spec[`mandatory`, yarg.BoolArgument]()
    add_scalar_spec[`max-elements`, yarg.MaxElementsArgument]()
    add_scalar_spec[`min-elements`, yarg.MinElementsArgument]()
    add_scalar_spec[`modifier`, yarg.ModifierArgument]()
    add_spec[MODULE_SPEC]()
    add_spec[MUST_SPEC]()
    add_scalar_spec[`namespace`, yarg.StringArgument]()
    add_scalar_spec[`notification`, yarg.IdentifierArgument]()
    add_scalar_spec[`organization`, yarg.StringArgument]()
    add_scalar_spec[`ordered-by`, yarg.OrderedByArgument]()
    add_scalar_spec[`path`, yarg.PathArgument]()
    add_spec[PATTERN_STMT_SPEC]()
    add_scalar_spec[`position`, yarg.PositionArgument]()
    add_scalar_spec[`prefix`, yarg.IdentifierArgument]()
    add_scalar_spec[`presence`, yarg.StringArgument]()
    add_spec[RANGE_STMT_SPEC]()
    add_scalar_spec[`reference`, yarg.StringArgument]()
    add_scalar_spec[`require-instance`, yarg.BoolArgument]()
    add_spec[REVISION_SPEC]()
    add_scalar_spec[`rpc`, yarg.IdentifierArgument]()
    add_scalar_spec[`status`, yarg.StatusArgument]()
    add_spec[TYPE_SPEC]()
    add_spec[TYPEDEF_SPEC]()
    add_scalar_spec[`unique`, yarg.UniqueArgument]()
    add_scalar_spec[`units`, yarg.StringArgument]()
    add_scalar_spec[`uses`, yarg.QNameArgument]()
    add_scalar_spec[`value`, yarg.EnumArgument]()
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
