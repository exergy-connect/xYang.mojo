## Minimal recursive subset of `lookup_table.mojo`:
##
##   module -> container -> list -> leaf
##
## This version encodes allowed fields with the same table-construction pattern
## as `test_func_spec.mojo`.
##
##   pixi run mojo -I . -I examples examples/lookup_table_subset.mojo

from std.memory import UnsafePointer

from ast import AstLexer, YangConstruct, parse_module

comptime Kw = UInt8
comptime ConstructPtr = UnsafePointer[YangConstruct, MutAnyOrigin]

## Cardinality of a child keyword under its parent (YANG-style).
comptime Cardinality = UInt8
comptime `0`: Cardinality = 0
comptime `1`: Cardinality = 1
comptime `0..1`: Cardinality = 2
comptime `0..n`: Cardinality = 3
comptime `1..n`: Cardinality = 4

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

comptime RuleTable = InlineArray[Cardinality, KEYWORD_COUNT]
comptime FIELD = Tuple[Kw, Cardinality]


def fields[n: Int](*fieldlist: FIELD) -> RuleTable:
    var table = InlineArray[Cardinality, KEYWORD_COUNT](fill=`0`)
    comptime for i in range(n):
        table[Int(fieldlist[i][0])] = fieldlist[i][1]
    return table


def keyword_spelling(idx: Kw) -> String:
    return SPELLING[idx]


def keyword_id(name: String) raises -> Kw:
    for i in range(KEYWORD_COUNT):
        if name == SPELLING[i]:
            return Kw(i)
    raise Error("Unknown keyword `" + name + "`")


def cardinality_label(card: Cardinality) -> String:
    if card == `0`:
        return "0"
    if card == `1`:
        return "1"
    if card == `0..1`:
        return "0..1"
    if card == `0..n`:
        return "0..n"
    if card == `1..n`:
        return "1..n"
    return "?"


def check_cardinality(name: String, card: Cardinality, count: Int) raises:
    if card == `0`:
        if count != 0:
            raise Error(
                "`" + name + "` must not appear (0), found " + String(count)
            )
    elif card == `1`:
        if count != 1:
            raise Error(
                "`"
                + name
                + "` must appear exactly once (1), found "
                + String(count)
            )
    elif card == `0..1`:
        if count > 1:
            raise Error(
                "`"
                + name
                + "` may appear at most once (0..1), found "
                + String(count)
            )
    elif card == `0..n`:
        pass
    elif card == `1..n`:
        if count < 1:
            raise Error(
                "`"
                + name
                + "` must appear at least once (1..n), found "
                + String(count)
            )


@fieldwise_init
struct YangConstructSpec(Copyable, ImplicitlyCopyable, Movable):
    var parent: Kw
    var has_argument: Bool
    var allowed_fields: RuleTable


comptime YANG_MODULE = YangConstructSpec(
    parent=`module`,
    has_argument=True,
    allowed_fields=fields[2]((`container`, `1..n`), (`description`, `0..1`)),
)

comptime YANG_CONTAINER = YangConstructSpec(
    parent=`container`,
    has_argument=True,
    allowed_fields=fields[1]((`list`, `1..n`)),
)

comptime YANG_LIST = YangConstructSpec(
    parent=`list`,
    has_argument=True,
    allowed_fields=fields[1]((`leaf`, `0..n`)),
)

comptime YANG_LEAF = YangConstructSpec(
    parent=`leaf`,
    has_argument=True,
    allowed_fields=fields[0](),
)

comptime YANG_DESCRIPTION = YangConstructSpec(
    parent=`description`,
    has_argument=True,
    allowed_fields=fields[0](),
)


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
def validate[spec: YangConstructSpec](construct: ConstructPtr) raises:
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
        if spec.allowed_fields[Int(child_kw)] == `0`:
            raise Error(
                "Unknown substatement `"
                + child[].keyword
                + "` in `"
                + expected_name
                + "`"
            )
        counts[Int(child_kw)] += 1

    for i in range(KEYWORD_COUNT):
        check_cardinality(
            keyword_spelling(Kw(i)),
            spec.allowed_fields[i],
            counts[i],
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


def describe_construct[spec: YangConstructSpec]() -> String:
    var out = keyword_spelling(spec.parent)
    if spec.has_argument:
        out += "(...)"
    out += " { "

    var emitted = False
    for i in range(KEYWORD_COUNT):
        var card = spec.allowed_fields[i]
        if card != `0`:
            if emitted:
                out += ", "
            out += keyword_spelling(Kw(i))
            out += "["
            out += cardinality_label(card)
            out += "]"
            emitted = True

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
