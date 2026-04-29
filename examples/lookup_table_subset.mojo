## Minimal recursive subset of `lookup_table.mojo`:
##
##   module -> container -> list -> leaf
##
##   pixi run mojo -I examples examples/lookup_table_subset.mojo

from std.memory import UnsafePointer

from ast import AstLexer, YangConstruct, parse_module

comptime Kw = UInt8
comptime ConstructPtr = UnsafePointer[YangConstruct, MutAnyOrigin]
comptime ValidateConstructFn = def(ConstructPtr) thin raises
comptime ValidatorTable = InlineArray[ValidateConstructFn, KEYWORD_COUNT]

## Cardinality of a child keyword under its parent (YANG-style); comptime template
## parameter on `YangConstructChild` together with the child `Kw`.
comptime Card = UInt8
comptime `0`   : Card = 0
comptime `1`   : Card = 1
comptime `0..1`: Card = 2
comptime `0..n`: Card = 3
comptime `1..n`: Card = 4

comptime `module`: Kw = 0
comptime `container`: Kw = 1
comptime `list`: Kw = 2
comptime `leaf`: Kw = 3
comptime `description`: Kw = 4

comptime KEYWORD_COUNT: Int = 5

comptime SPELLING: InlineArray[String, KEYWORD_COUNT] = [
    "module",
    "container",
    "list",
    "leaf",
    "description",
]


def keyword_spelling(idx: Kw) -> String:
    return SPELLING[idx]


def keyword_id(name: String) raises -> Kw:
    for i in range(KEYWORD_COUNT):
        if name == SPELLING[i]:
            return Kw(i)
    raise Error("Unknown keyword `" + name + "`")


trait YangChildRuleTag(Copyable, ImplicitlyCopyable, Movable):

    @staticmethod
    def label() -> String:
        ...

    @staticmethod
    def rule_kw() -> Kw:
        ...

    @staticmethod
    def check(name: String, count: Int) raises:
        ...

@fieldwise_init
struct YangConstructChild[child_kw: Kw, card: Card = `0..1`](
    Copyable, ImplicitlyCopyable, Movable, YangChildRuleTag
):
    @staticmethod
    def rule_kw() -> Kw:
        return Self.child_kw

    @staticmethod
    def label() -> String:
        comptime if Self.card == `0`:
            return "0"
        if Self.card == `1`:
            return "1"
        if Self.card == `0..1`:
            return "0..1"
        if Self.card == `0..n`:
            return "0..n"
        if Self.card == `1..n`:
            return "1..n"
        return "?"

    @staticmethod
    def check(name: String, count: Int) raises:
        comptime if Self.card == `0`:
            if count != 0:
                raise Error(
                    "`" + name + "` must not appear (0), found " + String(count)
                )
        elif Self.card == `1`:
            if count != 1:
                raise Error(
                    "`"
                    + name
                    + "` must appear exactly once (1), found "
                    + String(count)
                )
        elif Self.card == `0..1`:
            if count > 1:
                raise Error(
                    "`"
                    + name
                    + "` may appear at most once (0..1), found "
                    + String(count)
                )
        elif Self.card == `0..n`:
            pass
        elif Self.card == `1..n`:
            if count < 1:
                raise Error(
                    "`"
                    + name
                    + "` must appear at least once (1..n), found "
                    + String(count)
                )


@fieldwise_init
struct YangConstructSpec[*ChildRuleSpecs: YangChildRuleTag](
    Copyable, ImplicitlyCopyable, Movable
):
    var parent: Kw
    var has_argument: Bool


comptime YANG_MODULE = YangConstructSpec[
    YangConstructChild[`container`, `1..n`],
    YangConstructChild[`description`, `0..1`],
](parent=`module`, has_argument=True)

comptime YANG_CONTAINER = YangConstructSpec[YangConstructChild[`list`, `1..n`]](
    parent=`container`,
    has_argument=True,
)

comptime YANG_LIST = YangConstructSpec[YangConstructChild[`leaf`, `0..n`]](
    parent=`list`,
    has_argument=True,
)

comptime YANG_LEAF = YangConstructSpec[](parent=`leaf`, has_argument=True)

comptime YANG_DESCRIPTION = YangConstructSpec[](
    parent=`description`,
    has_argument=True,
)


def child_rule_allowed[schema: YangConstructSpec[...]](kw: Kw) -> Bool:
    comptime S = type_of(schema)
    comptime for i in range(len(S.ChildRuleSpecs)):
        comptime T = S.ChildRuleSpecs[i]
        if kw == T.rule_kw():
            return True
    return False


def validate_construct_for_kw(kw: Kw, construct: ConstructPtr) raises:
    if kw == `module`:
        validate_by_keyword[`module`](construct)
    elif kw == `container`:
        validate_by_keyword[`container`](construct)
    elif kw == `list`:
        validate_by_keyword[`list`](construct)
    elif kw == `leaf`:
        validate_by_keyword[`leaf`](construct)
    elif kw == `description`:
        validate_by_keyword[`description`](construct)
    else:
        raise Error(
            "No YangConstructSpec registered for `" + keyword_spelling(kw) + "`"
        )


@no_inline
def validate[spec: YangConstructSpec[...]](construct: ConstructPtr) raises:
    comptime S = type_of(spec)
    var expected_name = keyword_spelling(spec.parent)
    if construct[].keyword != expected_name:
        raise Error(
            "Expected `"
            + expected_name
            + "`, got `"
            + construct[].keyword
            + "`"
        )

    if spec.has_argument:
        if not construct[].argument:
            raise Error("Expected argument for `" + expected_name + "`")
    elif construct[].argument:
        raise Error("Unexpected argument for `" + expected_name + "`")

    var counts = InlineArray[Int, KEYWORD_COUNT](fill=0)

    for child in construct[].children:
        var child_kw = keyword_id(child[].keyword)
        if not child_rule_allowed[spec](child_kw):
            raise Error(
                "Unknown substatement `"
                + child[].keyword
                + "` in `"
                + expected_name
                + "`"
            )
        counts[Int(child_kw)] += 1

    comptime for i in range(len(S.ChildRuleSpecs)):
        comptime T = S.ChildRuleSpecs[i]
        T.check(
            keyword_spelling(T.rule_kw()),
            counts[Int(T.rule_kw())],
        )

    for child in construct[].children:
        var child_kw = keyword_id(child[].keyword)
        var child_ptr = UnsafePointer(to=child[]).unsafe_origin_cast[
            MutAnyOrigin
        ]()
        validate_construct_for_kw(child_kw, child_ptr)


def validate_by_keyword[kw: Kw](construct: ConstructPtr) raises:
    comptime if kw == `module`:
        validate[YANG_MODULE](construct)
    elif kw == `container`:
        validate[YANG_CONTAINER](construct)
    elif kw == `list`:
        validate[YANG_LIST](construct)
    elif kw == `leaf`:
        validate[YANG_LEAF](construct)
    elif kw == `description`:
        validate[YANG_DESCRIPTION](construct)
    else:
        raise Error(
            "No YangConstructSpec registered for `" + keyword_spelling(kw) + "`"
        )


def validate_module(mut construct: YangConstruct) raises:
    var module_ptr = UnsafePointer(to=construct).unsafe_origin_cast[
        MutAnyOrigin
    ]()
    validate_by_keyword[`module`](module_ptr)


def describe_construct[spec: YangConstructSpec[...]]() -> String:
    comptime S = type_of(spec)
    var out = keyword_spelling(spec.parent)
    if spec.has_argument:
        out += "(...)"
    out += " { "

    comptime for i in range(len(S.ChildRuleSpecs)):
        comptime T = S.ChildRuleSpecs[i]
        if i > 0:
            out += ", "
        out += keyword_spelling(T.rule_kw())
        out += "["
        out += T.label()
        out += "]"

    out += " }"
    return out^


def main() raises:
    var source = String(
        "module demo { container config { list user { leaf name; leaf uid;"
        " } } }"
    )
    var lexer = AstLexer(source.as_bytes())
    var module = parse_module(lexer)
    validate_module(module)
    print(describe_construct[YANG_MODULE]())
