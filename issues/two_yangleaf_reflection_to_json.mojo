## Standalone: `YangModeled` struct with two `YangLeaf` fields → JSON via reflection.
##
## Run (after `pixi run package`):
##   M="$PWD/.pixi/envs/default/lib/mojo"
##   pixi run mojo -I build -I "$M" -I . issues/two_yangleaf_reflection_to_json.mojo
##
## :func:`to_json` is a generic free function over any :trait:`YangModeled`
## struct whose reflected fields are direct ``YangLeaf`` descriptors. Mojo does
## not support an erased parameter type ``read obj: YangModeled``; traits are
## bounds on static type parameters, so the polymorphism is compile-time.

from std.collections import List
from std.memory import ArcPointer
from std.reflection import reflect

from xyang.api.model import validate_yang_subtree, yang_module_from_model
from xyang.api.types import (
    YangBuiltinString,
    YangBuiltinUInt16,
    YangConstraints,
    YangLeaf,
    YangLeafValueReadable,
    YangModeled,
)
from xyang.json.value import (
    JsonBool,
    JsonInt,
    JsonObject,
    JsonPayload,
    JsonString,
    JsonValue,
)
from xyang.yang.ast.module import YangModule

comptime Arc = ArcPointer


@fieldwise_init
struct CatalogLine(ImplicitlyDestructible, Movable, YangModeled):
    var title: YangLeaf[YangBuiltinString, YangConstraints[]]
    var units: YangLeaf[YangBuiltinUInt16, YangConstraints[]]

    def __init__(out self):
        self.title = YangLeaf[YangBuiltinString, YangConstraints[]]()
        self.units = YangLeaf[YangBuiltinUInt16, YangConstraints[]]()
        self.title.value = String()
        self.units.value = 0

    @staticmethod
    def yang_container_name() -> String:
        return "catalog_line"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)


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


def _json_bool_value(value: Bool) -> JsonValue:
    return JsonValue(
        JsonValue.BOOL,
        JsonPayload(JsonBool(value=value)),
        0,
    )


def to_json[T: AnyType](read obj: T) raises -> JsonValue:
    """Serialize a direct-leaf ``YangModeled`` struct using reflection."""

    comptime assert conforms_to(T, YangModeled), "to_json expects YangModeled"
    comptime ri = reflect[T]
    comptime n = ri.field_count()
    var keys = List[String]()
    var vals = List[Arc[JsonValue]]()
    comptime for i in range(n):
        comptime FieldType = ri.field_types()[i]
        comptime field_type_name = reflect[FieldType].name()
        comptime if "YangLeaf" in field_type_name:
            keys.append(String(ri.field_names()[i]))
            ref leaf = trait_downcast[YangLeafValueReadable](
                ri.field_ref[i](obj)
            )
            comptime if (
                "YangBuiltinString" in field_type_name
                or "YangEnum" in field_type_name
            ):
                vals.append(
                    Arc[JsonValue](
                        _json_string_value(leaf.yang_leaf_string_value())
                    )
                )
            elif "YangBuiltinBool" in field_type_name:
                vals.append(
                    Arc[JsonValue](
                        _json_bool_value(leaf.yang_leaf_bool_value())
                    )
                )
            elif (
                "YangBuiltinInt8" in field_type_name
                or "YangBuiltinInt16" in field_type_name
                or "YangBuiltinInt32" in field_type_name
                or "YangBuiltinUInt8" in field_type_name
                or "YangBuiltinUInt16" in field_type_name
            ):
                vals.append(
                    Arc[JsonValue](
                        _json_int_value(leaf.yang_leaf_int64_value())
                    )
                )
            elif (
                "YangBuiltinInt64" in field_type_name
                or "YangBuiltinUInt32" in field_type_name
                or "YangBuiltinUInt64" in field_type_name
            ):
                vals.append(
                    Arc[JsonValue](
                        _json_int_value(leaf.yang_leaf_int64_value())
                    )
                )
            else:
                raise Error("to_json: unsupported YangLeaf type")
        else:
            raise Error(
                "to_json: field `"
                + String(ri.field_names()[i])
                + "` is not a direct YangLeaf"
            )
    return JsonValue(
        JsonValue.OBJECT,
        JsonPayload(JsonObject(keys=keys^, values=vals^)),
        0,
    )


def to_json_for_modeled[T: YangModeled](mut obj: T) raises -> JsonValue:
    """Compatibility wrapper for older call sites."""

    return to_json[T](obj)


def main() raises:
    var m = yang_module_from_model[CatalogLine](
        "two-leaf-demo",
        "urn:example:two-leaf-demo",
        "tld",
    )
    CatalogLine.comptime_validate(m)
    var row = CatalogLine()
    row.title.value = "mug"
    row.units.value = 3
    print(to_json[CatalogLine](row).to_string())
