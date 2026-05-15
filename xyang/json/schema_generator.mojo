## YANG AST -> JSON Schema with `x-yang` annotations.

from xyang.json.value import json_escape
from xyang.yang.arguments import TypeArgument
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.keyword import Keyword
from xyang.yang.runtime_spec import keyword_spelling
from xyang.yang.visitor.uses_expand_visitor import expand_uses_throughout_module
from std.memory import ArcPointer


def _indent(n: Int) -> String:
    var s = String()
    for _ in range(n):
        s += "  "
    return s^


def _q(read s: String) -> String:
    return '"' + json_escape(s) + '"'


def _json_bool(v: Bool) -> String:
    if v:
        return "true"
    return "false"


def _append_pair(
    mut out: String, mut count: Int, indent: Int, key: String, value: String
):
    if count > 0:
        out += ",\n"
    out += _indent(indent) + _q(key) + ": " + value
    count += 1


def _child_arg(read node: YangConstruct, kw: Keyword) -> Optional[String]:
    for child in node.children:
        if child[].spec == kw and child[].has_argument():
            return Optional[String](child[].argument_text())
    return Optional[String]()


def _has_child_arg(
    read node: YangConstruct, kw: Keyword, value: String
) -> Bool:
    var arg = _child_arg(node, kw)
    if not arg:
        return False
    return arg.value() == value


def _is_data_node(read node: YangConstruct) -> Bool:
    from xyang.yang.spec import (
        `anydata`,
        `anyxml`,
        `choice`,
        `container`,
        `leaf`,
        `leaf-list`,
        `list`,
    )

    return (
        node.spec == `anydata`
        or node.spec == `anyxml`
        or node.spec == `choice`
        or node.spec == `container`
        or node.spec == `leaf`
        or node.spec == `leaf-list`
        or node.spec == `list`
    )


def _append_description(
    mut out: String, mut count: Int, read node: YangConstruct, indent: Int
):
    from xyang.yang.spec import `description`

    var desc = _child_arg(node, `description`)
    if desc:
        _append_pair(out, count, indent, "description", _q(desc.value()))


def _append_type_schema_pairs(
    read module: YangModule,
    mut out: String,
    mut count: Int,
    read type_stmt: YangConstruct,
    indent: Int,
):
    from xyang.yang.spec import (
        `base`,
        `bit`,
        `enum`,
        `fraction-digits`,
        `length`,
        `modifier`,
        `path`,
        `pattern`,
        `range-stmt`,
        `require-instance`,
        `type`,
    )

    ref type_arg = type_stmt.argument.get[TypeArgument]()
    if type_arg.local_name in module.typedefs:
        _append_pair(
            out, count, indent, "$ref", _q("#/$defs/" + type_arg.local_name)
        )
    elif type_arg.is_boolean():
        _append_pair(out, count, indent, "type", _q("boolean"))
    elif type_arg.is_number():
        _append_pair(out, count, indent, "type", _q("number"))
    elif type_arg.is_integer():
        _append_pair(out, count, indent, "type", _q("integer"))
    elif type_arg.is_enumeration():
        _append_pair(out, count, indent, "type", _q("string"))
        var enum_text = String("[")
        var enum_count = 0
        for child in type_stmt.children:
            if child[].spec == `enum` and child[].has_argument():
                if enum_count > 0:
                    enum_text += ", "
                enum_text += _q(child[].argument_text())
                enum_count += 1
        enum_text += "]"
        if enum_count > 0:
            _append_pair(out, count, indent, "enum", enum_text)
    elif type_arg.is_empty():
        _append_pair(out, count, indent, "type", _q("object"))
        _append_pair(out, count, indent, "maxProperties", "0")
    elif type_arg.is_union():
        var one = String("[\n")
        var branch_count = 0
        for child in type_stmt.children:
            if child[].spec != `type`:
                continue
            if branch_count > 0:
                one += ",\n"
            one += _emit_type_only_schema(module, child[], indent + 1)
            branch_count += 1
        one += "\n" + _indent(indent) + "]"
        if branch_count > 0:
            _append_pair(out, count, indent, "oneOf", one)
        else:
            _append_pair(out, count, indent, "type", _q("string"))
    else:
        _append_pair(out, count, indent, "type", _q("string"))

    var range_text = _child_arg(type_stmt, `range-stmt`)
    if range_text:
        var parts = range_text.value().split("..")
        if len(parts) == 2:
            if String(parts[0]) != "min":
                _append_pair(out, count, indent, "minimum", String(parts[0]))
            if String(parts[1]) != "max":
                _append_pair(out, count, indent, "maximum", String(parts[1]))

    var length_text = _child_arg(type_stmt, `length`)
    if length_text:
        var parts = length_text.value().split("..")
        if len(parts) == 2:
            if String(parts[0]) != "min":
                _append_pair(out, count, indent, "minLength", String(parts[0]))
            if String(parts[1]) != "max":
                _append_pair(out, count, indent, "maxLength", String(parts[1]))

    for child in type_stmt.children:
        if child[].spec != `pattern` or not child[].has_argument():
            continue
        var inverted = _has_child_arg(child[], `modifier`, "invert-match")
        if inverted:
            continue
        _append_pair(
            out,
            count,
            indent,
            "pattern",
            _q("^" + child[].argument_text() + "$"),
        )
        break

    var patterns = String("[")
    var pattern_count = 0
    for child in type_stmt.children:
        if child[].spec != `pattern` or not child[].has_argument():
            continue
        if pattern_count > 0:
            patterns += ", "
        var inverted = _has_child_arg(child[], `modifier`, "invert-match")
        patterns += '{"pattern": ' + _q(child[].argument_text())
        patterns += ', "invert-match": ' + _json_bool(inverted)
        _append_child_metadata(patterns, child[])
        patterns += "}"
        pattern_count += 1
    if pattern_count > 0:
        patterns += "]"
        _append_pair(out, count, indent, "x-yang", '{"string-patterns": ' + patterns + "}")


def _emit_type_only_schema(
    read module: YangModule, read type_stmt: YangConstruct, indent: Int
) -> String:
    var out = _indent(indent) + "{\n"
    var count = 0
    _append_type_schema_pairs(module, out, count, type_stmt, indent + 1)
    out += "\n" + _indent(indent) + "}"
    return out^


def _append_child_metadata(mut out: String, read node: YangConstruct):
    from xyang.yang.spec import (
        `description`,
        `error-app-tag`,
        `error-message`,
        `reference`,
        `status`,
    )

    var desc = _child_arg(node, `description`)
    if desc:
        out += ', "description": ' + _q(desc.value())
    var err = _child_arg(node, `error-message`)
    if err:
        out += ', "error-message": ' + _q(err.value())
    var tag = _child_arg(node, `error-app-tag`)
    if tag:
        out += ', "error-app-tag": ' + _q(tag.value())
    var ref_text = _child_arg(node, `reference`)
    if ref_text:
        out += ', "reference": ' + _q(ref_text.value())
    var status_text = _child_arg(node, `status`)
    if status_text:
        out += ', "status": ' + _q(status_text.value())


def _append_x_yang_common(
    mut xyang: String,
    mut count: Int,
    read node: YangConstruct,
    xyang_type: String,
    indent: Int,
):
    from xyang.yang.spec import (
        `base`,
        `config`,
        `default`,
        `fraction-digits`,
        `if-feature`,
        `key`,
        `mandatory`,
        `max-elements`,
        `min-elements`,
        `must`,
        `ordered-by`,
        `path`,
        `presence`,
        `reference`,
        `require-instance`,
        `status`,
        `type`,
        `unique`,
        `units`,
        `when`,
    )

    _append_pair(xyang, count, indent, "type", _q(xyang_type))
    var config_arg = _child_arg(node, `config`)
    if config_arg:
        _append_pair(
            xyang, count, indent, "config", _json_bool(config_arg.value() == "true")
        )
    var status_arg = _child_arg(node, `status`)
    if status_arg:
        _append_pair(xyang, count, indent, "status", _q(status_arg.value()))
    var reference_arg = _child_arg(node, `reference`)
    if reference_arg:
        _append_pair(xyang, count, indent, "reference", _q(reference_arg.value()))
    var units_arg = _child_arg(node, `units`)
    if units_arg:
        _append_pair(xyang, count, indent, "units", _q(units_arg.value()))
    var default_arg = _child_arg(node, `default`)
    if default_arg:
        _append_pair(xyang, count, indent, "default", _q(default_arg.value()))
    var mandatory_arg = _child_arg(node, `mandatory`)
    if mandatory_arg and mandatory_arg.value() == "true":
        _append_pair(xyang, count, indent, "mandatory", "true")
    var key_arg = _child_arg(node, `key`)
    if key_arg:
        _append_pair(xyang, count, indent, "key", _q(key_arg.value()))
    var presence_arg = _child_arg(node, `presence`)
    if presence_arg:
        _append_pair(xyang, count, indent, "presence", _q(presence_arg.value()))
    var ordered_by = _child_arg(node, `ordered-by`)
    if ordered_by:
        _append_pair(xyang, count, indent, "ordered-by", _q(ordered_by.value()))
    var when_expr = _child_arg(node, `when`)
    if when_expr:
        _append_pair(
            xyang,
            count,
            indent,
            "when",
            '{"condition": ' + _q(when_expr.value()) + "}",
        )

    var if_features = String("[")
    var if_count = 0
    var first_if_feature = String()
    for child in node.children:
        if child[].spec == `if-feature` and child[].has_argument():
            if if_count == 0:
                first_if_feature = child[].argument_text()
            if if_count > 0:
                if_features += ", "
            if_features += _q(child[].argument_text())
            if_count += 1
    if if_count == 1:
        _append_pair(xyang, count, indent, "if-feature", _q(first_if_feature))
    elif if_count > 1:
        if_features += "]"
        _append_pair(xyang, count, indent, "if-features", if_features)

    var uniques = String("[")
    var unique_count = 0
    for child in node.children:
        if child[].spec == `unique` and child[].has_argument():
            if unique_count > 0:
                uniques += ", "
            uniques += _q(child[].argument_text())
            unique_count += 1
    if unique_count > 0:
        uniques += "]"
        _append_pair(xyang, count, indent, "unique", uniques)

    var type_stmt = _child_construct(node, `type`)
    if type_stmt:
        ref ty = type_stmt.value()[]
        if ty.has_argument():
            var ty_name = ty.argument_text()
            if ty_name == "leafref":
                var path_arg = _child_arg(ty, `path`)
                if path_arg:
                    _append_pair(
                        xyang, count, indent, "path", _q(path_arg.value())
                    )
                var req = _child_arg(ty, `require-instance`)
                if req:
                    _append_pair(
                        xyang,
                        count,
                        indent,
                        "require-instance",
                        _json_bool(req.value() == "true"),
                    )
            elif ty_name == "identityref":
                var base_arg = _child_arg(ty, `base`)
                if base_arg:
                    _append_pair(
                        xyang, count, indent, "base", _q(base_arg.value())
                    )
            elif ty_name == "decimal64":
                var fd = _child_arg(ty, `fraction-digits`)
                if fd:
                    _append_pair(
                        xyang, count, indent, "fraction-digits", fd.value()
                    )

    var musts = String("[")
    var must_count = 0
    for child in node.children:
        if child[].spec != `must` or not child[].has_argument():
            continue
        if must_count > 0:
            musts += ", "
        musts += '{"must": ' + _q(child[].argument_text())
        _append_child_metadata(musts, child[])
        musts += "}"
        must_count += 1
    if must_count > 0:
        musts += "]"
        _append_pair(xyang, count, indent, "must", musts)


def _child_construct(
    read node: YangConstruct, kw: Keyword
) -> Optional[ArcPointer[YangConstruct]]:
    for child in node.children:
        if child[].spec == kw:
            return Optional[ArcPointer[YangConstruct]](child.copy())
    return Optional[ArcPointer[YangConstruct]]()


def _emit_x_yang(
    read node: YangConstruct, xyang_type: String, indent: Int
) -> String:
    var out = "{\n"
    var count = 0
    _append_x_yang_common(out, count, node, xyang_type, indent + 1)
    out += "\n" + _indent(indent) + "}"
    return out^


def _append_child_properties(
    read module: YangModule,
    mut out: String,
    mut count: Int,
    read parent: YangConstruct,
    indent: Int,
):
    var props = String("{\n")
    var prop_count = 0
    for child in parent.children:
        if not _is_data_node(child[]):
            continue
        if not child[].has_argument():
            continue
        if prop_count > 0:
            props += ",\n"
        props += _indent(indent + 1) + _q(child[].argument_text()) + ": "
        props += _emit_node_schema(module, child[], indent + 1)
        prop_count += 1
    props += "\n" + _indent(indent) + "}"
    if prop_count > 0:
        _append_pair(out, count, indent, "properties", props)


def _append_required(
    read parent: YangConstruct, mut out: String, mut count: Int, indent: Int
):
    from xyang.yang.spec import `mandatory`

    var req = String("[")
    var req_count = 0
    for child in parent.children:
        if not child[].has_argument():
            continue
        if _has_child_arg(child[], `mandatory`, "true"):
            if req_count > 0:
                req += ", "
            req += _q(child[].argument_text())
            req_count += 1
    if req_count > 0:
        req += "]"
        _append_pair(out, count, indent, "required", req)


def _append_schema_defaults(
    read node: YangConstruct, mut out: String, mut count: Int, indent: Int
):
    from xyang.yang.spec import `default`

    var defaults = String("[")
    var default_count = 0
    var first_default = String()
    for child in node.children:
        if child[].spec == `default` and child[].has_argument():
            if default_count == 0:
                first_default = child[].argument_text()
            if default_count > 0:
                defaults += ", "
            defaults += _q(child[].argument_text())
            default_count += 1
    if default_count == 1:
        _append_pair(out, count, indent, "default", _q(first_default))
    elif default_count > 1:
        defaults += "]"
        _append_pair(out, count, indent, "default", defaults)


def _emit_node_schema(
    read module: YangModule, read node: YangConstruct, indent: Int
) -> String:
    from xyang.yang.spec import (
        `anydata`,
        `anyxml`,
        `choice`,
        `container`,
        `leaf`,
        `leaf-list`,
        `list`,
        `max-elements`,
        `min-elements`,
        `type`,
    )

    var out = "{\n"
    var count = 0
    if node.spec == `container`:
        _append_pair(out, count, indent + 1, "type", _q("object"))
        _append_description(out, count, node, indent + 1)
        _append_pair(
            out,
            count,
            indent + 1,
            "x-yang",
            _emit_x_yang(node, "container", indent + 1),
        )
        _append_child_properties(module, out, count, node, indent + 1)
        _append_required(node, out, count, indent + 1)
    elif node.spec == `list`:
        _append_pair(out, count, indent + 1, "type", _q("array"))
        var min_items = _child_arg(node, `min-elements`)
        if min_items:
            _append_pair(out, count, indent + 1, "minItems", min_items.value())
        var max_items = _child_arg(node, `max-elements`)
        if max_items:
            _append_pair(out, count, indent + 1, "maxItems", max_items.value())
        _append_description(out, count, node, indent + 1)
        _append_pair(
            out,
            count,
            indent + 1,
            "x-yang",
            _emit_x_yang(node, "list", indent + 1),
        )
        var items = "{\n"
        var item_count = 0
        _append_pair(items, item_count, indent + 2, "type", _q("object"))
        _append_child_properties(module, items, item_count, node, indent + 2)
        _append_required(node, items, item_count, indent + 2)
        items += "\n" + _indent(indent + 1) + "}"
        _append_pair(out, count, indent + 1, "items", items)
    elif node.spec == `leaf`:
        var type_stmt = _child_construct(node, `type`)
        if type_stmt:
            _append_type_schema_pairs(
                module, out, count, type_stmt.value()[], indent + 1
            )
        else:
            _append_pair(out, count, indent + 1, "type", _q("string"))
        _append_description(out, count, node, indent + 1)
        var xyang_type = String("leaf")
        if type_stmt and type_stmt.value()[].has_argument():
            var tn = type_stmt.value()[].argument_text()
            if (
                tn == "leafref"
                or tn == "identityref"
                or tn == "instance-identifier"
                or tn == "bits"
            ):
                xyang_type = tn
        _append_pair(
            out,
            count,
            indent + 1,
            "x-yang",
            _emit_x_yang(node, xyang_type, indent + 1),
        )
        _append_schema_defaults(node, out, count, indent + 1)
    elif node.spec == `leaf-list`:
        _append_pair(out, count, indent + 1, "type", _q("array"))
        var min_items = _child_arg(node, `min-elements`)
        if min_items:
            _append_pair(out, count, indent + 1, "minItems", min_items.value())
        var max_items = _child_arg(node, `max-elements`)
        if max_items:
            _append_pair(out, count, indent + 1, "maxItems", max_items.value())
        _append_description(out, count, node, indent + 1)
        _append_pair(
            out,
            count,
            indent + 1,
            "x-yang",
            _emit_x_yang(node, "leaf-list", indent + 1),
        )
        var type_stmt = _child_construct(node, `type`)
        if type_stmt:
            _append_pair(
                out,
                count,
                indent + 1,
                "items",
                _emit_type_only_schema(module, type_stmt.value()[], indent + 1),
            )
        else:
            _append_pair(out, count, indent + 1, "items", '{"type": "string"}')
    elif node.spec == `choice`:
        _append_pair(
            out,
            count,
            indent + 1,
            "oneOf",
            _emit_choice_cases(module, node, indent + 1),
        )
        _append_description(out, count, node, indent + 1)
        _append_pair(
            out,
            count,
            indent + 1,
            "x-yang",
            _emit_x_yang(node, "choice", indent + 1),
        )
    elif node.spec == `anydata` or node.spec == `anyxml`:
        _append_description(out, count, node, indent + 1)
        _append_pair(
            out,
            count,
            indent + 1,
            "x-yang",
            _emit_x_yang(node, keyword_spelling(node.spec), indent + 1),
        )
    out += "\n" + _indent(indent) + "}"
    return out^


def _emit_choice_cases(
    read module: YangModule, read node: YangConstruct, indent: Int
) -> String:
    from xyang.yang.spec import `case`

    var out = "[\n"
    var count = 0
    for child in node.children:
        if child[].spec != `case`:
            continue
        if count > 0:
            out += ",\n"
        out += _indent(indent + 1) + "{\n"
        var branch_count = 0
        _append_pair(
            out,
            branch_count,
            indent + 2,
            "x-yang",
            '{"name": ' + _q(child[].argument_text()) + "}",
        )
        _append_child_properties(module, out, branch_count, child[], indent + 2)
        _append_required(child[], out, branch_count, indent + 2)
        out += "\n" + _indent(indent + 1) + "}"
        count += 1
    out += "\n" + _indent(indent) + "]"
    return out^


def _emit_typedef_schema(
    read module: YangModule, read node: YangConstruct, indent: Int
) -> String:
    from xyang.yang.spec import `type`

    var out = _indent(indent) + "{\n"
    var count = 0
    var type_stmt = _child_construct(node, `type`)
    if type_stmt:
        _append_type_schema_pairs(
            module, out, count, type_stmt.value()[], indent + 1
        )
    else:
        _append_pair(out, count, indent + 1, "type", _q("string"))
    _append_description(out, count, node, indent + 1)
    _append_schema_defaults(node, out, count, indent + 1)
    _append_pair(
        out,
        count,
        indent + 1,
        "x-yang",
        _emit_x_yang(node, "typedef", indent + 1),
    )
    out += "\n" + _indent(indent) + "}"
    return out^


def _append_defs(
    read module: YangModule, mut out: String, mut count: Int, indent: Int
) raises:
    var defs = "{\n"
    var def_count = 0
    for name in module.typedefs.keys():
        if def_count > 0:
            defs += ",\n"
        var local = name.copy()
        defs += _indent(indent + 1) + _q(local) + ": "
        defs += _emit_typedef_schema(
            module, module.typedefs[local][], indent + 1
        )
        def_count += 1
    defs += "\n" + _indent(indent) + "}"
    if def_count > 0:
        _append_pair(out, count, indent, "$defs", defs)


def yang_module_to_json_schema(read module: YangModule) raises -> String:
    from xyang.yang.spec import `description`

    var parsed_root = module.root_construct()
    var expanded_root = expand_uses_throughout_module(module)
    var out = "{\n"
    var count = 0
    _append_pair(
        out,
        count,
        1,
        "$schema",
        _q("https://json-schema.org/draft/2020-12/schema"),
    )
    var ns = module.get_namespace()
    if ns.byte_length() > 0:
        _append_pair(out, count, 1, "$id", _q(ns))
    var desc = _child_arg(parsed_root[], `description`)
    if desc:
        _append_pair(out, count, 1, "description", _q(desc.value()))

    var xy = "{\n"
    var xy_count = 0
    _append_pair(xy, xy_count, 2, "module", _q(module.get_name()))
    var yang_version = module.get_yang_version()
    if yang_version:
        _append_pair(xy, xy_count, 2, "yang-version", _q(yang_version.value()))
    _append_pair(xy, xy_count, 2, "namespace", _q(module.get_namespace()))
    _append_pair(xy, xy_count, 2, "prefix", _q(module.get_prefix()))
    var org = module.get_organization()
    if org:
        _append_pair(xy, xy_count, 2, "organization", _q(org.value()))
    var contact_text = module.get_contact()
    if contact_text:
        _append_pair(xy, xy_count, 2, "contact", _q(contact_text.value()))
    xy += "\n  }"
    _append_pair(out, count, 1, "x-yang", xy)

    _append_pair(out, count, 1, "type", _q("object"))
    _append_child_properties(module, out, count, expanded_root, 1)
    _append_required(expanded_root, out, count, 1)
    _append_defs(module, out, count, 1)
    out += "\n}\n"
    return out^
