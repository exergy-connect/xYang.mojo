import xyang.yang.arguments as yarg
from xyang.yang.arguments import YangArgument
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.cardinality import (
    Cardinality,
    FieldRule,
    check_cardinality,
    `0`,
)
from xyang.yang.keyword import Keyword

comptime ArgumentParser = def(mut YangConstruct) raises thin -> None

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


comptime RuleTable = InlineArray[FieldRule, KEYWORD_COUNT]
comptime FIELD = Tuple[Keyword, Cardinality]


def fields[n: Int](*fieldlist: FIELD) -> RuleTable:
    var table = InlineArray[FieldRule, KEYWORD_COUNT](fill=FieldRule(`0`))
    comptime for i in range(n):
        table[Int(fieldlist[i][0])] = FieldRule(fieldlist[i][1])
    return table


trait YangConstructSpecTrait(Movable):
    comptime KEYWORD: Keyword
    comptime ARGUMENT_TYPE: YangArgument

    @staticmethod
    def allowed_fields() -> RuleTable:
        ...


@always_inline
def _parse_argument[Arg: YangArgument](mut node: YangConstruct) raises -> None:
    Arg.parse_and_store(node)


@fieldwise_init
struct RuntimeConstructSpec(Copyable, ImplicitlyCopyable, Movable):
    comptime Table = InlineArray[Self, KEYWORD_COUNT]

    var kw: Keyword
    var parse_argument: ArgumentParser
    var allowed_fields: RuleTable

    @staticmethod
    def from_comptime[spec: YangConstructSpecTrait]() -> Self:
        return RuntimeConstructSpec(
            kw=spec.KEYWORD,
            parse_argument=_parse_argument[spec.ARGUMENT_TYPE],
            allowed_fields=spec.allowed_fields(),
        )

    @staticmethod
    def scalar[kw: Keyword, arg_t: yarg.YangArgument]() -> Self:
        return RuntimeConstructSpec(
            kw=kw,
            parse_argument=_parse_argument[arg_t],
            allowed_fields=fields[0](),
        )

    def validate(
        read self, mut node: YangConstruct, read specs: Self.Table
    ) raises:
        var expected_name = keyword_spelling(self.kw)
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
        self.parse_argument(node)

        if len(self.allowed_fields) == 0:
            for child in node.children:
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
            node.spec = self.kw
            return

        var counts = InlineArray[Int, KEYWORD_COUNT](fill=0)
        for child in node.children:
            var child_kw = keyword_id(child[].keyword, child[].line)
            var rule = self.allowed_fields[Int(child_kw)]
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
                self.allowed_fields[i].cardinality,
                counts[i],
                node.line,
            )

        node.spec = self.kw
        for child in node.children:
            var child_kw = keyword_id(child[].keyword, child[].line)
            ref child_spec = specs[Int(child_kw)]
            child_spec.validate(child[], specs)

