## Minimal compile-time field metadata for YANG-style statements.
##
##   pixi run mojo examples/structure.mojo

from std.collections import List
from std.iter import Iterable, Iterator
from std.builtin.variadics import TypeList

from std.reflection import (
    struct_field_count, struct_field_names,
    get_type_name, struct_field_types
)

trait Named:
    def name(self) -> String:
        ...

comptime FieldTraits = Named & Copyable & Movable & ImplicitlyDestructible

@fieldwise_init
struct FieldDefinition[
    field_name: String,
    ValueType: Copyable & Movable & ImplicitlyDestructible,
](FieldTraits):
    ## `field_name`: YANG keyword for this substatement.
    ## `ValueType`: type of its argument after parsing (here: plain string → `String`).
    ## `data`: stored argument value for this field instance.
    ## For an iterable `ValueType` (e.g. `List[…]`) and `for` loops, use
    ## `IterableFieldDefinition` or iterate `self.data` directly.

    comptime ArgumentType = Self.ValueType

    var data: Self.ValueType

    def name(self) -> String:
        return Self.field_name


@fieldwise_init
struct IterableFieldDefinition[
    field_name: String,
    ValueType: Copyable & Movable & ImplicitlyDestructible & Iterable,
](FieldTraits, Iterable):

    ## Like `FieldDefinition`, but the payload type is `Iterable` and this struct
    ## is iterable (delegates to `data`).

    comptime ArgumentType = Self.ValueType

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = Self.ValueType.IteratorType[
        iterable_mut=iterable_mut,
        iterable_origin=iterable_origin,
    ]

    var data: Self.ValueType

    def name(self) -> String:
        return Self.field_name

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return rebind_var[Self.IteratorType[origin_of(self)]](self.data.__iter__())


## One comptime binding per field keyword (string appears only here).
comptime FIELD_DESCRIPTION = FieldDefinition["description", String]
comptime FIELD_REFERENCE = FieldDefinition["reference", String]


## Substatements of `must { ... }` (see `must_stmt.mojo` / `YangMust` in `ast.mojo`).
comptime FIELD_MUST_EXPRESSION = FieldDefinition["expression", String]
comptime FIELD_MUST_ERROR_MESSAGE = FieldDefinition["error-message", String]


## `refine` substatements registered on `RefineParser` (see `refine_stmt.mojo`).
## `TypeList` entries must be **types**. Comptime bindings like
## `FIELD_MUST_EXPRESSION` are *values*; their types are
## `type_of(FIELD_MUST_EXPRESSION)` (same for each slot).
# comptime MustCompositeFields_TL = TypeList[
#     Trait=AnyType,
#     FIELD_MUST_EXPRESSION,
#     type_of(FIELD_DESCRIPTION),
#     type_of(FIELD_MUST_ERROR_MESSAGE),
# ]()
comptime MustCompositeFields = Tuple[
    FIELD_MUST_EXPRESSION,
    FIELD_DESCRIPTION,
    FIELD_MUST_ERROR_MESSAGE,
]
comptime FIELD_MUST = IterableFieldDefinition["must", List[MustCompositeFields]]
comptime FIELD_MIN_ELEMENTS = FieldDefinition["min-elements", Int]
comptime FIELD_MAX_ELEMENTS = FieldDefinition["max-elements", Int]
comptime FIELD_ORDERED_BY = FieldDefinition["ordered-by", String]
comptime FIELD_MANDATORY = FieldDefinition["mandatory", Bool]
comptime FIELD_DEFAULT = FieldDefinition["default", String]
comptime FIELD_IF_FEATURE = FieldDefinition["if-feature", String]
comptime FIELD_TYPE = FieldDefinition["type", String]


## Abstract AST node: `fields` is a comptime tuple of `FieldDefinition`,
## `IterableFieldDefinition`, and/or `CompositeFieldDefinition` values.
@fieldwise_init
struct YangASTNode[*FieldDefs: FieldTraits]():

    var data: Tuple[*Self.FieldDefs]

    @staticmethod
    def field_count() -> Int:
        return Self.FieldDefs.size

comptime YangRefineASTNode = YangASTNode[
    (FIELD_MUST),
    (FIELD_DESCRIPTION),
    (FIELD_MIN_ELEMENTS),
    (FIELD_MAX_ELEMENTS),
    (FIELD_ORDERED_BY),
    (FIELD_MANDATORY),
    (FIELD_DEFAULT),
    (FIELD_IF_FEATURE),
    (FIELD_TYPE),
]

def main():
    var tag = FIELD_DESCRIPTION("module summary")
    print(tag.name() + ": " + tag.data)

    print(
        "example node fields: "
        + String(YangRefineASTNode.field_count()),
    )
