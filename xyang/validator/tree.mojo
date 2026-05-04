## Validate JSON values against `YangConstruct` schema nodes.

from std.collections import Dict
from std.memory import ArcPointer

from xyang.json.parser import JsonValue, json_get
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
    `list`,
    `must`,
)


comptime Arc = ArcPointer
comptime DataChildMap = Dict[String, Arc[YangConstruct]]


struct ValidationCache:
    var data_children: Dict[String, DataChildMap]

    def __init__(out self):
        self.data_children = Dict[String, DataChildMap]()

    def data_child(
        mut self,
        read module: YangModule,
        read schema: YangConstruct,
        schema_path: String,
        key: String,
    ) raises -> Optional[Arc[YangConstruct]]:
        if schema_path not in self.data_children:
            var children = module.effective_data_children(schema)
            self.data_children[schema_path] = children^
        if key not in self.data_children[schema_path]:
            return Optional[Arc[YangConstruct]]()
        return Optional[Arc[YangConstruct]](
            self.data_children[schema_path][key].copy()
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


@no_inline
def validate_object_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
) raises:
    var cache = ValidationCache()
    validate_object_against_construct(
        data, schema, module, path, json_path, path, cache
    )


@no_inline
def validate_object_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    schema_path: String,
    mut cache: ValidationCache,
) raises:
    if data.kind != JsonValue.OBJECT:
        _raise_json_path_error(
            json_path, data.source_line, path, ": expected JSON object"
        )

    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var data_child = cache.data_child(module, schema, schema_path, key)
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

        if child_kind == `container`:
            validate_object_against_construct(
                slot,
                child,
                module,
                child_path,
                json_path,
                schema_path + "/" + key,
                cache,
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
                cache,
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
    mut cache: ValidationCache,
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
            entry, schema, module, entry_path, json_path, schema_path, cache
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
