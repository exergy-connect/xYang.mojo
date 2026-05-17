## Standalone: JSON serialization with nested schema templates.
##
## Run (after `pixi run package`):
##   pixi run mojo -I build -I . issues/two_yangleaf_nested_templates_to_json.mojo
##
## Heterogeneous `*ChildNodes`: `YangString`, `YangUInt16` / `YangInteger`, and nested
## containers via `YangLeaf[DetailsRow]` (container value type stays `DetailsRow`).

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


trait YangGrouping(Defaultable, ImplicitlyDestructible, Movable):
    @staticmethod
    def yang_name() -> String:
        ...

    def to_json(read self) raises -> JsonValue:
        ...


struct _NoGrouping(YangGrouping):
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
    comptime Kind = UInt8
    comptime STRING: Self.Kind = 0
    comptime UINT8: Self.Kind = 1
    comptime UINT16: Self.Kind = 2
    comptime UINT32: Self.Kind = 3
    comptime INT32: Self.Kind = 4
    comptime UINT64: Self.Kind = 5
    comptime INT64: Self.Kind = 6
    comptime NESTED_ROW: Self.Kind = 7
    comptime UNDEFINED: Self.Kind = 8

    comptime NodeType: Self.Kind
    comptime RuntimeValue: Defaultable & ImplicitlyDestructible & Movable
    comptime NestedBody: YangGrouping = _NoGrouping

    @staticmethod
    def yang_name() -> String:
        ...

    @staticmethod
    def yang_type() -> Self.Kind:
        ...

    @staticmethod
    def is_nested_row() -> Bool:
        return Self.NodeType == Self.NESTED_ROW


struct YangString[name: StaticString](YangNode):
    comptime NodeType = Self.STRING
    comptime RuntimeValue = String

    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def yang_type() -> Self.Kind:
        return Self.NodeType


comptime _yang_node_kinds = YangString["_"]


struct YangInteger[
    name: StaticString,
    yang_type_name: StaticString,
    kind: _yang_node_kinds.Kind,
    Runtime: Movable & Defaultable & ImplicitlyDestructible = Int,
](YangNode):
    comptime NodeType = Self.kind
    comptime RuntimeValue = Self.Runtime

    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def yang_builtin_name() -> String:
        return String(Self.yang_type_name)

    @staticmethod
    def yang_type() -> Self.Kind:
        return Self.NodeType


comptime YangUInt8[name: StaticString] = YangInteger[
    name, "uint8", _yang_node_kinds.UINT8
]
comptime YangUInt16[name: StaticString] = YangInteger[
    name, "uint16", _yang_node_kinds.UINT16
]
comptime YangUInt32[name: StaticString] = YangInteger[
    name, "uint32", _yang_node_kinds.UINT32
]
comptime YangInt32[name: StaticString] = YangInteger[
    name, "int32", _yang_node_kinds.INT32
]
comptime YangUInt64[name: StaticString] = YangInteger[
    name, "uint64", _yang_node_kinds.UINT64, Runtime=UInt64
]
comptime YangInt64[name: StaticString] = YangInteger[
    name, "int64", _yang_node_kinds.INT64, Runtime=Int64
]


struct YangLeaf[
    Body: YangGrouping,
](YangNode):
    """Field descriptor for a nested `YangContainer`; tuple slot type is `Body`."""

    comptime NodeType = Self.NESTED_ROW
    comptime RuntimeValue = Self.Body
    comptime NestedBody = Self.Body

    @staticmethod
    def yang_name() -> String:
        return Self.Body.yang_name()

    @staticmethod
    def yang_type() -> Self.Kind:
        return Self.NodeType


comptime LeafRuntime[
    Leaf: YangNode,
]: Defaultable & ImplicitlyDestructible & Movable = Leaf.RuntimeValue


trait YangContainerSchema:
    @staticmethod
    def yang_name() -> String:
        ...

    @staticmethod
    def field_count() -> Int:
        ...

    @staticmethod
    def field_name[i: Int]() -> String:
        ...


struct YangContainerDef[
    name: StaticString,
    *ChildNodes: YangNode,
](YangContainerSchema):
    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def field_count() -> Int:
        return len(Self.ChildNodes)

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.ChildNodes[i].yang_name()


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


def _json_uint64_value(value: UInt64) -> JsonValue:
    return JsonValue(
        JsonValue.INT,
        JsonPayload(JsonInt(value=Int64(value), text=String(value))),
        0,
    )


struct YangContainer[
    name: StaticString,
    *ChildNodes: YangNode,
](
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    YangGrouping,
):
    comptime Schema = YangContainerDef[Self.name, *Self.ChildNodes]
    comptime SlotTypes = TypeList.of[
        Trait=YangNode, *Self.ChildNodes
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
        comptime assert i >= 0 and i < len(Self.ChildNodes)
        self.slots[i] = value^

    @staticmethod
    def field_index[field_name: StaticString]() -> Int:
        comptime for i in range(len(Self.ChildNodes)):
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
        comptime assert not Self.ChildNodes[i].is_nested_row(), (
            "field is a nested container; assign the whole container value for now"
        )
        self.set[i](rebind_var[Self.SlotTypes[i]](value^))

    def _field_json[i: Int](read self) raises -> JsonValue:
        comptime field = Self.ChildNodes[i]
        comptime assert (
            field.yang_type() < _yang_node_kinds.UNDEFINED
        ), "unsupported YangNode.Kind"
        comptime if field.yang_type() == _yang_node_kinds.NESTED_ROW:
            return rebind[field.NestedBody](self.slots[i]).to_json()
        comptime if field.yang_type() == _yang_node_kinds.STRING:
            return _json_string_value(String(rebind[String](self.slots[i])))
        comptime if (
            field.yang_type() == _yang_node_kinds.UINT8
            or field.yang_type() == _yang_node_kinds.UINT16
            or field.yang_type() == _yang_node_kinds.UINT32
            or field.yang_type() == _yang_node_kinds.INT32
        ):
            return _json_int_value(Int64(rebind[Int](self.slots[i])))
        comptime if field.yang_type() == _yang_node_kinds.UINT64:
            return _json_uint64_value(rebind[UInt64](self.slots[i]))
        comptime if field.yang_type() == _yang_node_kinds.INT64:
            return _json_int_value(rebind[Int64](self.slots[i]))
        return _json_int_value(0)

    def to_json(read self) raises -> JsonValue:
        comptime assert Self.Schema.field_count() == len(Self.ChildNodes)
        var keys = List[String]()
        var vals = List[Arc[JsonValue]]()
        comptime for i in range(len(Self.ChildNodes)):
            comptime assert (
                Self.Schema.field_name[i]() == Self.ChildNodes[i].yang_name()
            )
            keys.append(Self.Schema.field_name[i]())
            vals.append(Arc[JsonValue](self._field_json[i]()))
        return JsonValue(
            JsonValue.OBJECT,
            JsonPayload(JsonObject(keys=keys^, values=vals^)),
            0,
        )


comptime DetailsRow = YangContainer[
    "details",
    YangString["comment"],
    YangUInt16["amount"],
]

comptime DetailsField = YangLeaf[DetailsRow]

comptime CatalogLineRow = YangContainer[
    "catalog_line",
    YangString["title"],
    YangUInt16["units"],
    DetailsField,
]

comptime MaxUint64Row = YangContainer[
    "u64_test",
    YangUInt64["n"],
]

comptime _MAX_UINT64: UInt64 = 18446744073709551615


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

    var max_u64_row = MaxUint64Row(slot_values=(_MAX_UINT64,))
    var max_u64_json = max_u64_row.to_json().to_string()
    print(max_u64_json)
    if max_u64_json.find("-") >= 0:
        raise Error("max uint64 must not serialize negative: " + max_u64_json)
    if max_u64_json.find("18446744073709551615") < 0:
        raise Error("max uint64 missing expected digits: " + max_u64_json)
