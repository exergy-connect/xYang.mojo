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
    
    def __str__(ref self) -> String:
        ...

trait ParseFromString:
    def parse(mut self, input: String) raises:
        ...

comptime YangScalarTraits = CreateFromString & Copyable & Movable & ImplicitlyDestructible & Defaultable

def parse_yang_string(input: String) raises -> String:
    return input

def parse_yang_int(input: String) raises -> Int:
    # TODO replace with actual int parser
    return atol(input)

def parse_yang_bool(input: String) raises -> Bool:
    return input == "true"

@fieldwise_init
struct YangScalar[
    ValueType: Writable & Copyable & Movable & ImplicitlyDestructible,
    parse_method: def(String) raises thin -> ValueType,
](YangScalarTraits):
    var value: Optional[Self.ValueType]

    def __init__(out self):
        self.value = Optional[Self.ValueType]()

    @staticmethod
    def from_string(input: String) raises -> Self:
        return Self(value=Optional[Self.ValueType](Self.parse_method(input)))

    def __str__(ref self) -> String:
        var output = String()
        if self.value:
            output.write(self.value.value())
        return output

comptime YangString = YangScalar[String, parse_yang_string]
comptime YangInt = YangScalar[Int, parse_yang_int]
comptime YangBool = YangScalar[Bool, parse_yang_bool]

trait YANGField:
    def name(self) -> String:
        ...  

comptime FieldTraits = YANGField & Defaultable & CreateFromString & ParseFromString & \
                       Movable & ImplicitlyDestructible

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

    var data: Self.ValueType

    def __init__(out self):
        self.data = Self.ValueType()

    def name(self) -> String:
        return Self.field_name
    
    def __str__(ref self) -> String:
        return Self.field_name + ": " + self.data.__str__()

    @staticmethod
    def from_string(input: String) raises -> Self:
        return Self(data = Self.ValueType.from_string(input))
    
    def parse(mut self, input: String) raises:
        self.data = Self.ValueType.from_string(input)

@fieldwise_init
struct RepeatedField[
    field_name: StringLiteral,
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

    def name(self) -> String:
        return Self.field_name

    @staticmethod
    def from_string(input: String) raises -> Self:
        var newField = Self(data = List[ArcPointer[Self.FieldType]]())
        newField.parse(input)
        return newField^

    def __str__(ref self) -> String:
        var result = String()
        for field in self.data:
            result += field[].__str__() + "\n"
        return result

    def parse(mut self, input: String) raises:
        var newField = Self.FieldType.from_string(input)
        self.data.append(ArcPointer[Self.FieldType](newField^))

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return rebind_var[Self.IteratorType[origin_of(self)]](self.data.__iter__())

@fieldwise_init
struct CompositeFieldDefinition[
    field_name: StringLiteral,
    *FieldDefs: FieldTraits ] (
    FieldTraits
):
    var data: Tuple[*Self.FieldDefs]

    def __init__(out self):
        self.data = Tuple[*Self.FieldDefs]()

    def name(self) -> String:
        return Self.field_name

    def __str__(ref self) -> String:
        var result = String()
        comptime for i in range(len(Self.FieldDefs)):
            ref field = self.data[i]
            result += field.__str__() + "\n"
        return result

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
comptime FIELD_MUST = RepeatedField["must", MustCompositeFields]
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
                field.parse(input)
                return
        raise Error("Unknown field: " + input)

    def __str__(ref self) -> String:
        var result = String()
        comptime for f in range(Self.field_count()):
            result += self.data[f].__str__() + "\n"
        return result

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
    node.parse("must expression description")
    print(node.__str__())
