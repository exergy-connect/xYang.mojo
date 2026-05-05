## Validate JSON values against `YangConstruct` schema nodes.

from xyang.json.parser import JsonValue, json_get
import xyang.validator.schema_walk as schema_walk
from xyang.validator.pattern_match import (
    unicode_scalar_count,
    yang_string_matches_xsd_subset,
)
from xyang.yang.arguments import length_allows_scalar_count
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.spec import (
    `container`,
    `key`,
    `leaf`,
    `leaf-list`,
    `list`,
    `must`,
)


@always_inline
def _json_err_prefix(json_path: String, source_line: Int) -> String:
    var p = String()
    if json_path.byte_length() > 0:
        p += json_path + " "
    if source_line > 0:
        p += "line " + String(source_line) + ": "
    return p^


@always_inline
def _raise_json_path_error(
    json_path: String, source_line: Int, path: String, message: String
) raises -> None:
    raise Error(_json_err_prefix(json_path, source_line) + path + message)


def validate_leaf_value(
    read value: JsonValue,
    read leaf: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
) raises:
    var ty = module.leaf_type(leaf)
    if ty == "string":
        if value.kind != JsonValue.STRING:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected string"
            )
        var segs = module.leaf_length_segments(leaf)
        if len(segs) > 0:
            var ulen = unicode_scalar_count(value.text)
            if not length_allows_scalar_count(segs, ulen):
                _raise_json_path_error(
                    json_path,
                    value.source_line,
                    path,
                    ": string length outside `length` restriction",
                )
        var pats = module.leaf_pattern_specs(leaf)
        for i in range(len(pats)):
            var ok = yang_string_matches_xsd_subset(pats[i].regex, value.text)
            if pats[i].invert:
                ok = not ok
            if not ok:
                _raise_json_path_error(
                    json_path,
                    value.source_line,
                    path,
                    ": string does not match `pattern` restriction",
                )
        if value.text.byte_length() == 0 and module.find_child(leaf, `must`):
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                ": must expression rejected empty string",
            )
        return
    if ty == "boolean":
        if value.kind != JsonValue.BOOL:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected boolean"
            )
        return
    if ty == "uint16":
        if value.kind != JsonValue.INT:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected uint16"
            )
        if value.int_value < 0 or value.int_value > 65535:
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                ": uint16 value out of range",
            )
        var segs = module.leaf_range_segments(leaf)
        if len(segs) > 0:
            var fv = Float64(value.int_value)
            var ok = False
            for i in range(len(segs)):
                var b = segs[i]
                if fv >= b.lo and fv <= b.hi:
                    ok = True
                    break
            if not ok:
                _raise_json_path_error(
                    json_path,
                    value.source_line,
                    path,
                    ": value outside `range` restriction",
                )
        return
    if ty == "leafref":
        if (
            value.kind != JsonValue.STRING
            and value.kind != JsonValue.INT
            and value.kind != JsonValue.BOOL
        ):
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                ": expected scalar leafref",
            )
        return
    _raise_json_path_error(
        json_path,
        value.source_line,
        path,
        ": unsupported leaf type `" + ty + "`",
    )


def validate_leaf_list_value(
    read value: JsonValue,
    read leaf_list: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
) raises:
    if value.kind != JsonValue.ARRAY:
        _raise_json_path_error(
            json_path,
            value.source_line,
            path,
            ": expected JSON array for leaf-list",
        )
    ## Reuse `leaf` typing: `leaf-list` carries the same `type` subtree as a leaf.
    var proxy = YangConstruct("leaf", leaf_list.line)
    proxy.spec = `leaf`
    for ch in leaf_list.children:
        proxy.children.append(ch.copy())
    for i in range(len(value.array_values)):
        validate_leaf_value(
            value.array_values[i][],
            proxy,
            module,
            path + "[" + String(i) + "]",
            json_path,
        )


@no_inline
def validate_object_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
) raises:
    validate_object_against_construct(
        data, schema, module, path, json_path, path
    )


@no_inline
def validate_object_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    schema_path: String,
) raises:
    if data.kind != JsonValue.OBJECT:
        _raise_json_path_error(
            json_path, data.source_line, path, ": expected JSON object"
        )

    schema_walk.validate_mandatory_choices_under_container(
        module,
        schema,
        data,
        path,
        json_path,
    )

    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var data_child = schema_walk.find_schema_child_for_json_key(
            module,
            schema,
            key,
            data,
        )
        if not data_child:
            _raise_json_path_error(
                json_path,
                slot.source_line,
                path,
                ": unknown field `" + key + "`",
            )
        ref child = data_child.value()[]
        var child_kind = child.spec
        var child_path = path + "/" + key

        if child_kind == `leaf`:
            validate_leaf_value(slot, child, module, child_path, json_path)
            continue

        if child_kind == `leaf-list`:
            validate_leaf_list_value(slot, child, module, child_path, json_path)
            continue

        if child_kind == `container`:
            validate_object_against_construct(
                slot,
                child,
                module,
                child_path,
                json_path,
                schema_path + "/" + key,
            )
            continue

        if child_kind == `list`:
            validate_list_against_construct(
                slot,
                child,
                module,
                child_path,
                json_path,
                schema_path + "/" + key,
            )
            continue

        _raise_json_path_error(
            json_path,
            slot.source_line,
            path,
            ": unknown field `" + key + "`",
        )


@no_inline
def validate_list_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    schema_path: String,
) raises:
    if data.kind != JsonValue.ARRAY:
        _raise_json_path_error(
            json_path, data.source_line, path, ": expected JSON array for list"
        )
    var key_stmt = module.find_child(schema, `key`)
    for i in range(len(data.array_values)):
        ref entry = data.array_values[i][]
        var entry_path = path + "[" + String(i) + "]"
        validate_object_against_construct(
            entry, schema, module, entry_path, json_path, schema_path
        )
        if key_stmt and key_stmt.value()[].has_argument():
            var key = key_stmt.value()[].argument_text()
            if not json_get(entry, key):
                _raise_json_path_error(
                    json_path,
                    entry.source_line,
                    entry_path,
                    ": missing list key `" + key + "`",
                )
