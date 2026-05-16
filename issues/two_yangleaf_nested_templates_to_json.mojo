## Standalone: JSON serialization with nested schema templates.
##
## Run (after `pixi run package`):
##   pixi run mojo -I build -I . issues/two_yangleaf_nested_templates_to_json.mojo
##
## Heterogeneous `*Leaves`: `YangString`, `YangUInt16`, and nested rows via
## `YangRowLeaf[DetailsRow]` (row value type stays `DetailsRow`).

from std.builtin.variadics import TypeList
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


trait YangRowNestable(Defaultable, ImplicitlyDestructible, Movable):
    @staticmethod
    def yang_name() -> String:
        ...

    def to_json(read self) raises -> JsonValue:
        ...


struct _NoNested(YangRowNestable):
    def __init__(out self):
        pass

    @staticmethod
    def yang_name() -> String:
        return ""

    def to_json(read self) raises -> JsonValue:
        _ = self
        return JsonValue(
            JsonValue.OBJECT,
            JsonPayload(JsonObject(keys=List[String](), values=List[Arc[JsonValue]]())),
            0,
        )


trait YangNode:
    comptime Type = UInt8
    comptime STRING: Self.Type = 0
    comptime UINT16: Self.Type = 1
    comptime NESTED_ROW: Self.Type = 2

    comptime NodeType: Self.Type
    comptime RuntimeValue: Defaultable & ImplicitlyDestructible & Movable
    comptime NestedBody: YangRowNestable = _NoNested

    @staticmethod
    def yang_name() -> String:
        ...

    @staticmethod
    def yang_type() -> Self.Type:
        ...

    @staticmethod
    def is_nested_row() -> Bool:
        ...


struct YangString[name: StaticString](YangNode):
    comptime NodeType = Self.STRING
    comptime RuntimeValue = String
    comptime NestedBody = _NoNested

    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def yang_type() -> Self.Type:
        return Self.NodeType

    @staticmethod
    def is_nested_row() -> Bool:
        return Self.NodeType == Self.NESTED_ROW


struct YangUInt16[name: StaticString](YangNode):
    comptime NodeType = Self.UINT16
    comptime RuntimeValue = Int
    comptime NestedBody = _NoNested

    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def yang_type() -> Self.Type:
        return Self.NodeType

    @staticmethod
    def is_nested_row() -> Bool:
        return Self.NodeType == Self.NESTED_ROW


struct YangRowLeaf[
    Body: YangRowNestable,
](YangNode):
    """Field descriptor for a nested `YangRow`; tuple slot type is `Body`."""

    comptime NodeType = Self.NESTED_ROW
    comptime RuntimeValue = Self.Body
    comptime NestedBody = Self.Body

    @staticmethod
    def yang_name() -> String:
        return Self.Body.yang_name()

    @staticmethod
    def yang_type() -> Self.Type:
        return Self.NodeType

    @staticmethod
    def is_nested_row() -> Bool:
        return Self.NodeType == Self.NESTED_ROW


comptime LeafRuntime[
    Leaf: YangNode,
]: Defaultable & ImplicitlyDestructible & Movable = Leaf.RuntimeValue


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
    *Leaves: YangNode,
](YangTemplateObject):
    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def field_count() -> Int:
        return len(Self.Leaves)

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.Leaves[i].yang_name()


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
    *Leaves: YangNode,
](
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    YangRowNestable,
):
    comptime Schema = YangObject[Self.name, *Self.Leaves]
    comptime SlotTypes = TypeList.of[
        Trait=YangNode, *Self.Leaves
    ]().map[
        ToTrait=Defaultable & ImplicitlyDestructible & Movable,
        LeafRuntime,
    ]()

    var slots: Tuple[*Self.SlotTypes]

    def __init__(out self):
        self.slots = Tuple[*Self.SlotTypes]()

    def __init__(out self, *, var slot_values: Tuple[*Self.SlotTypes]):
        self.slots = slot_values^

    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    def set[i: Int](mut self, var value: Self.SlotTypes[i]):
        comptime assert i >= 0 and i < len(Self.Leaves)
        self.slots[i] = value^

    @staticmethod
    def field_index[field_name: StaticString]() -> Int:
        comptime for i in range(len(Self.Leaves)):
            comptime if String(field_name) == Self.Schema.field_name[i]():
                return i
        return -1

    def set_by_name[
        field_name: StaticString,
        Value: Defaultable & ImplicitlyDestructible & Movable,
    ](
        mut self, var value: Value
    ) raises:
        comptime i = Self.field_index[field_name]()
        comptime assert i >= 0, "unknown schema field"
        comptime assert not Self.Leaves[i].is_nested_row(), (
            "field is a nested row; assign the whole row value for now"
        )
        self.set[i](rebind_var[Self.SlotTypes[i]](value^))

    def _field_json[i: Int](read self) raises -> JsonValue:
        comptime field = Self.Leaves[i]
        comptime if field.yang_type() == field.NESTED_ROW:
            return rebind[field.NestedBody](self.slots[i]).to_json()
        comptime if field.yang_type() == field.STRING:
            return _json_string_value(String(rebind[String](self.slots[i])))
        comptime if field.yang_type() == field.UINT16:
            return _json_int_value(Int64(rebind[Int](self.slots[i])))
        raise Error("unsupported YangNode.Type")

    def to_json(read self) raises -> JsonValue:
        comptime assert Self.Schema.field_count() == len(Self.Leaves)
        var keys = List[String]()
        var vals = List[Arc[JsonValue]]()
        comptime for i in range(len(Self.Leaves)):
            comptime assert (
                Self.Schema.field_name[i]() == Self.Leaves[i].yang_name()
            )
            keys.append(Self.Schema.field_name[i]())
            vals.append(Arc[JsonValue](self._field_json[i]()))
        return JsonValue(
            JsonValue.OBJECT,
            JsonPayload(JsonObject(keys=keys^, values=vals^)),
            0,
        )


comptime DetailsRow = YangRow[
    "details",
    YangString["comment"],
    YangUInt16["amount"],
]

comptime DetailsField = YangRowLeaf[DetailsRow]

comptime CatalogLineRow = YangRow[
    "catalog_line",
    YangString["title"],
    YangUInt16["units"],
    DetailsField,
]


def main() raises:
    var details = DetailsRow(slot_values=(String("new mug"), 42))
    var row = CatalogLineRow(
        slot_values=(
            String("mug"),
            3,
            details^,
        )
    )
    print(row.to_json().to_string())
