## Reflection helpers for binding annotated Mojo structs to YANG modules.

from std.collections import Dict, List
from std.memory import ArcPointer
from std.reflection import reflect

from xyang.json.parser import JsonValue, parse_json
from xyang.validator.document import validate_data
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.spec import `leaf`

from .types import (
    NoNumericRange,
    NoStringConstraints,
    NoYangWhen,
    YangBuiltinBool,
    YangBuiltinInt8,
    YangBuiltinInt16,
    YangBuiltinInt32,
    YangBuiltinInt64,
    YangBuiltinString,
    YangBuiltinUInt8,
    YangBuiltinUInt16,
    YangBuiltinUInt32,
    YangBuiltinUInt64,
    YangModeled,
)


comptime Arc = ArcPointer


def _stmt(keyword: String, argument: String = "") -> YangConstruct:
    var node = YangConstruct(keyword, 0)
    if argument.byte_length() > 0:
        node.set_raw_argument(argument)
    return node^


def _append_stmt(mut parent: YangConstruct, var child: YangConstruct):
    parent.children.append(Arc[YangConstruct](child^))


def _append_arg(mut parent: YangConstruct, keyword: String, argument: String):
    if argument.byte_length() == 0:
        return
    var child = _stmt(keyword, argument)
    _append_stmt(parent, child^)


def _byte_slice_str(read s: String, start: Int, end: Int) -> String:
    var b = s.as_bytes()
    return String(StringSlice(unsafe_from_utf8=b[start:end]))


def _model_type_keyword_from_reflection[FT: AnyType]() raises -> String:
    comptime reflected_ty = reflect[FT].name()
    if "YangBuiltinString" in reflected_ty:
        return "string"
    if "YangBuiltinBool" in reflected_ty:
        return "boolean"
    if "YangBuiltinInt8" in reflected_ty:
        return "int8"
    if "YangBuiltinInt16" in reflected_ty:
        return "int16"
    if "YangBuiltinInt32" in reflected_ty:
        return "int32"
    if "YangBuiltinInt64" in reflected_ty:
        return "int64"
    if "YangBuiltinUInt8" in reflected_ty:
        return "uint8"
    if "YangBuiltinUInt16" in reflected_ty:
        return "uint16"
    if "YangBuiltinUInt32" in reflected_ty:
        return "uint32"
    if "YangBuiltinUInt64" in reflected_ty:
        return "uint64"
    raise Error(
        "reflection: field is not a recognized YangLeaf builtin: "
        + reflected_ty
    )


def _model_max_string_length_from_reflection[FT: AnyType]() raises -> Int:
    comptime reflected_ty = reflect[FT].name()
    if "NoStringConstraints" in reflected_ty:
        return -1
    var marker = "MaxStringLength["
    var start = reflected_ty.find(marker)
    if start < 0:
        return -1
    start += marker.byte_length()
    var end = start
    var b = reflected_ty.as_bytes()
    comptime close = UInt8(ord("]"))
    while end < len(b) and b[end] != close:
        end += 1
    if end <= start:
        return -1
    return atol(_byte_slice_str(reflected_ty, start, end))


def _skip_to_signed_digit(read s: String, start: Int) -> Int:
    var b = s.as_bytes()
    var i = start
    while i < len(b):
        var c = b[i]
        if (c >= UInt8(ord("0")) and c <= UInt8(ord("9"))) or c == UInt8(
            ord("-")
        ):
            return i
        i += 1
    return -1


def _scan_signed_int_end(read s: String, start: Int) -> Int:
    var b = s.as_bytes()
    var i = start
    if i < len(b) and b[i] == UInt8(ord("-")):
        i += 1
    while i < len(b) and b[i] >= UInt8(ord("0")) and b[i] <= UInt8(ord("9")):
        i += 1
    return i


def _model_range_text_from_reflection[FT: AnyType]() raises -> String:
    comptime reflected_ty = reflect[FT].name()
    if "NoNumericRange" in reflected_ty:
        return String()
    var marker = "YangRange["
    var start = reflected_ty.find(marker)
    if start < 0:
        return String()
    var lo_start = _skip_to_signed_digit(reflected_ty, start + marker.byte_length())
    if lo_start < 0:
        return String()
    var lo_end = _scan_signed_int_end(reflected_ty, lo_start)
    var hi_start = _skip_to_signed_digit(reflected_ty, lo_end)
    if hi_start < 0:
        return String()
    var hi_end = _scan_signed_int_end(reflected_ty, hi_start)
    if hi_end <= hi_start:
        return String()
    return (
        _byte_slice_str(reflected_ty, lo_start, lo_end)
        + ".."
        + _byte_slice_str(reflected_ty, hi_start, hi_end)
    )


def _schema_string_max_length(
    read module: YangModule, read parent: String, read leaf: String
) raises -> Int:
    var c = module.top_container(parent)
    if not c:
        raise Error("reflection: no top container `" + parent + "`")
    var lf = module.find_effective_leaf(c.value()[], leaf)
    if not lf:
        raise Error(
            "reflection: no leaf `"
            + leaf
            + "` under container `"
            + parent
            + "`"
        )
    var segs = module.leaf_length_segments(lf.value()[])
    if len(segs) == 0:
        return -1
    var hi: Int64 = -1
    for i in range(len(segs)):
        if segs[i].hi > hi:
            hi = segs[i].hi
    comptime _BIG: Int64 = 9223372036854775807
    if hi >= _BIG:
        return -1
    return Int(hi)


def effective_leaf_names_under(
    read module: YangModule, read parent: YangConstruct
) raises -> List[String]:
    var out = List[String]()
    var seen = Dict[String, Bool]()
    for child in parent.children:
        if child[].spec == `leaf` and child[].has_argument():
            var name = child[].argument_text()
            if name not in seen:
                seen[name] = True
                out.append(name)
    for child in parent.children:
        if child[].keyword != "uses" or not child[].has_argument():
            continue
        var grouping = module.find_grouping(child[].argument_text())
        if not grouping:
            continue
        var inner = effective_leaf_names_under(module, grouping.value()[])
        for i in range(len(inner)):
            var n = inner[i]
            if n not in seen:
                seen[n] = True
                out.append(n)
    return out^


def validate_yang_subtree[T: YangModeled](read module: YangModule) raises:
    comptime info = reflect[T]
    comptime _nfc = info.field_count()
    var want = T.yang_container_name()
    var c = module.top_container(want)
    if not c:
        raise Error(
            "reflection: Yang subtree missing top container `" + want + "`"
        )
    var schema_leaves = effective_leaf_names_under(module, c.value()[])
    if len(schema_leaves) != _nfc:
        raise Error(
            "reflection: container `"
            + want
            + "` has "
            + String(len(schema_leaves))
            + " effective leaf(es) vs "
            + String(_nfc)
            + " model field(s)"
        )
    for i in range(len(schema_leaves)):
        var ln = schema_leaves[i]
        var in_model = False
        for j in range(_nfc):
            if info.field_names()[j] == ln:
                in_model = True
                break
        if not in_model:
            raise Error(
                "reflection: schema leaf `"
                + want
                + "/"
                + ln
                + "` has no matching Mojo field"
            )
    comptime for j in range(_nfc):
        var fname = String(info.field_names()[j])
        var in_schema = False
        for i in range(len(schema_leaves)):
            if schema_leaves[i] == fname:
                in_schema = True
                break
        if not in_schema:
            raise Error(
                "reflection: Mojo field `"
                + fname
                + "` missing under YANG `"
                + want
                + "`"
            )
        validate_leaf_model_vs_module[info.field_types()[j]](
            module, want, fname
        )


def validate_leaf_model_vs_module[
    FT: AnyType
](read module: YangModule, read parent: String, read leaf: String) raises:
    var yt = _model_type_keyword_from_reflection[FT]()
    var c = module.top_container(parent)
    if not c:
        raise Error("reflection: missing container `" + parent + "`")
    var lf = module.find_effective_leaf(c.value()[], leaf)
    if not lf:
        raise Error("reflection: missing leaf `" + parent + "/" + leaf + "`")
    var schema_ty = module.leaf_type(lf.value()[])
    if schema_ty != yt:
        raise Error(
            "reflection: leaf `"
            + parent
            + "/"
            + leaf
            + "` model type `"
            + yt
            + "` != schema `"
            + schema_ty
            + "`"
        )
    if yt == "string":
        var schema_max = _schema_string_max_length(module, parent, leaf)
        var model_max = _model_max_string_length_from_reflection[FT]()
        if schema_max != model_max:
            raise Error(
                "reflection: leaf `"
                + parent
                + "/"
                + leaf
                + "` model string max "
                + String(model_max)
                + " != schema length upper bound "
                + String(schema_max)
            )
    else:
        comptime reflected_ty = reflect[FT].name()
        if "NoStringConstraints" not in reflected_ty:
            raise Error(
                "reflection: non-string leaf `"
                + parent
                + "/"
                + leaf
                + "` must use NoStringConstraints"
            )
        var model_range = _model_range_text_from_reflection[FT]()
        if model_range.byte_length() > 0:
            var schema_range = module.leaf_range(lf.value()[])
            if schema_range != model_range:
                raise Error(
                    "reflection: leaf `"
                    + parent
                    + "/"
                    + leaf
                    + "` model range `"
                    + model_range
                    + "` != schema `"
                    + schema_range
                    + "`"
                )


def _leaf_from_model[FT: AnyType](read name: String) raises -> YangConstruct:
    var leaf_node = _stmt("leaf", name)
    var yt = _model_type_keyword_from_reflection[FT]()
    var type_node = _stmt("type", yt)
    if yt == "string":
        var max_len = _model_max_string_length_from_reflection[FT]()
        if max_len >= 0:
            _append_arg(type_node, "length", "0.." + String(max_len))
    else:
        var range_text = _model_range_text_from_reflection[FT]()
        if range_text.byte_length() > 0:
            _append_arg(type_node, "range", range_text)
    _append_stmt(leaf_node, type_node^)
    return leaf_node^


def container_construct_from_model[T: YangModeled]() raises -> YangConstruct:
    comptime info = reflect[T]
    comptime _nfc = info.field_count()
    var container = _stmt("container", T.yang_container_name())
    comptime for i in range(_nfc):
        var field = _leaf_from_model[info.field_types()[i]](
            String(info.field_names()[i])
        )
        _append_stmt(container, field^)
    return container^


def yang_module_from_model[T: YangModeled](
    module_name: String,
    namespace: String,
    prefix: String,
    yang_version: String = "1.1",
) raises -> YangModule:
    var root = _stmt("module", module_name)
    _append_arg(root, "yang-version", yang_version)
    _append_arg(root, "namespace", namespace)
    _append_arg(root, "prefix", prefix)
    var container = container_construct_from_model[T]()
    _append_stmt(root, container^)
    var module = YangModule()
    module.ingest_construct_tree(root^)
    return module^


def validate_data_against_model[T: YangModeled](
    read data: JsonValue,
    module_name: String,
    namespace: String,
    prefix: String,
    json_path: String = "",
) raises:
    var module = yang_module_from_model[T](module_name, namespace, prefix)
    validate_yang_subtree[T](module)
    validate_data(data, module, json_path)


def parse_and_validate_json_against_model[T: YangModeled](
    source: String,
    module_name: String,
    namespace: String,
    prefix: String,
    json_path: String = "",
) raises -> JsonValue:
    var data = parse_json(source, json_path)
    validate_data_against_model[T](
        data, module_name, namespace, prefix, json_path
    )
    return data^
