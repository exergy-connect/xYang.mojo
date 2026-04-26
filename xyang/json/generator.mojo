## JSON Schema generator from the Mojo ast.YangModule AST (shape aligned with Python xYang).

from emberjson import Object, Array, Value, write_pretty
from std.collections import Dict
from std.memory import ArcPointer
import xyang.ast as ast
import xyang.json.schema_keys as schema_keys
import xyang.yang.parser.yang_token as yang_token

comptime Arc = ArcPointer


def _must_entry(read m: ast.YangMust) raises -> Object:
    var o = Object()
    o[schema_keys.XYANG_MUST_EXPR] = Value(m.expression)
    o[schema_keys.XYANG_ERROR_MESSAGE] = Value(m.error_message)
    o[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(m.description)
    return o^


def _must_array_from_arc_list(read stmts: List[Arc[ast.YangMust]]) raises -> Array:
    var arr = Array()
    for ref m in stmts:
        arr.append(Value(_must_entry(m[])))
    return arr^


def _when_object(read w: ast.YangWhen) raises -> Object:
    var o = Object()
    o[schema_keys.XYANG_WHEN_CONDITION] = Value(w.expression)
    if len(w.description) > 0:
        o[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(w.description)
    return o^


def _leaf_xyang(read leaf: ast.YangLeaf) raises -> Object:
    var xy = Object()
    if leaf.type.name == yang_token.YANG_TYPE_LEAFREF:
        xy[schema_keys.XYANG_TYPE] = Value(yang_token.YANG_TYPE_LEAFREF)
        xy[schema_keys.XYANG_PATH] = Value(leaf.type.leafref_path())
        xy[schema_keys.XYANG_REQUIRE_INSTANCE] = Value(leaf.type.leafref_require_instance())
    else:
        xy[schema_keys.XYANG_TYPE] = Value("leaf")
    if len(leaf.must.must_statements) > 0:
        var arr = _must_array_from_arc_list(leaf.must.must_statements)
        xy[schema_keys.XYANG_MUST] = Value(arr^)
    if leaf.has_when():
        ref w = leaf.when.value()
        xy[schema_keys.XYANG_WHEN] = Value(_when_object(w))
    if leaf.mandatory:
        xy[schema_keys.XYANG_MANDATORY] = Value(True)
    return xy^


def _open_json_instance_type_array() raises -> Array:
    ## RFC 7950 anydata/anyxml: unconstrained JSON instance (Python `_ANY_JSON_INSTANCE_SCHEMA`).
    var t = Array()
    t.append(Value(schema_keys.JSON_SCHEMA_TYPE_ARRAY))
    t.append(Value(schema_keys.JSON_SCHEMA_TYPE_BOOLEAN))
    t.append(Value(schema_keys.JSON_SCHEMA_TYPE_INTEGER))
    t.append(Value(schema_keys.JSON_SCHEMA_TYPE_NULL))
    t.append(Value(schema_keys.JSON_SCHEMA_TYPE_NUMBER))
    t.append(Value(schema_keys.JSON_SCHEMA_TYPE_OBJECT))
    t.append(Value(schema_keys.JSON_SCHEMA_TYPE_STRING))
    return t^


def _anydata_xyang(read a: ast.YangAnydata) raises -> Object:
    var xy = Object()
    xy[schema_keys.XYANG_TYPE] = Value("anydata")
    if len(a.must.must_statements) > 0:
        var arr = _must_array_from_arc_list(a.must.must_statements)
        xy[schema_keys.XYANG_MUST] = Value(arr^)
    if a.has_when():
        ref w = a.when.value()
        xy[schema_keys.XYANG_WHEN] = Value(_when_object(w))
    if a.mandatory:
        xy[schema_keys.XYANG_MANDATORY] = Value(True)
    return xy^


def _anyxml_xyang(read x: ast.YangAnyxml) raises -> Object:
    var xy = Object()
    xy[schema_keys.XYANG_TYPE] = Value("anyxml")
    if len(x.must.must_statements) > 0:
        var arr = _must_array_from_arc_list(x.must.must_statements)
        xy[schema_keys.XYANG_MUST] = Value(arr^)
    if x.has_when():
        ref w = x.when.value()
        xy[schema_keys.XYANG_WHEN] = Value(_when_object(w))
    if x.mandatory:
        xy[schema_keys.XYANG_MANDATORY] = Value(True)
    return xy^


def _anydata_property(read a: ast.YangAnydata) raises -> Object:
    var out = Object()
    out[schema_keys.JSON_SCHEMA_TYPE] = Value(_open_json_instance_type_array())
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(a.description)
    out[schema_keys.JSON_SCHEMA_X_YANG] = Value(_anydata_xyang(a))
    return out^


def _anyxml_property(read x: ast.YangAnyxml) raises -> Object:
    var out = Object()
    out[schema_keys.JSON_SCHEMA_TYPE] = Value(_open_json_instance_type_array())
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(x.description)
    out[schema_keys.JSON_SCHEMA_X_YANG] = Value(_anyxml_xyang(x))
    return out^


def _leaf_list_xyang(read ll: ast.YangLeafList) raises -> Object:
    var xy = Object()
    xy[schema_keys.XYANG_TYPE] = Value(yang_token.YANG_STMT_LEAF_LIST)
    if len(ll.must.must_statements) > 0:
        var arr = _must_array_from_arc_list(ll.must.must_statements)
        xy[schema_keys.XYANG_MUST] = Value(arr^)
    if ll.has_when():
        ref w = ll.when.value()
        xy[schema_keys.XYANG_WHEN] = Value(_when_object(w))
    if len(ll.ordered_by) > 0:
        xy[schema_keys.XYANG_ORDERED_BY] = Value(ll.ordered_by)
    return xy^


def _json_schema_pattern_from_yang_str(read p: String) -> String:
    ## RFC 7950 patterns are XSD regexes; align with Python xYang by anchoring
    ## as full JSON Schema pattern when the model is not already anchored.
    if len(p) == 0:
        return p
    if p.startswith("^") and p.endswith("$"):
        return p
    return "^" + p + "$"


def _type_schema(
    read t: ast.YangType,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
    use_typedef_refs: Bool = True,
) raises -> Object:
    var tn = t.name
    if use_typedef_refs and tn in typedefs:
        var ro = Object()
        ro[schema_keys.JSON_SCHEMA_REF] = Value(schema_keys.json_schema_defs_uri(tn))
        return ro^
    if tn == yang_token.YANG_TYPE_LEAFREF:
        var o = Object()
        o[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
        var lr_xy = Object()
        lr_xy[schema_keys.XYANG_TYPE] = Value(yang_token.YANG_TYPE_LEAFREF)
        lr_xy[schema_keys.XYANG_PATH] = Value(t.leafref_path())
        lr_xy[schema_keys.XYANG_REQUIRE_INSTANCE] = Value(t.leafref_require_instance())
        o[schema_keys.JSON_SCHEMA_X_YANG] = Value(lr_xy^)
        return o^
    if tn == "boolean":
        var b = Object()
        b[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_BOOLEAN)
        return b^
    if tn == "empty":
        var e = Object()
        e[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_OBJECT)
        e[schema_keys.JSON_SCHEMA_MAX_PROPERTIES] = Value(0)
        return e^
    if tn == "int8" or tn == "int16" or tn == "int32" or tn == "int64" or tn.startswith(
        "uint"
    ):
        var o = Object()
        o[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_INTEGER)
        if t.has_range():
            o[schema_keys.JSON_SCHEMA_MINIMUM] = Value(Int64(t.range_min()))
            o[schema_keys.JSON_SCHEMA_MAXIMUM] = Value(Int64(t.range_max()))
        elif tn == "uint8":
            o[schema_keys.JSON_SCHEMA_MINIMUM] = Value(Int64(0))
            o[schema_keys.JSON_SCHEMA_MAXIMUM] = Value(Int64(255))
        return o^
    if tn == "enumeration":
        var o = Object()
        o[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
        if t.enum_values_len() > 0:
            var e = Array()
            for i in range(t.enum_values_len()):
                e.append(Value(t.enum_value_at(i)))
            o[schema_keys.JSON_SCHEMA_ENUM] = Value(e^)
        return o^
    if tn == yang_token.YANG_STMT_UNION:
        var o = Object()
        var branches = Array()
        for i in range(t.union_members_len()):
            branches.append(
                Value(
                    _type_schema(
                        t.union_member_arc(i)[],
                        typedefs,
                        use_typedef_refs,
                    )
                )
            )
        o[schema_keys.JSON_SCHEMA_ONE_OF] = Value(branches^)
        return o^
    if tn == "decimal64":
        var o = Object()
        o[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_NUMBER)
        if t.fraction_digits() > 0:
            var step = Float64(1.0)
            for _i in range(t.fraction_digits()):
                step = step * Float64(0.1)
            o[schema_keys.JSON_SCHEMA_MULTIPLE_OF] = Value(step)
        if t.has_decimal64_range():
            o[schema_keys.JSON_SCHEMA_MINIMUM] = Value(t.decimal64_range_min())
            o[schema_keys.JSON_SCHEMA_MAXIMUM] = Value(t.decimal64_range_max())
        var xy = Object()
        xy[schema_keys.XYANG_TYPE] = Value("decimal64")
        if t.fraction_digits() > 0:
            xy[schema_keys.XYANG_FRACTION_DIGITS] = Value(Int64(t.fraction_digits()))
        o[schema_keys.JSON_SCHEMA_X_YANG] = Value(xy^)
        return o^
    if tn == "bits":
        var o = Object()
        o[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
        var xy = Object()
        xy[schema_keys.XYANG_TYPE] = Value("bits")
        if t.bits_names_len() > 0:
            var ba = Array()
            for i in range(t.bits_names_len()):
                ba.append(Value(t.bits_name_at(i)))
            xy[schema_keys.XYANG_BITS] = Value(ba^)
        o[schema_keys.JSON_SCHEMA_X_YANG] = Value(xy^)
        return o^
    if tn == "identityref":
        var o = Object()
        o[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
        var xy = Object()
        xy[schema_keys.XYANG_TYPE] = Value("identityref")
        if len(t.identityref_base()) > 0:
            xy[schema_keys.XYANG_BASE] = Value(t.identityref_base())
        o[schema_keys.JSON_SCHEMA_X_YANG] = Value(xy^)
        return o^
    if tn == "string":
        var st = Object()
        st[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
        if t.has_string_pattern():
            st[schema_keys.JSON_SCHEMA_PATTERN] = Value(
                _json_schema_pattern_from_yang_str(t.string_pattern())
            )
        return st^
    var s = Object()
    s[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
    return s^


def _default_json_value(default_text: String, type_name: String) raises -> Optional[Value]:
    if len(default_text) == 0:
        return Optional[Value]()
    if (
        type_name == "int8"
        or type_name == "int16"
        or type_name == "int32"
        or type_name == "int64"
        or type_name == "uint8"
        or type_name == "uint16"
        or type_name == "uint32"
        or type_name == "uint64"
        or type_name == "integer"
    ):
        try:
            return Optional(Value(Int64(atol(default_text.strip()))))
        except:
            return Optional[Value]()
    return Optional(Value(default_text))


def _default_json_value_for_type(
    default_text: String,
    read type_stmt: ast.YangType,
) raises -> Optional[Value]:
    if type_stmt.name == yang_token.YANG_STMT_UNION:
        for i in range(type_stmt.union_members_len()):
            var dv = _default_json_value(default_text, type_stmt.union_member_arc(i)[].name)
            if dv:
                return dv^
        return Optional(Value(default_text))
    return _default_json_value(default_text, type_stmt.name)


def _leaf_property(
    read leaf: ast.YangLeaf,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
) raises -> Object:
    var out: Object
    if leaf.type.name == yang_token.YANG_TYPE_LEAFREF:
        out = Object()
        out[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
    else:
        out = _type_schema(leaf.type, typedefs)
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(leaf.description)
    out[schema_keys.JSON_SCHEMA_X_YANG] = Value(_leaf_xyang(leaf))
    if leaf.has_default:
        var dv = _default_json_value_for_type(leaf.default_value, leaf.type)
        if dv:
            out[schema_keys.JSON_SCHEMA_DEFAULT] = dv.value().copy()
    return out^


def _leaf_list_items_schema(
    read ll: ast.YangLeafList,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
) raises -> Object:
    var type_name = ll.type.name
    if type_name == yang_token.YANG_TYPE_LEAFREF:
        var items = Object()
        items[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
        var lr_xy = Object()
        lr_xy[schema_keys.XYANG_TYPE] = Value(yang_token.YANG_TYPE_LEAFREF)
        lr_xy[schema_keys.XYANG_PATH] = Value(ll.type.leafref_path())
        lr_xy[schema_keys.XYANG_REQUIRE_INSTANCE] = Value(ll.type.leafref_require_instance())
        items[schema_keys.JSON_SCHEMA_X_YANG] = Value(lr_xy^)
        return items^
    return _type_schema(ll.type, typedefs)


def _leaf_list_property(
    read ll: ast.YangLeafList,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
) raises -> Object:
    var out = Object()
    out[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_ARRAY)
    out[schema_keys.JSON_SCHEMA_ITEMS] = Value(_leaf_list_items_schema(ll, typedefs))
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(ll.description)
    out[schema_keys.JSON_SCHEMA_X_YANG] = Value(_leaf_list_xyang(ll))
    if ll.min_elements >= 0:
        out[schema_keys.JSON_SCHEMA_MIN_ITEMS] = Value(ll.min_elements)
    if ll.max_elements >= 0:
        out[schema_keys.JSON_SCHEMA_MAX_ITEMS] = Value(ll.max_elements)
    if len(ll.default_values) > 0:
        var darr = Array()
        for dtext in ll.default_values:
            var dv = _default_json_value_for_type(dtext, ll.type)
            if dv:
                darr.append(dv.value().copy())
        if len(darr) > 0:
            out[schema_keys.JSON_SCHEMA_DEFAULT] = Value(darr^)
    return out^


def _stub_leaf_property() raises -> Object:
    var xy = Object()
    xy[schema_keys.XYANG_TYPE] = Value("leaf")
    var o = Object()
    o[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
    o[schema_keys.JSON_SCHEMA_X_YANG] = Value(xy^)
    return o^


def _find_named_property(
    name: String,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
    read leaves: List[Arc[ast.YangLeaf]],
    read leaf_lists: List[Arc[ast.YangLeafList]],
    read anydatas: List[Arc[ast.YangAnydata]],
    read anyxmls: List[Arc[ast.YangAnyxml]],
    read containers: List[Arc[ast.YangContainer]],
    read lists: List[Arc[ast.YangList]],
) raises -> Object:
    for ref lf in leaves:
        if lf[].name == name:
            return _leaf_property(lf[], typedefs)
    for ref llist in leaf_lists:
        if llist[].name == name:
            return _leaf_list_property(llist[], typedefs)
    for ref ad in anydatas:
        if ad[].name == name:
            return _anydata_property(ad[])
    for ref ax in anyxmls:
        if ax[].name == name:
            return _anyxml_property(ax[])
    for ref co in containers:
        if co[].name == name:
            return _container_property(co[], typedefs)
    for ref li in lists:
        if li[].name == name:
            return _list_property(li[], typedefs)
    return _stub_leaf_property()


def _choice_property(
    read choice: ast.YangChoice,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
    read leaves: List[Arc[ast.YangLeaf]],
    read leaf_lists: List[Arc[ast.YangLeafList]],
    read anydatas: List[Arc[ast.YangAnydata]],
    read anyxmls: List[Arc[ast.YangAnyxml]],
    read containers: List[Arc[ast.YangContainer]],
    read lists: List[Arc[ast.YangList]],
) raises -> Object:
    var out = Object()
    out[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_OBJECT)
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(choice.description)

    var xy = Object()
    xy[schema_keys.XYANG_TYPE] = Value("choice")
    xy[schema_keys.XYANG_MANDATORY] = Value(choice.mandatory)
    if len(choice.default_case) > 0:
        xy[schema_keys.XYANG_DEFAULT] = Value(choice.default_case)
    if choice.has_when():
        ref w = choice.when.value()
        xy[schema_keys.XYANG_WHEN] = Value(_when_object(w))
    out[schema_keys.JSON_SCHEMA_X_YANG] = Value(xy^)

    var branches = Array()
    var n_cases = len(choice.cases)
    if not choice.mandatory and n_cases > 1:
        var empty = Object()
        empty[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_OBJECT)
        empty[schema_keys.JSON_SCHEMA_MAX_PROPERTIES] = Value(0)
        branches.append(Value(empty^))

    for i in range(n_cases):
        ref case_node = choice.cases[i][]
        var props = Object()
        var req = Array()
        for nm in case_node.node_names:
            props[nm] = Value(
                _find_named_property(
                    nm,
                    typedefs,
                    leaves,
                    leaf_lists,
                    anydatas,
                    anyxmls,
                    containers,
                    lists,
                )
            )
            req.append(Value(nm))
        var branch = Object()
        branch[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_OBJECT)
        branch[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(case_node.description)
        branch[schema_keys.JSON_SCHEMA_PROPERTIES] = Value(props^)
        branch[schema_keys.JSON_SCHEMA_ADDITIONAL_PROPERTIES] = Value(False)
        branch[schema_keys.JSON_SCHEMA_REQUIRED] = Value(req^)
        var case_xy = Object()
        case_xy[schema_keys.JSON_SCHEMA_NAME] = Value(case_node.name)
        if case_node.has_when():
            ref cw = case_node.when.value()
            case_xy[schema_keys.XYANG_WHEN] = Value(_when_object(cw))
        branch[schema_keys.JSON_SCHEMA_X_YANG] = Value(case_xy^)
        branches.append(Value(branch^))

    out[schema_keys.JSON_SCHEMA_ONE_OF] = Value(branches^)
    return out^


def _container_property(
    read c: ast.YangContainer,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
) raises -> Object:
    var props = Object()
    var req = Array()

    for ref lf_arc in c.leaves:
        ref lf = lf_arc[]
        props[lf.name] = Value(_leaf_property(lf, typedefs))
        if lf.mandatory:
            req.append(Value(lf.name))
    for ref ll_arc in c.leaf_lists:
        ref ll = ll_arc[]
        props[ll.name] = Value(_leaf_list_property(ll, typedefs))
    for ref ad_arc in c.anydatas:
        ref ad = ad_arc[]
        props[ad.name] = Value(_anydata_property(ad))
        if ad.mandatory:
            req.append(Value(ad.name))
    for ref ax_arc in c.anyxmls:
        ref ax = ax_arc[]
        props[ax.name] = Value(_anyxml_property(ax))
        if ax.mandatory:
            req.append(Value(ax.name))
    for ref ch_arc in c.containers:
        ref ch = ch_arc[]
        props[ch.name] = Value(_container_property(ch, typedefs))
    for ref lst_arc in c.lists:
        ref lst = lst_arc[]
        props[lst.name] = Value(_list_property(lst, typedefs))
    for ref ch_arc2 in c.choices:
        ref ch = ch_arc2[]
        props[ch.name] = Value(
            _choice_property(
                ch,
                typedefs,
                c.leaves,
                c.leaf_lists,
                c.anydatas,
                c.anyxmls,
                c.containers,
                c.lists,
            )
        )

    var xy = Object()
    xy[schema_keys.XYANG_TYPE] = Value("container")
    if len(c.must.must_statements) > 0:
        var must_arr = _must_array_from_arc_list(c.must.must_statements)
        xy[schema_keys.XYANG_MUST] = Value(must_arr^)
    var out = Object()
    out[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_OBJECT)
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(c.description)
    out[schema_keys.JSON_SCHEMA_X_YANG] = Value(xy^)
    if len(props) > 0:
        out[schema_keys.JSON_SCHEMA_PROPERTIES] = Value(props^)
    out[schema_keys.JSON_SCHEMA_ADDITIONAL_PROPERTIES] = Value(False)
    if len(req) > 0:
        out[schema_keys.JSON_SCHEMA_REQUIRED] = Value(req^)
    return out^


def _list_items_schema(
    read lst: ast.YangList,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
) raises -> Object:
    var b = ast.decompose_yang_list_children(lst.children)
    var props = Object()
    var req = Array()
    for ref lf_arc in b.leaves:
        ref lf = lf_arc[]
        props[lf.name] = Value(_leaf_property(lf, typedefs))
        if lf.mandatory:
            req.append(Value(lf.name))
    for ref ll_arc in b.leaf_lists:
        ref ll = ll_arc[]
        props[ll.name] = Value(_leaf_list_property(ll, typedefs))
    for ref ad_arc in b.anydatas:
        ref ad = ad_arc[]
        props[ad.name] = Value(_anydata_property(ad))
        if ad.mandatory:
            req.append(Value(ad.name))
    for ref ax_arc in b.anyxmls:
        ref ax = ax_arc[]
        props[ax.name] = Value(_anyxml_property(ax))
        if ax.mandatory:
            req.append(Value(ax.name))
    for ref ch_arc in b.containers:
        ref ch = ch_arc[]
        props[ch.name] = Value(_container_property(ch, typedefs))
    for ref inner_arc in b.lists:
        ref inner = inner_arc[]
        props[inner.name] = Value(_list_property(inner, typedefs))
    for ref ch_arc2 in b.choices:
        ref ch = ch_arc2[]
        props[ch.name] = Value(
            _choice_property(
                ch,
                typedefs,
                b.leaves,
                b.leaf_lists,
                b.anydatas,
                b.anyxmls,
                b.containers,
                b.lists,
            )
        )

    var items = Object()
    items[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_OBJECT)
    if len(props) > 0:
        items[schema_keys.JSON_SCHEMA_PROPERTIES] = Value(props^)
    items[schema_keys.JSON_SCHEMA_ADDITIONAL_PROPERTIES] = Value(False)
    if len(req) > 0:
        items[schema_keys.JSON_SCHEMA_REQUIRED] = Value(req^)
    return items^


def _list_property(
    read lst: ast.YangList,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
) raises -> Object:
    var xy = Object()
    xy[schema_keys.XYANG_TYPE] = Value("list")
    xy[schema_keys.XYANG_KEY] = Value(lst.key)
    if len(lst.must.must_statements) > 0:
        var must_arr = _must_array_from_arc_list(lst.must.must_statements)
        xy[schema_keys.XYANG_MUST] = Value(must_arr^)
    if len(lst.ordered_by) > 0:
        xy[schema_keys.XYANG_ORDERED_BY] = Value(lst.ordered_by)
    if len(lst.unique_specs) > 0:
        var uarr = Array()
        for spec in lst.unique_specs:
            var inner = Array()
            for s in spec:
                inner.append(Value(s))
            uarr.append(Value(inner^))
        xy[schema_keys.XYANG_UNIQUE] = Value(uarr^)
    var out = Object()
    out[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_ARRAY)
    out[schema_keys.JSON_SCHEMA_ITEMS] = Value(_list_items_schema(lst, typedefs))
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(lst.description)
    out[schema_keys.JSON_SCHEMA_X_YANG] = Value(xy^)
    if lst.min_elements >= 0:
        out[schema_keys.JSON_SCHEMA_MIN_ITEMS] = Value(lst.min_elements)
    if lst.max_elements >= 0:
        out[schema_keys.JSON_SCHEMA_MAX_ITEMS] = Value(lst.max_elements)
    return out^


def _typedef_def_object(read td: ast.YangTypedefStmt) raises -> Object:
    var out = _type_schema(
        td.type_stmt,
        Dict[String, Arc[ast.YangTypedefStmt]](),
        use_typedef_refs=False,
    )
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(td.description)
    return out^


def _identity_def_object(read ident: ast.YangIdentityStmt) raises -> Object:
    var out = Object()
    out[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_STRING)
    out[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(ident.description)
    var xy = Object()
    xy[schema_keys.XYANG_TYPE] = Value(yang_token.YANG_STMT_IDENTITY)
    if len(ident.bases) > 0:
        var bases = Array()
        for b in ident.bases:
            bases.append(Value(b))
        xy[schema_keys.XYANG_BASES] = Value(bases^)
    if len(ident.if_features) > 0:
        var ff = Array()
        for f in ident.if_features:
            ff.append(Value(f))
        xy[schema_keys.XYANG_IF_FEATURES] = Value(ff^)
    out[schema_keys.JSON_SCHEMA_X_YANG] = Value(xy^)
    return out^


def _build_defs(read module: ast.YangModule) raises -> Object:
    var defs = Object()
    for ref pair in module.typedefs.items():
        defs[pair.key] = Value(_typedef_def_object(pair.value[]))
    for ref pair in module.identities.items():
        defs[pair.key] = Value(_identity_def_object(pair.value[]))
    return defs^


def _module_statement_property(
    read stmt: ast.YangModuleStatement,
    read typedefs: Dict[String, Arc[ast.YangTypedefStmt]],
    read leaves: List[Arc[ast.YangLeaf]],
    read leaf_lists: List[Arc[ast.YangLeafList]],
    read anydatas: List[Arc[ast.YangAnydata]],
    read anyxmls: List[Arc[ast.YangAnyxml]],
    read containers: List[Arc[ast.YangContainer]],
    read lists: List[Arc[ast.YangList]],
) raises -> Optional[Object]:
    if stmt.isa[Arc[ast.YangLeaf]]():
        return Optional[Object](_leaf_property(stmt[Arc[ast.YangLeaf]][], typedefs))
    if stmt.isa[Arc[ast.YangLeafList]]():
        return Optional[Object](_leaf_list_property(stmt[Arc[ast.YangLeafList]][], typedefs))
    if stmt.isa[Arc[ast.YangAnydata]]():
        return Optional[Object](_anydata_property(stmt[Arc[ast.YangAnydata]][]))
    if stmt.isa[Arc[ast.YangAnyxml]]():
        return Optional[Object](_anyxml_property(stmt[Arc[ast.YangAnyxml]][]))
    if stmt.isa[Arc[ast.YangContainer]]():
        return Optional[Object](_container_property(stmt[Arc[ast.YangContainer]][], typedefs))
    if stmt.isa[Arc[ast.YangList]]():
        return Optional[Object](_list_property(stmt[Arc[ast.YangList]][], typedefs))
    if stmt.isa[Arc[ast.YangChoice]]():
        return Optional[Object](
            _choice_property(
                stmt[Arc[ast.YangChoice]][],
                typedefs,
                leaves,
                leaf_lists,
                anydatas,
                anyxmls,
                containers,
                lists,
            )
        )
    return Optional[Object]()


def generate_json_schema(read module: ast.YangModule) raises -> Value:
    var root_xy = Object()
    root_xy[schema_keys.XYANG_MODULE] = Value(module.name)
    root_xy[schema_keys.XYANG_YANG_VERSION] = Value(module.yang_version)
    root_xy[schema_keys.XYANG_NAMESPACE] = Value(module.namespace)
    root_xy[schema_keys.XYANG_PREFIX] = Value(module.prefix)
    root_xy[schema_keys.XYANG_ORGANIZATION] = Value(module.organization)
    root_xy[schema_keys.XYANG_CONTACT] = Value(module.contact)

    var module_leaves = List[Arc[ast.YangLeaf]]()
    var module_leaf_lists = List[Arc[ast.YangLeafList]]()
    var module_anydatas = List[Arc[ast.YangAnydata]]()
    var module_anyxmls = List[Arc[ast.YangAnyxml]]()
    var module_containers = List[Arc[ast.YangContainer]]()
    var module_lists = List[Arc[ast.YangList]]()

    for stmt in module.statements:
        if stmt.isa[Arc[ast.YangLeaf]]():
            module_leaves.append(stmt[Arc[ast.YangLeaf]])
        elif stmt.isa[Arc[ast.YangLeafList]]():
            module_leaf_lists.append(stmt[Arc[ast.YangLeafList]])
        elif stmt.isa[Arc[ast.YangAnydata]]():
            module_anydatas.append(stmt[Arc[ast.YangAnydata]])
        elif stmt.isa[Arc[ast.YangAnyxml]]():
            module_anyxmls.append(stmt[Arc[ast.YangAnyxml]])
        elif stmt.isa[Arc[ast.YangContainer]]():
            module_containers.append(stmt[Arc[ast.YangContainer]])
        elif stmt.isa[Arc[ast.YangList]]():
            module_lists.append(stmt[Arc[ast.YangList]])

    var props = Object()
    for stmt in module.statements:
        var prop = _module_statement_property(
            stmt,
            module.typedefs,
            module_leaves,
            module_leaf_lists,
            module_anydatas,
            module_anyxmls,
            module_containers,
            module_lists,
        )
        if prop:
            var name = ""
            if stmt.isa[Arc[ast.YangLeaf]]():
                name = stmt[Arc[ast.YangLeaf]][].name
            elif stmt.isa[Arc[ast.YangLeafList]]():
                name = stmt[Arc[ast.YangLeafList]][].name
            elif stmt.isa[Arc[ast.YangAnydata]]():
                name = stmt[Arc[ast.YangAnydata]][].name
            elif stmt.isa[Arc[ast.YangAnyxml]]():
                name = stmt[Arc[ast.YangAnyxml]][].name
            elif stmt.isa[Arc[ast.YangContainer]]():
                name = stmt[Arc[ast.YangContainer]][].name
            elif stmt.isa[Arc[ast.YangList]]():
                name = stmt[Arc[ast.YangList]][].name
            elif stmt.isa[Arc[ast.YangChoice]]():
                name = stmt[Arc[ast.YangChoice]][].name
            if len(name) > 0:
                props[name] = Value(prop.take())

    var root = Object()
    root[schema_keys.JSON_SCHEMA_SCHEMA] = Value(schema_keys.JSON_SCHEMA_DRAFT_2020_12)
    var mod_id = module.namespace
    if len(mod_id) == 0:
        mod_id = "urn:" + module.name
    root[schema_keys.JSON_SCHEMA_ID] = Value(mod_id)
    root[schema_keys.JSON_SCHEMA_DESCRIPTION] = Value(module.description)
    root[schema_keys.JSON_SCHEMA_X_YANG] = Value(root_xy^)
    root[schema_keys.JSON_SCHEMA_TYPE] = Value(schema_keys.JSON_SCHEMA_TYPE_OBJECT)
    root[schema_keys.JSON_SCHEMA_PROPERTIES] = Value(props^)
    root[schema_keys.JSON_SCHEMA_ADDITIONAL_PROPERTIES] = Value(False)
    var defs = _build_defs(module)
    if len(defs) > 0:
        root[schema_keys.JSON_SCHEMA_DEFS] = Value(defs^)
    return Value(root^)


def schema_to_yang_json(read module: ast.YangModule, indent: Int = 2) raises -> String:
    var root = generate_json_schema(module)
    return write_pretty(root, indent) + "\n"
