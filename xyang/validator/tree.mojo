## Validate JSON values against `YangConstruct` schema nodes.
##
## A single pass over the JSON document validates each leaf (including leafref
## resolution) based on its schema type.

from std.memory import ArcPointer

from xyang.json.value import JsonValue, JsonArray, JsonBool, JsonInt, JsonObject, JsonReal, JsonString, json_get, json_scalar_text
import xyang.validator.schema_walk as schema_walk
from xyang.validator.leafref import LeafrefCache
from xyang.validator.pattern_match import (
    unicode_scalar_count,
    yang_string_matches_xsd_subset,
)
from xyang.yang.arguments import UniqueArgument, length_allows_scalar_count
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.path import YangPath
from xyang.yang.spec import (
    `bit`,
    `container`,
    `enum`,
    `fraction-digits`,
    `key`,
    `leaf`,
    `leaf-list`,
    `list`,
    `max-elements`,
    `min-elements`,
    `must`,
    `unique`,
    `type`,
)


comptime Arc = ArcPointer


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


def _validate_integer_type(
    read value: JsonValue,
    read leaf: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    type_name: String,
    min_val: Int64,
    max_val: Int64,
) raises:
    if value.kind != JsonValue.INT:
        _raise_json_path_error(
            json_path, value.source_line, path, ": expected " + type_name
        )
    if value.payload[JsonInt].value < min_val or value.payload[JsonInt].value > max_val:
        _raise_json_path_error(
            json_path,
            value.source_line,
            path,
            ": " + type_name + " value out of range",
        )
    var segs = module.leaf_range_segments(leaf)
    if len(segs) > 0:
        var fv = Float64(value.payload[JsonInt].value)
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


def validate_leaf_value(
    read value: JsonValue,
    read leaf: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    read root: JsonValue,
    mut cache: LeafrefCache,
) raises:
    var ty = module.leaf_type(leaf)

    # --- string (§9.4) ---
    if ty == "string":
        if value.kind != JsonValue.STRING:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected string"
            )
        var segs = module.leaf_length_segments(leaf)
        if len(segs) > 0:
            var ulen = unicode_scalar_count(value.payload[JsonString].value)
            if not length_allows_scalar_count(segs, ulen):
                _raise_json_path_error(
                    json_path,
                    value.source_line,
                    path,
                    ": string length outside `length` restriction",
                )
        var pats = module.leaf_pattern_specs(leaf)
        for i in range(len(pats)):
            var ok = yang_string_matches_xsd_subset(pats[i].regex, value.payload[JsonString].value)
            if pats[i].invert:
                ok = not ok
            if not ok:
                _raise_json_path_error(
                    json_path,
                    value.source_line,
                    path,
                    ": string does not match `pattern` restriction",
                )
        if value.payload[JsonString].value.byte_length() == 0 and module.find_child(leaf, `must`):
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                ": must expression rejected empty string",
            )
        return

    # --- boolean (§9.5) ---
    if ty == "boolean":
        if value.kind != JsonValue.BOOL:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected boolean"
            )
        return

    # --- enumeration (§9.6) ---
    if ty == "enumeration":
        if value.kind != JsonValue.STRING:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected string"
            )
        var eff = module.leaf_effective_type_stmt(leaf)
        if not eff:
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                ": missing effective type for enumeration",
            )
        var allowed = False
        for ch in eff.value()[].children:
            if ch[].spec == `enum` and ch[].has_argument():
                if ch[].argument_text() == value.payload[JsonString].value:
                    allowed = True
                    break
        if not allowed:
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                ": enumeration value not allowed",
            )
        return

    # --- integer types (§9.2) ---
    if ty == "int8":
        _validate_integer_type(
            value, leaf, module, path, json_path, "int8", -128, 127
        )
        return
    if ty == "int16":
        _validate_integer_type(
            value, leaf, module, path, json_path, "int16", -32768, 32767
        )
        return
    if ty == "int32":
        _validate_integer_type(
            value, leaf, module, path, json_path, "int32",
            -2147483648, 2147483647,
        )
        return
    if ty == "int64":
        _validate_integer_type(
            value, leaf, module, path, json_path, "int64",
            Int64.MIN, Int64.MAX,
        )
        return
    if ty == "uint8":
        _validate_integer_type(
            value, leaf, module, path, json_path, "uint8", 0, 255
        )
        return
    if ty == "uint16":
        _validate_integer_type(
            value, leaf, module, path, json_path, "uint16", 0, 65535
        )
        return
    if ty == "uint32":
        _validate_integer_type(
            value, leaf, module, path, json_path, "uint32", 0, 4294967295
        )
        return
    if ty == "uint64":
        _validate_integer_type(
            value, leaf, module, path, json_path, "uint64", 0, Int64.MAX
        )
        return

    # --- decimal64 (§9.3) ---
    if ty == "decimal64":
        if value.kind != JsonValue.INT and value.kind != JsonValue.REAL:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected decimal64"
            )
        var segs = module.leaf_range_segments(leaf)
        if len(segs) > 0:
            var fv = atof(json_scalar_text(value))
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

    # --- bits (§9.7) ---
    if ty == "bits":
        if value.kind != JsonValue.STRING:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected string for bits"
            )
        var eff = module.leaf_effective_type_stmt(leaf)
        if eff and value.payload[JsonString].value.byte_length() > 0:
            var tokens = value.payload[JsonString].value.split(" ")
            for i in range(len(tokens)):
                var tok = String(tokens[i]).strip()
                if tok.byte_length() == 0:
                    continue
                var found = False
                for ch in eff.value()[].children:
                    if ch[].spec == `bit` and ch[].has_argument():
                        if ch[].argument_text() == tok:
                            found = True
                            break
                if not found:
                    _raise_json_path_error(
                        json_path,
                        value.source_line,
                        path,
                        ": unknown bit `" + tok + "`",
                    )
        return

    # --- binary (§9.8) ---
    if ty == "binary":
        if value.kind != JsonValue.STRING:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected string for binary"
            )
        var segs = module.leaf_length_segments(leaf)
        if len(segs) > 0:
            var decoded_len = _base64_decoded_length(value.payload[JsonString].value)
            if not length_allows_scalar_count(segs, decoded_len):
                _raise_json_path_error(
                    json_path,
                    value.source_line,
                    path,
                    ": binary length outside `length` restriction",
                )
        return

    # --- leafref (§9.9) ---
    if ty == "leafref":
        if (
            value.kind != JsonValue.STRING
            and value.kind != JsonValue.INT
            and value.kind != JsonValue.REAL
            and value.kind != JsonValue.BOOL
        ):
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                ": expected scalar leafref",
            )
        var target_path = module.leafref_path(leaf)
        if target_path.byte_length() > 0:
            var actual = json_scalar_text(value)
            if not cache.contains(root, target_path, path, actual):
                _raise_json_path_error(
                    json_path,
                    value.source_line,
                    path,
                    ": leafref `" + actual + "` does not resolve",
                )
        return

    # --- identityref (§9.10) ---
    if ty == "identityref":
        if value.kind != JsonValue.STRING:
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected string for identityref"
            )
        var bases = module.leaf_identityref_bases(leaf)
        if len(bases) > 0:
            if not module.identity_valid_for_bases(value.payload[JsonString].value, bases):
                _raise_json_path_error(
                    json_path,
                    value.source_line,
                    path,
                    ": identityref value `"
                    + value.payload[JsonString].value
                    + "` does not match any declared identity",
                )
        return

    # --- empty (§9.11) — RFC 7951 §6.9: encoded as [null] ---
    if ty == "empty":
        if value.kind == JsonValue.ARRAY:
            if (
                len(value.payload[JsonArray].values) == 1
                and value.payload[JsonArray].values[0][].kind == JsonValue.NULL
            ):
                return
        _raise_json_path_error(
            json_path, value.source_line, path, ": expected [null] for empty type"
        )

    # --- union (§9.12) — accept any scalar; full member dispatch is future work ---
    if ty == "union":
        if (
            value.kind != JsonValue.STRING
            and value.kind != JsonValue.INT
            and value.kind != JsonValue.REAL
            and value.kind != JsonValue.BOOL
        ):
            _raise_json_path_error(
                json_path, value.source_line, path, ": expected scalar for union"
            )
        return

    # --- instance-identifier (§9.13) ---
    if ty == "instance-identifier":
        if value.kind != JsonValue.STRING:
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                ": expected string for instance-identifier",
            )
        return

    _raise_json_path_error(
        json_path,
        value.source_line,
        path,
        ": unsupported leaf type `" + ty + "`",
    )


def _base64_decoded_length(read encoded: String) -> Int:
    """Approximate decoded byte count from a base64 string (§9.8.2)."""
    var n = encoded.byte_length()
    if n == 0:
        return 0
    var padding = 0
    var b = encoded.as_bytes()
    if n >= 1 and b[n - 1] == 61:  # '='
        padding += 1
    if n >= 2 and b[n - 2] == 61:
        padding += 1
    return (n * 3) // 4 - padding


def _validate_cardinality(
    read value: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    node_kind: String,
) raises:
    var count = len(value.payload[JsonArray].values)
    var min_stmt = module.find_child(schema, `min-elements`)
    if min_stmt and min_stmt.value()[].has_argument():
        var min_count = Int(atol(min_stmt.value()[].argument_text()))
        if count < min_count:
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                (
                    ": "
                    + node_kind
                    + " has fewer entries than `min-elements` "
                    + String(min_count)
                ),
            )
    var max_stmt = module.find_child(schema, `max-elements`)
    if max_stmt and max_stmt.value()[].has_argument():
        if max_stmt.value()[].argument_text() == "unbounded":
            return
        var max_count = Int(atol(max_stmt.value()[].argument_text()))
        if count > max_count:
            _raise_json_path_error(
                json_path,
                value.source_line,
                path,
                (
                    ": "
                    + node_kind
                    + " has more entries than `max-elements` "
                    + String(max_count)
                ),
            )


def _json_unique_scalar(read value: JsonValue) -> Optional[String]:
    if value.kind == JsonValue.STRING:
        return Optional[String]("s:" + value.payload[JsonString].value)
    if value.kind == JsonValue.INT:
        return Optional[String]("i:" + value.payload[JsonInt].text)
    if value.kind == JsonValue.REAL:
        return Optional[String]("r:" + value.payload[JsonReal].text)
    if value.kind == JsonValue.BOOL:
        return Optional[String]("b:" + ("true" if value.payload[JsonBool].value else "false"))
    return Optional[String]()


def _unique_path_value(
    read entry: JsonValue, read path: YangPath
) -> Optional[String]:
    ## RFC 7950 `unique` paths are descendant-schema-nodeids: resolve them from
    ## the list entry and skip entries where any referenced leaf is absent.
    if entry.kind != JsonValue.OBJECT:
        return Optional[String]()
    var current = Optional[Arc[JsonValue]]()
    var first = True
    for i in range(len(path.segments)):
        var name = path.segments[i].node.local_name
        if first:
            current = json_get(entry, name)
            first = False
        else:
            if not current or current.value()[].kind != JsonValue.OBJECT:
                return Optional[String]()
            current = json_get(current.value()[], name)
        if not current:
            return Optional[String]()
    if not current:
        return Optional[String]()
    return _json_unique_scalar(current.value()[])


def _append_unique_component(mut out: String, read value: String):
    out += String(value.byte_length())
    out += ":"
    out += value
    out += ";"


def _validate_unique_constraints(
    read data: JsonValue,
    read schema: YangConstruct,
    path: String,
    json_path: String,
) raises:
    for child in schema.children:
        ref stmt = child[]
        if stmt.spec != `unique` or not stmt.has_argument():
            continue
        ref arg = stmt.argument.get[UniqueArgument]()
        var seen = Dict[String, Int]()
        for i in range(len(data.payload[JsonArray].values)):
            ref entry = data.payload[JsonArray].values[i][]
            var tuple_key = String()
            var complete = True
            for j in range(len(arg.paths)):
                var value = _unique_path_value(entry, arg.paths[j])
                if not value:
                    complete = False
                    break
                _append_unique_component(tuple_key, value.value())
            if not complete:
                continue
            if tuple_key in seen:
                _raise_json_path_error(
                    json_path,
                    entry.source_line,
                    path + "[" + String(i) + "]",
                    ": duplicate values for `unique` `" + stmt.argument_text() + "`",
                )
            seen[tuple_key] = i


def validate_leaf_list_value(
    read value: JsonValue,
    read leaf_list: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    read root: JsonValue,
    mut cache: LeafrefCache,
) raises:
    if value.kind != JsonValue.ARRAY:
        _raise_json_path_error(
            json_path,
            value.source_line,
            path,
            ": expected JSON array for leaf-list",
        )
    _validate_cardinality(value, leaf_list, module, path, json_path, "leaf-list")
    var proxy = YangConstruct("leaf", leaf_list.line)
    proxy.spec = `leaf`
    for ch in leaf_list.children:
        proxy.children.append(ch.copy())
    for i in range(len(value.payload[JsonArray].values)):
        validate_leaf_value(
            value.payload[JsonArray].values[i][],
            proxy,
            module,
            path + "[" + String(i) + "]",
            json_path,
            root,
            cache,
        )


@no_inline
def validate_object_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    read root: JsonValue,
    mut cache: LeafrefCache,
) raises:
    validate_object_against_construct(
        data, schema, module, path, json_path, path, root, cache
    )


@no_inline
def validate_object_against_construct(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    path: String,
    json_path: String,
    schema_path: String,
    read root: JsonValue,
    mut cache: LeafrefCache,
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

    for i in range(len(data.payload[JsonObject].keys)):
        var key = data.payload[JsonObject].keys[i]
        ref slot = data.payload[JsonObject].values[i][]
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
            validate_leaf_value(
                slot, child, module, child_path, json_path, root, cache
            )
            continue

        if child_kind == `leaf-list`:
            validate_leaf_list_value(
                slot, child, module, child_path, json_path, root, cache
            )
            continue

        if child_kind == `container`:
            validate_object_against_construct(
                slot,
                child,
                module,
                child_path,
                json_path,
                schema_path + "/" + key,
                root,
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
                root,
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
    read root: JsonValue,
    mut cache: LeafrefCache,
) raises:
    if data.kind != JsonValue.ARRAY:
        _raise_json_path_error(
            json_path, data.source_line, path, ": expected JSON array for list"
        )
    _validate_cardinality(data, schema, module, path, json_path, "list")
    _validate_unique_constraints(data, schema, path, json_path)
    var key_stmt = module.find_child(schema, `key`)
    for i in range(len(data.payload[JsonArray].values)):
        ref entry = data.payload[JsonArray].values[i][]
        var entry_path = path + "[" + String(i) + "]"
        validate_object_against_construct(
            entry, schema, module, entry_path, json_path, schema_path,
            root, cache,
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
