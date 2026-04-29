## Data-only mirror of the **composite** productions in `yang_ebnf.mojo`: each
## statement is a **`YangConstructSpec`** — parent keyword id, `has_argument`
## (same meaning as `CompositeFieldDefinition` in `structure.mojo`), and a
## dense **`Span[Kw, _]`** over a comptime child keyword table (`Kw` = `UInt8`).
## `YangConstructLookup.describe_spec` selects by parent `Kw`.
## `SPELLING[id]` is the RFC 7950 / YANG spelling (ids 0–5 are the original small
## keyword subset).
##
##   pixi run mojo -I examples examples/lookup_table.mojo

from std.memory import Span

comptime Kw = UInt8

comptime KwSpan = Span[Kw, _]

comptime `enum`: Kw = 0
comptime `module`: Kw = 1
comptime `import`: Kw = 2
comptime `type`: Kw = 3
comptime `leaf`: Kw = 4
comptime `typedef`: Kw = 5
comptime `bit`: Kw = 6
comptime `case`: Kw = 7
comptime `choice`: Kw = 8
comptime `container`: Kw = 9
comptime `contact`: Kw = 10
comptime `default`: Kw = 11
comptime `description`: Kw = 12
comptime `error-message`: Kw = 13
comptime `fraction-digits`: Kw = 14
comptime `grouping`: Kw = 15
comptime `key`: Kw = 16
comptime `leaf-list`: Kw = 17
comptime `length`: Kw = 18
comptime `list`: Kw = 19
comptime `mandatory`: Kw = 20
comptime `max-elements`: Kw = 21
comptime `min-elements`: Kw = 22
comptime `must`: Kw = 23
comptime `namespace`: Kw = 24
comptime `organization`: Kw = 25
comptime `path`: Kw = 26
comptime `pattern`: Kw = 27
comptime `position`: Kw = 28
comptime `prefix`: Kw = 29
comptime `presence`: Kw = 30
## `_range`: RFC `range` token id (name avoids shadowing the `range` builtin).
comptime _range: Kw = 31
comptime `reference`: Kw = 32
comptime `refine`: Kw = 33
comptime `require-instance`: Kw = 34
comptime `revision`: Kw = 35
comptime `status`: Kw = 36
comptime `uses`: Kw = 37
comptime `value`: Kw = 38
comptime `when`: Kw = 39
comptime `yang-version`: Kw = 40

comptime KEYWORD_COUNT: Int = 41


## Index **must** match each token’s numeric id above.
comptime SPELLING: InlineArray[String, KEYWORD_COUNT] = [
    "enum",
    "module",
    "import",
    "type",
    "leaf",
    "typedef",
    "bit",
    "case",
    "choice",
    "container",
    "contact",
    "default",
    "description",
    "error-message",
    "fraction-digits",
    "grouping",
    "key",
    "leaf-list",
    "length",
    "list",
    "mandatory",
    "max-elements",
    "min-elements",
    "must",
    "namespace",
    "organization",
    "path",
    "pattern",
    "position",
    "prefix",
    "presence",
    "range",
    "reference",
    "refine",
    "require-instance",
    "revision",
    "status",
    "uses",
    "value",
    "when",
    "yang-version",
]


def keyword_spelling(idx: Kw) -> String:
    return SPELLING[idx]


@fieldwise_init
struct YangConstructSpec[origin: ImmutOrigin](Copyable, ImplicitlyCopyable, Movable):
    ## Children are in the same order as the `CompositeFieldDefinition` field
    ## list in `yang_ebnf.mojo`.
    var parent: Kw
    var has_argument: Bool
    var children: KwSpan[Self.origin]


## --- Composites from `yang_ebnf.mojo` (same `FieldDefs` order) --------------------

comptime REVISION_CHILDREN: InlineArray[Kw, 1] = [`description`]

comptime YANG_REVISION = YangConstructSpec(
    parent=`revision`,
    has_argument=True,
    children=KwSpan(REVISION_CHILDREN),
)

comptime ENUM_CHILDREN: InlineArray[Kw, 4] = [
    `value`,
    `status`,
    `description`,
    `reference`,
]

comptime YANG_ENUM = YangConstructSpec(
    parent=`enum`,
    has_argument=True,
    children=KwSpan(ENUM_CHILDREN),
)

comptime BIT_CHILDREN: InlineArray[Kw, 4] = [
    `position`,
    `status`,
    `description`,
    `reference`,
]

comptime YANG_BIT = YangConstructSpec(
    parent=`bit`,
    has_argument=True,
    children=KwSpan(BIT_CHILDREN),
)

comptime UNION_MEMBER_TYPE_CHILDREN: InlineArray[Kw, 9] = [
    `path`,
    `require-instance`,
    `enum`,
    `bit`,
    `pattern`,
    `length`,
    _range,
    `fraction-digits`,
    `description`,
]

comptime YANG_UNION_MEMBER_TYPE = YangConstructSpec(
    parent=`type`,
    has_argument=True,
    children=KwSpan(UNION_MEMBER_TYPE_CHILDREN),
)

comptime TYPE_CHILDREN: InlineArray[Kw, 10] = [
    `type`,
    `path`,
    `require-instance`,
    `enum`,
    `bit`,
    `pattern`,
    `length`,
    _range,
    `fraction-digits`,
    `description`,
]

comptime YANG_TYPE = YangConstructSpec(
    parent=`type`,
    has_argument=True,
    children=KwSpan(TYPE_CHILDREN),
)

comptime TYPEDEF_CHILDREN: InlineArray[Kw, 2] = [`type`, `description`]

comptime YANG_TYPEDEF = YangConstructSpec(
    parent=`typedef`,
    has_argument=True,
    children=KwSpan(TYPEDEF_CHILDREN),
)

comptime MUST_CHILDREN: InlineArray[Kw, 2] = [`error-message`, `description`]

comptime YANG_MUST = YangConstructSpec(
    parent=`must`,
    has_argument=True,
    children=KwSpan(MUST_CHILDREN),
)

comptime WHEN_CHILDREN: InlineArray[Kw, 1] = [`description`]

comptime YANG_WHEN = YangConstructSpec(
    parent=`when`,
    has_argument=True,
    children=KwSpan(WHEN_CHILDREN),
)

comptime REFINE_CHILDREN: InlineArray[Kw, 3] = [`type`, `must`, `description`]

comptime YANG_REFINE = YangConstructSpec(
    parent=`refine`,
    has_argument=True,
    children=KwSpan(REFINE_CHILDREN),
)

comptime USES_CHILDREN: InlineArray[Kw, 2] = [`refine`, `when`]

comptime YANG_USES = YangConstructSpec(
    parent=`uses`,
    has_argument=True,
    children=KwSpan(USES_CHILDREN),
)

comptime LEAF_CHILDREN: InlineArray[Kw, 6] = [
    `type`,
    `mandatory`,
    `default`,
    `when`,
    `description`,
    `must`,
]

comptime YANG_LEAF = YangConstructSpec(
    parent=`leaf`,
    has_argument=True,
    children=KwSpan(LEAF_CHILDREN),
)

comptime LEAF_LIST_CHILDREN: InlineArray[Kw, 6] = [
    `type`,
    `min-elements`,
    `max-elements`,
    `when`,
    `description`,
    `must`,
]

comptime YANG_LEAF_LIST_STMT = YangConstructSpec(
    parent=`leaf-list`,
    has_argument=True,
    children=KwSpan(LEAF_LIST_CHILDREN),
)

comptime CONTAINER_CHILDREN: InlineArray[Kw, 7] = [
    `presence`,
    `when`,
    `description`,
    `must`,
    `leaf`,
    `leaf-list`,
    `uses`,
]

comptime YANG_CONTAINER = YangConstructSpec(
    parent=`container`,
    has_argument=True,
    children=KwSpan(CONTAINER_CHILDREN),
)

comptime LIST_CHILDREN: InlineArray[Kw, 10] = [
    `key`,
    `min-elements`,
    `max-elements`,
    `when`,
    `description`,
    `must`,
    `leaf`,
    `leaf-list`,
    `container`,
    `uses`,
]

comptime YANG_LIST = YangConstructSpec(
    parent=`list`,
    has_argument=True,
    children=KwSpan(LIST_CHILDREN),
)

comptime CASE_CHILDREN: InlineArray[Kw, 6] = [
    `description`,
    `leaf`,
    `leaf-list`,
    `container`,
    `list`,
    `uses`,
]

comptime YANG_CASE = YangConstructSpec(
    parent=`case`,
    has_argument=True,
    children=KwSpan(CASE_CHILDREN),
)

comptime CHOICE_CHILDREN: InlineArray[Kw, 3] = [
    `mandatory`,
    `description`,
    `case`,
]

comptime YANG_CHOICE = YangConstructSpec(
    parent=`choice`,
    has_argument=True,
    children=KwSpan(CHOICE_CHILDREN),
)

comptime GROUPING_CHILDREN: InlineArray[Kw, 7] = [
    `description`,
    `leaf`,
    `leaf-list`,
    `container`,
    `list`,
    `choice`,
    `uses`,
]

comptime YANG_GROUPING = YangConstructSpec(
    parent=`grouping`,
    has_argument=True,
    children=KwSpan(GROUPING_CHILDREN),
)

comptime MODULE_CHILDREN: InlineArray[Kw, 14] = [
    `yang-version`,
    `namespace`,
    `prefix`,
    `organization`,
    `contact`,
    `description`,
    `revision`,
    `typedef`,
    `grouping`,
    `container`,
    `list`,
    `leaf`,
    `leaf-list`,
    `choice`,
]

comptime YANG_MODULE = YangConstructSpec(
    parent=`module`,
    has_argument=True,
    children=KwSpan(MODULE_CHILDREN),
)


struct YangConstructLookup:
    ## Comptime dispatch on parent statement keyword id (`Kw`).
    ## Note: both full `type-stmt` and union-member `type` use keyword `` `type` ``;
    ## this returns **`YANG_TYPE`** (10 children). Use **`YANG_UNION_MEMBER_TYPE`**
    ## directly for the 9-child union-member shape.
    @staticmethod
    def describe_spec[parent: Kw]() raises -> String:
        comptime if parent == `revision`:
            return describe_construct[YANG_REVISION]()
        elif parent == `enum`:
            return describe_construct[YANG_ENUM]()
        elif parent == `bit`:
            return describe_construct[YANG_BIT]()
        elif parent == `type`:
            return describe_construct[YANG_TYPE]()
        elif parent == `typedef`:
            return describe_construct[YANG_TYPEDEF]()
        elif parent == `must`:
            return describe_construct[YANG_MUST]()
        elif parent == `when`:
            return describe_construct[YANG_WHEN]()
        elif parent == `refine`:
            return describe_construct[YANG_REFINE]()
        elif parent == `uses`:
            return describe_construct[YANG_USES]()
        elif parent == `leaf`:
            return describe_construct[YANG_LEAF]()
        elif parent == `leaf-list`:
            return describe_construct[YANG_LEAF_LIST_STMT]()
        elif parent == `container`:
            return describe_construct[YANG_CONTAINER]()
        elif parent == `list`:
            return describe_construct[YANG_LIST]()
        elif parent == `case`:
            return describe_construct[YANG_CASE]()
        elif parent == `choice`:
            return describe_construct[YANG_CHOICE]()
        elif parent == `grouping`:
            return describe_construct[YANG_GROUPING]()
        elif parent == `module`:
            return describe_construct[YANG_MODULE]()
        raise Error(
            "describe_spec: no composite table for this parent keyword id"
        )


def describe_construct[spec: YangConstructSpec[_]]() -> String:
    var out = keyword_spelling(spec.parent)
    if spec.has_argument:
        out += "(…)"
    out += " { "
    var children = spec.children
    for i in range(len(children)):
        if i > 0:
            out += ", "
        out += keyword_spelling(children[i])
    out += " }"
    return out^


def main() raises:
    print(keyword_spelling(`enum`))
    print(describe_construct[YANG_LEAF]())
    print(describe_construct[YANG_TYPE]())
    print(describe_construct[YANG_MODULE]())
    print(YangConstructLookup.describe_spec[`leaf`]())
