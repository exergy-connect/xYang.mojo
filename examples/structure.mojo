## Minimal compile-time field metadata for YANG-style statements.
##
##   pixi run mojo examples/structure.mojo

from std.collections import Dict, List
from std.iter import Iterable, Iterator
from std.builtin.variadics import TypeList
from std.memory import ArcPointer

from ast import AstLexer, AstToken, YangConstruct, is_name_token, parse_statement_after_keyword

from std.reflection import (
    struct_field_count,
    struct_field_names,
    get_type_name,
    struct_field_types,
)


trait ParseFromConstruct:
    @staticmethod
    def from_construct(ref construct: YangConstruct) raises -> Self:
        ...

    def __str__(ref self) -> String:
        ...


trait Buildable:
    def build(mut self, ref construct: YangConstruct) raises:
        ...


comptime YangScalarTraits = ParseFromConstruct & Copyable & Movable & ImplicitlyDestructible & Defaultable


def parse_yang_string(argument: String) raises -> String:
    return argument.copy()


def parse_yang_int(argument: String) raises -> Int:
    return atol(argument)


def parse_yang_bool(argument: String) raises -> Bool:
    if argument == "true":
        return True
    if argument == "false":
        return False
    raise Error("Expected boolean argument, got `" + argument + "`")


@fieldwise_init
struct YangScalar[
    ValueType: Writable & Copyable & Movable & ImplicitlyDestructible,
    parse_method: def(String) raises thin -> ValueType,
](YangScalarTraits):
    var value: Optional[Self.ValueType]

    def __init__(out self):
        self.value = Optional[Self.ValueType]()

    @staticmethod
    def from_construct(ref construct: YangConstruct) raises -> Self:
        if not construct.argument:
            raise Error("Expected argument for `" + construct.keyword + "`")
        return Self(
            value=Optional[Self.ValueType](
                Self.parse_method(construct.argument.value())
            )
        )

    def __str__(ref self) -> String:
        var output = String()
        if self.value:
            output.write(self.value.value())
        return output


comptime YangString = YangScalar[String, parse_yang_string]
comptime YangInt = YangScalar[Int, parse_yang_int]
comptime YangBool = YangScalar[Bool, parse_yang_bool]


trait YANGField:
    @staticmethod
    def name() -> String:
        ...


comptime FieldTraits = YANGField & Defaultable & ParseFromConstruct & Buildable & Movable & ImplicitlyDestructible


@fieldwise_init
struct FieldDefinition[
    field_name: StringLiteral,
    ValueType: YangScalarTraits,
](FieldTraits):
    ## `field_name`: YANG keyword for this substatement.
    ## `ValueType`: type of its argument after parsing (here: plain string → `String`).
    ## `data`: stored argument value for this field instance.
    ## For an iterable `ValueType` (e.g. `List[…]`) and `for` loops, use
    ## `IterableFieldDefinition` or iterate `self.data` directly.

    comptime ArgumentType = Self.ValueType

    var data: Optional[Self.ValueType]

    def __init__(out self):
        self.data = Optional[Self.ValueType]()

    @staticmethod
    def name() -> String:
        return Self.field_name

    def __str__(ref self) -> String:
        return (
            Self.field_name
            + ": "
            + self.data.value().__str__()
            + "\n" if self.data else ""
        )

    @staticmethod
    def from_construct(ref construct: YangConstruct) raises -> Self:
        var field = Self()
        field.build(construct)
        return field^

    def build(mut self, ref construct: YangConstruct) raises:
        if construct.keyword != Self.field_name:
            raise Error(
                "Expected `"
                + Self.field_name
                + "`, got `"
                + construct.keyword
                + "`"
            )
        self.data = Self.ValueType.from_construct(construct)


@fieldwise_init
struct RepeatedField[
    FieldType: FieldTraits,
](FieldTraits & Iterable):
    ## Like `FieldDefinition`, but the payload type is `Iterable` and this struct
    ## is iterable (delegates to `data`).

    comptime ListType = List[ArcPointer[Self.FieldType]]

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = Self.ListType.IteratorType[
        iterable_mut=iterable_mut,
        iterable_origin=iterable_origin,
    ]

    var data: Self.ListType

    def __init__(out self):
        self.data = Self.ListType()

    @staticmethod
    def name() -> String:
        return Self.FieldType.name()

    @staticmethod
    def from_construct(ref construct: YangConstruct) raises -> Self:
        var newField = Self(data=List[ArcPointer[Self.FieldType]]())
        newField.build(construct)
        return newField^

    def __str__(ref self) -> String:
        var result = String()
        for field in self.data:
            result += field[].__str__()
        return result

    def build(mut self, ref construct: YangConstruct) raises:
        var newField = Self.FieldType.from_construct(construct)
        self.data.append(ArcPointer[Self.FieldType](newField^))

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return rebind_var[Self.IteratorType[origin_of(self)]](
            self.data.__iter__()
        )


@fieldwise_init
struct CompositeFieldDefinition[
    field_name: StringLiteral, has_argument: Bool, *FieldDefs: FieldTraits
](FieldTraits):
    var argument: Optional[String]
    var data: Tuple[*Self.FieldDefs]

    def __init__(out self):
        self.argument = Optional[String]()
        self.data = Tuple[*Self.FieldDefs]()

    @staticmethod
    def name() -> String:
        return Self.field_name

    def __str__(ref self) -> String:
        var result = String(Self.field_name)
        if self.argument:
            result += "(" + self.argument.value() + ") "
        comptime for i in range(len(Self.FieldDefs)):
            ref field = self.data[i]
            result += field.__str__()
        return result

    @staticmethod
    def populate_field_index_table(out field_table: Dict[String, Int]):
        field_table = Dict[String, Int]()
        comptime for i in range(len(Self.FieldDefs)):
            field_table[Self.FieldDefs[i].name()] = i

    @staticmethod
    def from_construct(ref construct: YangConstruct) raises -> Self:
        var newField = Self(
            argument=Optional[String](), data=Tuple[*Self.FieldDefs]()
        )
        newField.build(construct)
        return newField^

    def build(mut self, ref construct: YangConstruct) raises:
        if construct.keyword != Self.field_name:
            raise Error(
                "Expected `"
                + Self.field_name
                + "`, got `"
                + construct.keyword
                + "`"
            )
        if Self.has_argument:
            if not construct.argument:
                raise Error("Expected argument for `" + Self.field_name + "`")
            self.argument = Optional[String](construct.argument.value().copy())
        elif construct.argument:
            raise Error("Unexpected argument for `" + Self.field_name + "`")

        var field_table = Self.populate_field_index_table()
        for child in construct.children:
            var stmt_name = child[].keyword
            if stmt_name in field_table:
                var field_index = field_table[stmt_name]
                comptime for i in range(len(Self.FieldDefs)):
                    if field_index == i:
                        self.data[i].build(child[])
                        break
            else:
                raise Error(
                    "Unknown substatement `"
                    + stmt_name
                    + "` in `"
                    + Self.field_name
                    + "`"
                )


## One comptime binding per field keyword (string appears only here).
comptime FIELD_DESCRIPTION = FieldDefinition["description", YangString]
comptime FIELD_REFERENCE = FieldDefinition["reference", YangString]


## Substatements of `must { ... }` (see `must_stmt.mojo` / `YangMust` in `ast.mojo`).
comptime FIELD_MUST_ERROR_MESSAGE = FieldDefinition["error-message", YangString]

comptime MustCompositeFields = CompositeFieldDefinition[
    "must",
    True,
    FIELD_DESCRIPTION,
    FIELD_MUST_ERROR_MESSAGE,
]
comptime FIELD_MUST = RepeatedField[MustCompositeFields]
comptime FIELD_MIN_ELEMENTS = FieldDefinition["min-elements", YangInt]
comptime FIELD_MAX_ELEMENTS = FieldDefinition["max-elements", YangInt]
comptime FIELD_ORDERED_BY = FieldDefinition["ordered-by", YangString]
comptime FIELD_MANDATORY = FieldDefinition["mandatory", YangBool]
comptime FIELD_DEFAULT = FieldDefinition["default", YangString]
comptime FIELD_IF_FEATURE = FieldDefinition["if-feature", YangString]
comptime FIELD_TYPE = FieldDefinition["type", YangString]

comptime YangRefineASTNode = CompositeFieldDefinition[
    "refine",
    True,
    FIELD_MUST,
    FIELD_DESCRIPTION,
    FIELD_MIN_ELEMENTS,
    FIELD_MAX_ELEMENTS,
    FIELD_ORDERED_BY,
    FIELD_MANDATORY,
    FIELD_DEFAULT,
    FIELD_IF_FEATURE,
    FIELD_TYPE,
]


def main() raises:
    var source = (
        'refine a/b/c { must "x>0" { description "x must be greater than'
        ' 0"; } }'
    )
    var lexer = AstLexer(source.as_bytes())
    var tok = lexer.next_token()
    if not is_name_token(tok):
        raise Error("Expected construct")
    var construct = parse_statement_after_keyword(lexer, tok.text(lexer.input))
    tok = lexer.next_token()
    if tok.type != AstToken.EOF:
        raise Error("Expected EOF after construct")
    var node = YangRefineASTNode()
    node.build(construct)
    print(node.__str__())
