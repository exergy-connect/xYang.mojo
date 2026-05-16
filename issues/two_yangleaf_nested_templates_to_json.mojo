## Standalone: JSON serialization with nested schema templates.
##
## Run (after `pixi run package`):
##   pixi run mojo -I build -I . issues/two_yangleaf_nested_templates_to_json.mojo
##
## This is the non-reflection alternative to
## `two_yangleaf_reflection_to_json.mojo`: the YANG shape is declared as a
## variadic nested template, and the runtime value container derives from the
## same template parameters. Serialization follows those explicit type slots.

from std.collections import List
from std.memory import ArcPointer

from xyang.json.value import (
    JsonInt,
    JsonObject,
    JsonPayload,
    JsonString,
    JsonValue,
)

comptime Arc = ArcPointer


trait YangTemplateLeaf:
    comptime Value: Copyable & Defaultable & ImplicitlyDestructible & Movable

    @staticmethod
    def yang_name() -> String:
        ...

    @staticmethod
    def yang_type_str() -> String:
        ...

    @staticmethod
    def json_value(var value: Self.Value) raises -> JsonValue:
        ...


struct YangString[name: StaticString](YangTemplateLeaf):
    comptime Value = String

    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def yang_type_str() -> String:
        return "string"

    @staticmethod
    def json_value(var value: Self.Value) raises -> JsonValue:
        return _json_string_value(rebind[String](value))


struct YangUInt16[name: StaticString](YangTemplateLeaf):
    comptime Value = Int

    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def yang_type_str() -> String:
        return "uint16"

    @staticmethod
    def json_value(value: Self.Value) raises -> JsonValue:
        return _json_int_value(Int64(rebind[Int](value)))


comptime LeafValue[
    Leaf: YangTemplateLeaf,
]: Copyable & Defaultable & ImplicitlyDestructible & Movable = Leaf.Value


trait YangTemplateObject:
    @staticmethod
    def yang_name() -> String:
        ...

    @staticmethod
    def field_count() -> Int:
        ...

    @staticmethod
    def field_name[i: Int]() -> String:
        ...


struct YangObject[
    name: StaticString,
    *Fields: YangTemplateLeaf,
](YangTemplateObject):
    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def field_count() -> Int:
        return len(Self.Fields)

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.Fields[i].yang_name()


def _json_string_value(var value: String) -> JsonValue:
    return JsonValue(
        JsonValue.STRING,
        JsonPayload(JsonString(value=value^)),
        0,
    )


def _json_int_value(value: Int64) -> JsonValue:
    return JsonValue(
        JsonValue.INT,
        JsonPayload(JsonInt(value=value, text=String(value))),
        0,
    )


struct YangRow[
    name: StaticString,
    *Fields: YangTemplateLeaf,
](
    ImplicitlyDestructible,
    Movable,
):
    comptime Schema = YangObject[Self.name, *Self.Fields]
    comptime ValueTypes = TypeList.of[
        Trait=YangTemplateLeaf, *Self.Fields
    ]().map[
        ToTrait=Copyable & Defaultable & ImplicitlyDestructible & Movable,
        LeafValue,
    ]()

    var values: Tuple[*Self.ValueTypes]

    def __init__(out self):
        comptime assert Self.Schema.field_count() == len(Self.Fields)
        comptime for i in range(len(Self.Fields)):
            comptime assert (
                Self.Schema.field_name[i]() == Self.Fields[i].yang_name()
            )
        self.values = Tuple[*Self.ValueTypes]()

    def set[i: Int](mut self, var value: Self.ValueTypes[i]):
        comptime assert i >= 0 and i < len(Self.Fields)
        self.values[i] = value^

    def to_json(read self) raises -> JsonValue:
        comptime assert Self.Schema.field_count() == len(Self.Fields)
        var keys = List[String]()
        var vals = List[Arc[JsonValue]]()
        comptime for i in range(len(Self.Fields)):
            comptime assert (
                Self.Schema.field_name[i]() == Self.Fields[i].yang_name()
            )
            keys.append(Self.Schema.field_name[i]())
            var value = rebind_var[Self.Fields[i].Value](
                self.values[i].copy()
            )
            vals.append(
                Arc[JsonValue](Self.Fields[i].json_value(value^))
            )

        return JsonValue(
            JsonValue.OBJECT,
            JsonPayload(JsonObject(keys=keys^, values=vals^)),
            0,
        )


comptime CatalogLineRow = YangRow[
    "catalog_line",
    YangString["title"],
    YangUInt16["units"],
]


def main() raises:
    var row = CatalogLineRow()
    row.set[0](String("mug"))
    row.set[1](3)
    print(row.to_json().to_string())
