## YANG-from-JSON: JSON Schema + `x-yang` → AST
##
## This module is the **second half** of the JSON pipeline: `xyang.json.parser`
## turns bytes into a `JsonValue` tree; this file interprets that tree as YANG
## metadata and emits the same **`YangConstruct` graph** the text lexer/parser
## produces, so downstream validation and `YangModule` indexing can run
## unchanged.
##
## **Input shape (conventions)**
## - Root JSON object must carry an **`x-yang`** object with module fields
##   (`module`, `namespace`, `prefix`, …).
## - For string leaves, **`x-yang.pattern`** and **`x-yang.patternInvert`** map to
##   `pattern` and `modifier invert-match` (RFC 7950 §9.4.5–9.4.6).
## - **`x-yang.length`**: use only for RFC `length-arg` that JSON Schema cannot
##   express (`|`, `min` / `max`, etc.). Plain bounds belong in **`minLength`** /
##   **`maxLength`**; if those are set, they define `length` and a *simple*
##   `x-yang.length` (a single integer or `digits..digits`) is ignored.
## - Each schema object that becomes a data node (leaf, container, …) must
##   have its own **`x-yang`** object with a **`type`** field naming the YANG
##   statement kind (`leaf`, `list`, `container`, …). Objects without `x-yang`
##   are ignored by `_convert_property`.
## - **`$defs`** entries become `typedef` or `identity` children depending on
##   `x-yang.type` in each def. Top-level **`properties`** become module
##   children via `_convert_property` (recursive for `properties` under
##   containers and list `items`).
##
## **Main pieces**
## - `_type_from_schema` — maps a property schema (JSON Schema keywords +
##   optional `x-yang`) to a `type …` subtree (`enumeration`, `union`, builtins,
##   `leafref`, …).
## - `_convert_property` — one root or nested property → optional
##   `container` / `list` / `leaf` / … node.
## - `parse_yang_json` — assemble module header, `$defs`, then properties.
## - `parse_yang_json_module` — same tree, then `YangModule.ingest_construct_tree`.

from std.memory import ArcPointer

import xyang.json.parser as json_parser
import xyang.yang.ast.util as ast_util
from xyang.yang.arguments import _strip_spaces
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule

comptime Arc = ArcPointer


comptime `^b` = ast_util.to_byte["^"]()
comptime `$b` = ast_util.to_byte["$"]()


def _parse_ascii_uint64(read s: String) -> Int64:
    ## Decimal digits only; returns -1 on empty or invalid (no `atol` / no raises).
    var b = s.as_bytes()
    var n = len(b)
    if n == 0:
        return -1
    var acc: Int64 = 0
    comptime d0 = ast_util.to_byte["0"]()
    comptime d9 = ast_util.to_byte["9"]()
    for i in range(n):
        var c = b[i]
        if c < d0 or c > d9:
            return -1
        acc = acc * 10 + Int64(c - d0)
    return acc


## --- `YangConstruct` tree helpers (keyword + argument + children) ---


@always_inline
def _stmt(
    keyword: String, argument: String = "", line: UInt = 0
) -> YangConstruct:
    var node = YangConstruct(keyword, line)
    if argument.byte_length() > 0:
        node.set_raw_argument(argument)
    return node^


def _append_stmt(mut parent: YangConstruct, var child: YangConstruct):
    parent.children.append(Arc[YangConstruct](child^))


def _append_arg(mut parent: YangConstruct, keyword: String, argument: String):
    if argument.byte_length() == 0:
        return
    _append_stmt(parent, _stmt(keyword, argument))


## --- Typed reads from `JsonValue` objects (by string key) ---


def _json_string(
    read obj: json_parser.JsonValue, key: String, default: String = ""
) -> String:
    var value = json_parser.json_get(obj, key)
    if value and value.value()[].kind == json_parser.JsonValue.STRING:
        return value.value()[].text
    return default


def _json_bool(
    read obj: json_parser.JsonValue, key: String, default: Bool = False
) -> Bool:
    var value = json_parser.json_get(obj, key)
    if value and value.value()[].kind == json_parser.JsonValue.BOOL:
        return value.value()[].bool_value
    return default


def _json_scalar(
    read obj: json_parser.JsonValue, key: String
) -> Optional[String]:
    var value = json_parser.json_get(obj, key)
    if not value:
        return Optional[String]()
    ref v = value.value()[]
    if (
        v.kind == json_parser.JsonValue.STRING
        or v.kind == json_parser.JsonValue.INT
        or v.kind == json_parser.JsonValue.BOOL
    ):
        return Optional[String](json_parser.json_scalar_text(v))
    return Optional[String]()


def _ascii_digits_only(read s: String) -> Bool:
    if s.byte_length() == 0:
        return False
    var b = s.as_bytes()
    for i in range(len(b)):
        var c = Int(b[i])
        if c < ord("0") or c > ord("9"):
            return False
    return True


def _yang_length_requires_xyang(read expr: String) -> Bool:
    ## True when `length-arg` cannot be represented with only JSON Schema
    ## `minLength` / `maxLength` (RFC 7950 §9.4.4).
    var s = _strip_spaces(expr)
    if s.byte_length() == 0:
        return False
    if s.find("|") >= 0:
        return True
    if s.find("..max") >= 0:
        return True
    if s.startswith("min.."):
        return True
    if s.find("..min") >= 0:
        return True
    if s == "min" or s == "max":
        return True
    var parts = s.split("..")
    if len(parts) == 1:
        return not _ascii_digits_only(String(parts[0]))
    if len(parts) == 2:
        return not (
            _ascii_digits_only(String(parts[0]))
            and _ascii_digits_only(String(parts[1]))
        )
    return True


def _strip_json_schema_anchors(pattern: String) -> String:
    var out = pattern
    if out.byte_length() > 0 and out.as_bytes()[0] == `^b`:
        out = String(StringSlice(unsafe_from_utf8=out.as_bytes()[1:]))
    if out.byte_length() > 0 and out.as_bytes()[out.byte_length() - 1] == `$b`:
        out = String(
            StringSlice(
                unsafe_from_utf8=out.as_bytes()[0 : out.byte_length() - 1]
            )
        )
    return out^


def _ref_typedef_name(ref_text: String) -> String:
    comptime prefix = "#/$defs/"
    if ref_text.startswith(prefix):
        return String(
            StringSlice(
                unsafe_from_utf8=ref_text.as_bytes()[prefix.byte_length() :]
            )
        )
    return String(ref_text)


## --- `x-yang` blob access and YANG-shaped extras (when, must, range) ---


def _xyang(
    read schema: json_parser.JsonValue,
) -> Optional[Arc[json_parser.JsonValue]]:
    return json_parser.json_get(schema, "x-yang")


def _xyang_type(read schema: json_parser.JsonValue) -> String:
    var xy = _xyang(schema)
    if xy and xy.value()[].kind == json_parser.JsonValue.OBJECT:
        return _json_string(xy.value()[], "type")
    return ""


def _append_when(mut node: YangConstruct, read xyang: json_parser.JsonValue):
    var when_value = json_parser.json_get(xyang, "when")
    if (
        not when_value
        or when_value.value()[].kind != json_parser.JsonValue.OBJECT
    ):
        return
    var cond = _json_string(when_value.value()[], "condition")
    if cond.byte_length() == 0:
        return
    var when_node = _stmt("when", cond)
    _append_arg(
        when_node,
        "description",
        _json_string(when_value.value()[], "description"),
    )
    _append_stmt(node, when_node^)


def _append_musts(mut node: YangConstruct, read xyang: json_parser.JsonValue):
    var must_value = json_parser.json_get(xyang, "must")
    if (
        not must_value
        or must_value.value()[].kind != json_parser.JsonValue.ARRAY
    ):
        return
    for item in must_value.value()[].array_values:
        if item[].kind != json_parser.JsonValue.OBJECT:
            continue
        var expr = _json_string(item[], "must")
        if expr.byte_length() == 0:
            continue
        var must_node = _stmt("must", expr)
        _append_arg(
            must_node, "error-message", _json_string(item[], "error-message")
        )
        _append_arg(
            must_node, "description", _json_string(item[], "description")
        )
        _append_stmt(node, must_node^)


def _append_range_from_schema(
    mut type_node: YangConstruct, read schema: json_parser.JsonValue
):
    var minv = _json_scalar(schema, "minimum")
    var maxv = _json_scalar(schema, "maximum")
    if minv and maxv:
        _append_arg(type_node, "range", minv.value() + ".." + maxv.value())
    elif minv:
        _append_arg(type_node, "range", minv.value() + "..max")
    elif maxv:
        _append_arg(type_node, "range", "min.." + maxv.value())


## --- JSON Schema → single `type` statement subtree ---


def _type_from_schema(
    read schema: json_parser.JsonValue, read defs: json_parser.JsonValue
) -> YangConstruct:
    var xy = _xyang(schema)
    var xy_type = String()
    if xy and xy.value()[].kind == json_parser.JsonValue.OBJECT:
        xy_type = _json_string(xy.value()[], "type")

    if xy_type == "leafref":
        var t = _stmt("type", "leafref")
        _append_arg(t, "path", _json_string(xy.value()[], "path"))
        return t^
    if xy_type == "identityref":
        var t = _stmt("type", "identityref")
        _append_arg(t, "base", _json_string(xy.value()[], "base"))
        var bases = json_parser.json_get(xy.value()[], "bases")
        if bases and bases.value()[].kind == json_parser.JsonValue.ARRAY:
            for base in bases.value()[].array_values:
                if base[].kind == json_parser.JsonValue.STRING:
                    _append_arg(t, "base", base[].text)
        return t^
    if xy_type == "instance-identifier":
        return _stmt("type", "instance-identifier")
    if xy_type == "bits":
        var t = _stmt("type", "bits")
        var bits = json_parser.json_get(xy.value()[], "bits")
        if bits and bits.value()[].kind == json_parser.JsonValue.ARRAY:
            for bit in bits.value()[].array_values:
                if bit[].kind == json_parser.JsonValue.STRING:
                    _append_arg(t, "bit", bit[].text)
                elif bit[].kind == json_parser.JsonValue.OBJECT:
                    _append_arg(t, "bit", _json_string(bit[], "name"))
        return t^

    var ref_value = json_parser.json_get(schema, "$ref")
    if ref_value and ref_value.value()[].kind == json_parser.JsonValue.STRING:
        return _stmt("type", _ref_typedef_name(ref_value.value()[].text))

    var one_of = json_parser.json_get(schema, "oneOf")
    if one_of and one_of.value()[].kind == json_parser.JsonValue.ARRAY:
        var t = _stmt("type", "union")
        for branch in one_of.value()[].array_values:
            if branch[].kind == json_parser.JsonValue.OBJECT:
                _append_stmt(t, _type_from_schema(branch[], defs))
        return t^

    var enum_value = json_parser.json_get(schema, "enum")
    if enum_value and enum_value.value()[].kind == json_parser.JsonValue.ARRAY:
        var t = _stmt("type", "enumeration")
        for e in enum_value.value()[].array_values:
            if e[].kind == json_parser.JsonValue.STRING:
                _append_arg(t, "enum", e[].text)
        return t^

    var schema_type = _json_string(schema, "type", "string")
    if schema_type == "boolean":
        return _stmt("type", "boolean")
    if schema_type == "object":
        var max_props = _json_scalar(schema, "maxProperties")
        if max_props and max_props.value() == "0":
            return _stmt("type", "empty")
        return _stmt("type", "string")
    if schema_type == "array":
        var items = json_parser.json_get(schema, "items")
        if items and items.value()[].kind == json_parser.JsonValue.OBJECT:
            return _type_from_schema(items.value()[], defs)
        return _stmt("type", "string")
    if schema_type == "integer":
        var minv = _json_scalar(schema, "minimum")
        var maxv = _json_scalar(schema, "maximum")
        if minv and maxv and minv.value() == "0" and maxv.value() == "255":
            return _stmt("type", "uint8")
        if minv and maxv:
            var lo = _parse_ascii_uint64(minv.value())
            var hi = _parse_ascii_uint64(maxv.value())
            if lo >= 0 and hi >= 0 and lo <= hi and hi <= 65535:
                var t16 = _stmt("type", "uint16")
                _append_range_from_schema(t16, schema)
                return t16^
        var t = _stmt("type", "int32")
        _append_range_from_schema(t, schema)
        return t^
    if schema_type == "number":
        var t = _stmt("type", "decimal64")
        if xy and xy.value()[].kind == json_parser.JsonValue.OBJECT:
            var fd = _json_scalar(xy.value()[], "fraction-digits")
            if fd:
                _append_arg(t, "fraction-digits", fd.value())
        _append_range_from_schema(t, schema)
        return t^

    var t = _stmt("type", "string")
    var min_len = _json_scalar(schema, "minLength")
    var max_len = _json_scalar(schema, "maxLength")
    var has_json_len = min_len or max_len

    var xy_len = String()
    if xy and xy.value()[].kind == json_parser.JsonValue.OBJECT:
        xy_len = _json_string(xy.value()[], "length")

    var used_complex_xy_len = False
    if xy_len.byte_length() > 0 and _yang_length_requires_xyang(xy_len):
        _append_arg(t, "length", xy_len)
        used_complex_xy_len = True
    elif xy_len.byte_length() > 0 and not has_json_len:
        _append_arg(t, "length", xy_len)

    if not used_complex_xy_len:
        if min_len and max_len:
            _append_arg(t, "length", min_len.value() + ".." + max_len.value())
        elif min_len:
            _append_arg(t, "length", min_len.value() + "..max")
        elif max_len:
            _append_arg(t, "length", "0.." + max_len.value())
    var pat_invert = False
    var xy_pat = String()
    if xy and xy.value()[].kind == json_parser.JsonValue.OBJECT:
        pat_invert = _json_bool(xy.value()[], "patternInvert")
        xy_pat = _json_string(xy.value()[], "pattern")
    var json_pat = _json_scalar(schema, "pattern")
    var pat_text = String()
    if xy_pat.byte_length() > 0:
        pat_text = _strip_json_schema_anchors(xy_pat)
    elif json_pat:
        pat_text = _strip_json_schema_anchors(json_pat.value())
    if pat_text.byte_length() > 0:
        if pat_invert:
            var pnode = _stmt("pattern", pat_text)
            _append_arg(pnode, "modifier", "invert-match")
            _append_stmt(t, pnode^)
        else:
            _append_arg(t, "pattern", pat_text)
    return t^


## --- JSON Schema `oneOf` + `x-yang.choice` → YANG `choice` / `case` ---


def _append_cases_from_oneof(
    mut choice_node: YangConstruct,
    read one_of_arr: json_parser.JsonValue,
    read defs: json_parser.JsonValue,
) raises:
    ## Each `oneOf` branch becomes a `case`; branch `x-yang.name` is the case id.
    if one_of_arr.kind != json_parser.JsonValue.ARRAY:
        return
    for bi in range(len(one_of_arr.array_values)):
        ref branch = one_of_arr.array_values[bi][]
        if branch.kind != json_parser.JsonValue.OBJECT:
            continue
        var bxy = _xyang(branch)
        var case_id = String("case-") + String(bi)
        if bxy and bxy.value()[].kind == json_parser.JsonValue.OBJECT:
            var nn = _json_string(bxy.value()[], "name")
            if nn.byte_length() > 0:
                case_id = nn.copy()
        var case_node = _stmt("case", case_id)
        var props = json_parser.json_get(branch, "properties")
        var required = json_parser.json_get(branch, "required")
        if props and props.value()[].kind == json_parser.JsonValue.OBJECT:
            for j in range(len(props.value()[].object_keys)):
                var child_name = props.value()[].object_keys[j]
                var mandatory = Optional[Bool]()
                if (
                    required
                    and required.value()[].kind == json_parser.JsonValue.ARRAY
                ):
                    for req in required.value()[].array_values:
                        if (
                            req[].kind == json_parser.JsonValue.STRING
                            and req[].text == child_name
                        ):
                            mandatory = Optional[Bool](True)
                var child = _convert_property(
                    child_name,
                    props.value()[].object_values[j][],
                    defs,
                    mandatory,
                )
                if child:
                    _append_stmt(case_node, child.take())
        _append_stmt(choice_node, case_node^)


def _append_choice_from_schema_oneof(
    mut container_node: YangConstruct,
    read schema: json_parser.JsonValue,
    read xy: json_parser.JsonValue,
    read defs: json_parser.JsonValue,
) raises:
    ## When a `container` schema uses `oneOf` for mutually exclusive branches,
    ## `x-yang.choice` supplies the YANG choice name and metadata.
    var one_of_top = json_parser.json_get(schema, "oneOf")
    var choice_blob = json_parser.json_get(xy, "choice")
    if (
        not one_of_top
        or one_of_top.value()[].kind != json_parser.JsonValue.ARRAY
        or not choice_blob
        or choice_blob.value()[].kind != json_parser.JsonValue.OBJECT
    ):
        return
    ref ch_xy = choice_blob.value()[]
    var ch = _stmt("choice", _json_string(ch_xy, "name", "branches"))
    _append_arg(ch, "description", _json_string(ch_xy, "description"))
    if _json_bool(ch_xy, "mandatory"):
        _append_arg(ch, "mandatory", "true")
    _append_cases_from_oneof(ch, one_of_top.value()[], defs)
    _append_stmt(container_node, ch^)


## --- One schema property → optional child statement (recursive) ---


def _convert_property(
    name: String,
    read prop_value: json_parser.JsonValue,
    read defs: json_parser.JsonValue,
    mandatory_override: Optional[Bool] = Optional[Bool](),
) raises -> Optional[YangConstruct]:
    if prop_value.kind != json_parser.JsonValue.OBJECT:
        return Optional[YangConstruct]()
    ref schema = prop_value
    var xy = _xyang(schema)
    if not xy or xy.value()[].kind != json_parser.JsonValue.OBJECT:
        return Optional[YangConstruct]()
    var node_type = _json_string(xy.value()[], "type")
    if (
        node_type == "leafref"
        or node_type == "identityref"
        or node_type == "instance-identifier"
    ):
        node_type = "leaf"

    if node_type == "container":
        var node = _stmt("container", name)
        _append_arg(node, "description", _json_string(schema, "description"))
        _append_arg(node, "presence", _json_string(xy.value()[], "presence"))
        _append_when(node, xy.value()[])
        _append_musts(node, xy.value()[])
        var props = json_parser.json_get(schema, "properties")
        if props and props.value()[].kind == json_parser.JsonValue.OBJECT:
            var required = json_parser.json_get(schema, "required")
            for i in range(len(props.value()[].object_keys)):
                var child_name = props.value()[].object_keys[i]
                var mandatory = Optional[Bool]()
                if (
                    required
                    and required.value()[].kind == json_parser.JsonValue.ARRAY
                ):
                    for req in required.value()[].array_values:
                        if (
                            req[].kind == json_parser.JsonValue.STRING
                            and req[].text == child_name
                        ):
                            mandatory = Optional[Bool](True)
                var child = _convert_property(
                    child_name,
                    props.value()[].object_values[i][],
                    defs,
                    mandatory,
                )
                if child:
                    _append_stmt(node, child.take())
        _append_choice_from_schema_oneof(node, schema, xy.value()[], defs)
        return Optional[YangConstruct](node^)

    if node_type == "choice":
        var ch_node = _stmt("choice", name)
        _append_arg(ch_node, "description", _json_string(schema, "description"))
        _append_when(ch_node, xy.value()[])
        _append_musts(ch_node, xy.value()[])
        if _json_bool(xy.value()[], "mandatory"):
            _append_arg(ch_node, "mandatory", "true")
        var one_of_ch = json_parser.json_get(schema, "oneOf")
        if (
            not one_of_ch
            or one_of_ch.value()[].kind != json_parser.JsonValue.ARRAY
        ):
            return Optional[YangConstruct]()
        _append_cases_from_oneof(ch_node, one_of_ch.value()[], defs)
        return Optional[YangConstruct](ch_node^)

    if node_type == "list":
        var node = _stmt("list", name)
        _append_arg(node, "key", _json_string(xy.value()[], "key"))
        var min_items = _json_scalar(schema, "minItems")
        if min_items:
            _append_arg(node, "min-elements", min_items.value())
        var max_items = _json_scalar(schema, "maxItems")
        if max_items:
            _append_arg(node, "max-elements", max_items.value())
        _append_arg(node, "description", _json_string(schema, "description"))
        _append_when(node, xy.value()[])
        _append_musts(node, xy.value()[])
        var items = json_parser.json_get(schema, "items")
        if items and items.value()[].kind == json_parser.JsonValue.OBJECT:
            var props = json_parser.json_get(items.value()[], "properties")
            var required = json_parser.json_get(items.value()[], "required")
            if props and props.value()[].kind == json_parser.JsonValue.OBJECT:
                for i in range(len(props.value()[].object_keys)):
                    var child_name = props.value()[].object_keys[i]
                    var mandatory = Optional[Bool]()
                    if (
                        required
                        and required.value()[].kind
                        == json_parser.JsonValue.ARRAY
                    ):
                        for req in required.value()[].array_values:
                            if (
                                req[].kind == json_parser.JsonValue.STRING
                                and req[].text == child_name
                            ):
                                mandatory = Optional[Bool](True)
                    var child = _convert_property(
                        child_name,
                        props.value()[].object_values[i][],
                        defs,
                        mandatory,
                    )
                    if child:
                        _append_stmt(node, child.take())
        return Optional[YangConstruct](node^)

    if node_type == "leaf" or node_type == "leaf-list":
        var node = _stmt(node_type, name)
        _append_when(node, xy.value()[])
        if node_type == "leaf-list":
            var items = json_parser.json_get(schema, "items")
            if items and items.value()[].kind == json_parser.JsonValue.OBJECT:
                _append_stmt(node, _type_from_schema(items.value()[], defs))
            else:
                _append_stmt(node, _type_from_schema(schema, defs))
        else:
            _append_stmt(node, _type_from_schema(schema, defs))
        var mandatory = False
        if mandatory_override:
            mandatory = mandatory_override.value()
        elif _json_bool(xy.value()[], "mandatory"):
            mandatory = True
        if mandatory:
            _append_arg(node, "mandatory", "true")
        var min_items = _json_scalar(schema, "minItems")
        if min_items:
            _append_arg(node, "min-elements", min_items.value())
        var max_items = _json_scalar(schema, "maxItems")
        if max_items:
            _append_arg(node, "max-elements", max_items.value())
        var default_value = _json_scalar(schema, "default")
        if default_value:
            _append_arg(node, "default", default_value.value())
        _append_arg(node, "description", _json_string(schema, "description"))
        _append_musts(node, xy.value()[])
        return Optional[YangConstruct](node^)

    if node_type == "anydata" or node_type == "anyxml":
        var node = _stmt(node_type, name)
        _append_arg(node, "description", _json_string(schema, "description"))
        _append_when(node, xy.value()[])
        _append_musts(node, xy.value()[])
        return Optional[YangConstruct](node^)

    return Optional[YangConstruct]()


## --- `$defs` map → typedef / identity children on the module node ---


def _append_typedefs_and_identities(
    mut module: YangConstruct, read defs: json_parser.JsonValue
):
    if defs.kind != json_parser.JsonValue.OBJECT:
        return
    for i in range(len(defs.object_keys)):
        var name = defs.object_keys[i]
        ref schema = defs.object_values[i][]
        if schema.kind != json_parser.JsonValue.OBJECT:
            continue
        var xy_type = _xyang_type(schema)
        if xy_type == "identity":
            var ident = _stmt("identity", name)
            _append_arg(
                ident, "description", _json_string(schema, "description")
            )
            var xy = _xyang(schema)
            if xy and xy.value()[].kind == json_parser.JsonValue.OBJECT:
                _append_arg(ident, "base", _json_string(xy.value()[], "base"))
            _append_stmt(module, ident^)
            continue
        var td = _stmt("typedef", name)
        _append_stmt(td, _type_from_schema(schema, defs))
        _append_arg(td, "description", _json_string(schema, "description"))
        _append_stmt(module, td^)


## --- Public API ---


def parse_yang_json(
    source: String, source_path: String = ""
) raises -> YangConstruct:
    """Return the module `YangConstruct` root only (no spec validation).

    Callers that need a `YangModule` should use `parse_yang_json_module`.
    """
    var root = json_parser.parse_json(source, source_path)
    if root.kind != json_parser.JsonValue.OBJECT:
        raise Error("YANG JSON root must be an object")
    var xy = _xyang(root)
    if not xy or xy.value()[].kind != json_parser.JsonValue.OBJECT:
        raise Error("YANG JSON root is missing object `x-yang` metadata")

    var module = _stmt(
        "module", _json_string(xy.value()[], "module", "unknown")
    )
    _append_arg(
        module,
        "yang-version",
        _json_string(xy.value()[], "yang-version", "1.1"),
    )
    _append_arg(module, "namespace", _json_string(xy.value()[], "namespace"))
    _append_arg(module, "prefix", _json_string(xy.value()[], "prefix"))
    _append_arg(
        module, "organization", _json_string(xy.value()[], "organization")
    )
    _append_arg(module, "contact", _json_string(xy.value()[], "contact"))
    _append_arg(module, "description", _json_string(root, "description"))

    var defs = json_parser.json_get(root, "$defs")
    if defs:
        _append_typedefs_and_identities(module, defs.value()[])

    var props = json_parser.json_get(root, "properties")
    if props and props.value()[].kind == json_parser.JsonValue.OBJECT:
        var empty_defs = json_parser.make_json(json_parser.JsonValue.OBJECT)
        for i in range(len(props.value()[].object_keys)):
            if defs:
                var child = _convert_property(
                    props.value()[].object_keys[i],
                    props.value()[].object_values[i][],
                    defs.value()[],
                )
                if child:
                    _append_stmt(module, child.take())
            else:
                var child = _convert_property(
                    props.value()[].object_keys[i],
                    props.value()[].object_values[i][],
                    empty_defs,
                )
                if child:
                    _append_stmt(module, child.take())
    return module^


def parse_yang_json_module(
    source: String, source_path: String = ""
) raises -> YangModule:
    """Parse JSON/YANG and validate/index it as a `YangModule`.

    The returned module uses the same `YangConstruct` root representation as
    the text YANG parser. Validation is intentionally left in place, so schemas
    that use constructs beyond the current Mojo validator surface will fail
    after the raw tree has been built.
    """
    var tree = parse_yang_json(source, source_path)
    var module = YangModule()
    module.ingest_construct_tree(tree^)
    return module^
