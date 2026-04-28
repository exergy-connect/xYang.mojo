## Minimal compile-time field metadata for YANG-style statements.
##
##   pixi run mojo examples/structure.mojo

from std.collections import List
from std.iter import Iterable, Iterator
from std.builtin.variadics import TypeList
from std.memory import ArcPointer

from std.reflection import (
    struct_field_count, struct_field_names,
    get_type_name, struct_field_types
)

trait CreateFromString:
    @staticmethod
    def from_string(input: String) raises -> Self:
        ...

trait ParseFromString:
    def parse(mut self, input: String) raises:
        ...

comptime YangTypeTraits = CreateFromString & Copyable & Movable & ImplicitlyDestructible & Defaultable

@fieldwise_init
struct YangString(YangTypeTraits):
    var value: String

    def __init__(out self):
        self.value = String()

    @staticmethod
    def from_string(input: String) raises -> Self:
        return Self(value=input)


@fieldwise_init
struct YangInt(YangTypeTraits):
    var value: Int

    def __init__(out self):
        self.value = 0

    @staticmethod
    def from_string(input: String) raises -> Self:
        # TODO replace with actual int parser
        return Self(value=atol(input))


@fieldwise_init
struct YangBool(YangTypeTraits):
    var value: Bool

    def __init__(out self):
        self.value = False

    @staticmethod
    def from_string(input: String) raises -> Self:
        return Self(value=input == "true")

trait YANGField:
    def name(self) -> String:
        ...

comptime FieldTraits = YANGField & ParseFromString & Movable & ImplicitlyDestructible

@fieldwise_init
struct FieldDefinition[
    field_name: StringLiteral,
    ValueType: CreateFromString & Copyable & Movable & ImplicitlyDestructible,
](FieldTraits & CreateFromString):
    ## `field_name`: YANG keyword for this substatement.
    ## `ValueType`: type of its argument after parsing (here: plain string → `String`).
    ## `data`: stored argument value for this field instance.
    ## For an iterable `ValueType` (e.g. `List[…]`) and `for` loops, use
    ## `IterableFieldDefinition` or iterate `self.data` directly.

    comptime ArgumentType = Self.ValueType

    var data: Self.ValueType

    def name(self) -> String:
        return Self.field_name
    
    @staticmethod
    def from_string(input: String) raises -> Self:
        return Self(data = Self.ValueType.from_string(input))
    
    def parse(mut self, input: String) raises:
        self.data = Self.ValueType.from_string(input)

@fieldwise_init
struct FieldListDefinition[
    field_name: StringLiteral,
    FieldType: FieldTraits & CreateFromString,
](FieldTraits, Iterable):

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

    def name(self) -> String:
        return Self.field_name

    def parse(mut self, input: String) raises:
        var newField = Self.FieldType.from_string(input)
        self.data.append(ArcPointer[Self.FieldType](newField^))

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return rebind_var[Self.IteratorType[origin_of(self)]](self.data.__iter__())

@fieldwise_init
struct CompositeFieldDefinition[
    field_name: StringLiteral,
    *FieldDefs: FieldTraits ] (
    FieldTraits & CreateFromString
):
    var data: Tuple[*Self.FieldDefs]

    def name(self) -> String:
        return Self.field_name

    @staticmethod
    def from_string(input: String) raises -> Self:
        var newField = Self(data = Tuple[*Self.FieldDefs]())
        newField.parse(input)
        return newField^

    def parse(mut self, input: String) raises:
        comptime for i in range(len(Self.FieldDefs)):
            ref field = self.data[i]
            # later: route real parsed substatement tokens here
            if field.name() == input:
                _ = field.parse(input)
                return
        
        raise Error("Unknown field: " + input)

## One comptime binding per field keyword (string appears only here).
comptime FIELD_DESCRIPTION = FieldDefinition["description", YangString]
comptime FIELD_REFERENCE = FieldDefinition["reference", YangString]


## Substatements of `must { ... }` (see `must_stmt.mojo` / `YangMust` in `ast.mojo`).
comptime FIELD_MUST_EXPRESSION = FieldDefinition["expression", YangString]
comptime FIELD_MUST_ERROR_MESSAGE = FieldDefinition["error-message", YangString]

comptime MustCompositeFields = CompositeFieldDefinition[ "must",
    FIELD_MUST_EXPRESSION,
    FIELD_DESCRIPTION,
    FIELD_MUST_ERROR_MESSAGE,
]
comptime FIELD_MUST = FieldListDefinition["must", MustCompositeFields] # XXX does not work
comptime FIELD_MIN_ELEMENTS = FieldDefinition["min-elements", YangInt]
comptime FIELD_MAX_ELEMENTS = FieldDefinition["max-elements", YangInt]
comptime FIELD_ORDERED_BY = FieldDefinition["ordered-by", YangString]
comptime FIELD_MANDATORY = FieldDefinition["mandatory", YangBool]
comptime FIELD_DEFAULT = FieldDefinition["default", YangString]
comptime FIELD_IF_FEATURE = FieldDefinition["if-feature", YangString]
comptime FIELD_TYPE = FieldDefinition["type", YangString]


## Abstract AST node: `fields` is a comptime tuple of `FieldDefinition`,
## `IterableFieldDefinition`, and/or `CompositeFieldDefinition` values.
@fieldwise_init
struct YangASTNode[*FieldDefs: FieldTraits]():

    var data: Tuple[*Self.FieldDefs]

    def __init__(out self):
        self.data = Tuple[*Self.FieldDefs]()

    @staticmethod
    def field_count() -> Int:
        return Self.FieldDefs.size
    
    def parse(mut self, input: String) raises:
        comptime for f in range(Self.field_count()):
            ref field = self.data[f]
            if field.name() == input:
                _ = field.parse(input)
                return

comptime YangRefineASTNode = YangASTNode[
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
    print(
        "example node fields: "
        + String(YangRefineASTNode.field_count()),
    )
    var node = YangRefineASTNode()
    _ = node.parse("must expression description")
