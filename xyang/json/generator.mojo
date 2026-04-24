## JSON Schema generator from the Mojo YangModule AST (shape aligned with Python xYang).

from emberjson import Object, Array, Value, write_pretty
from std.memory import ArcPointer
from xyang.ast import (
    YangModule,
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangLeafList,
    YangAnydata,
    YangAnyxml,
    YangType,
    YangMust,
    YangWhen,
)
from xyang.json.schema_keys import (
    JSON_SCHEMA_ADDITIONAL_PROPERTIES,
    JSON_SCHEMA_DEFAULT,
    JSON_SCHEMA_DESCRIPTION,
    JSON_SCHEMA_ENUM,
    JSON_SCHEMA_ID,
    JSON_SCHEMA_ITEMS,
    JSON_SCHEMA_MAXIMUM,
    JSON_SCHEMA_MAX_PROPERTIES,
    JSON_SCHEMA_MINIMUM,
    JSON_SCHEMA_MULTIPLE_OF,
    JSON_SCHEMA_MIN_ITEMS,
    JSON_SCHEMA_MAX_ITEMS,
    JSON_SCHEMA_NAME,
    JSON_SCHEMA_ONE_OF,
    JSON_SCHEMA_PROPERTIES,
    JSON_SCHEMA_REQUIRED,
    JSON_SCHEMA_SCHEMA,
    JSON_SCHEMA_TYPE,
    JSON_SCHEMA_X_YANG,
    JSON_SCHEMA_DRAFT_2020_12,
    XYANG_CONTACT,
    XYANG_DEFAULT,
    XYANG_ORDERED_BY,
    XYANG_UNIQUE,
    XYANG_ERROR_MESSAGE,
    XYANG_KEY,
    XYANG_MANDATORY,
    XYANG_MODULE,
    XYANG_MUST,
    XYANG_MUST_EXPR,
    XYANG_NAMESPACE,
    XYANG_ORGANIZATION,
    XYANG_PREFIX,
    XYANG_FRACTION_DIGITS,
    XYANG_BASE,
    XYANG_BITS,
    XYANG_REQUIRE_INSTANCE,
    XYANG_TYPE,
    XYANG_PATH,
    XYANG_WHEN,
    XYANG_WHEN_CONDITION,
    XYANG_YANG_VERSION,
)
from xyang.yang.tokens import YANG_TYPE_LEAFREF, YANG_STMT_LEAF_LIST, YANG_STMT_UNION

comptime Arc = ArcPointer


def _must_entry(read m: YangMust) raises -> Object:
    var o = Object()
    o[XYANG_MUST_EXPR] = Value(m.expression)
    o[XYANG_ERROR_MESSAGE] = Value(m.error_message)
    o[JSON_SCHEMA_DESCRIPTION] = Value(m.description)
    return o^


def _must_array_from_arc_list(read stmts: List[Arc[YangMust]]) raises -> Array:
    var arr = Array()
    for i in range(len(stmts)):
        arr.append(Value(_must_entry(stmts[i][])))
    return arr^


def _when_object(read w: YangWhen) raises -> Object:
    var o = Object()
    o[XYANG_WHEN_CONDITION] = Value(w.expression)
    if len(w.description) > 0:
        o[JSON_SCHEMA_DESCRIPTION] = Value(w.description)
    return o^


def _leaf_xyang(read leaf: YangLeaf) raises -> Object:
    var xy = Object()
    if leaf.type.name == YANG_TYPE_LEAFREF:
        xy[XYANG_TYPE] = Value(YANG_TYPE_LEAFREF)
        xy[XYANG_PATH] = Value(leaf.type.leafref_path())
        xy[XYANG_REQUIRE_INSTANCE] = Value(leaf.type.leafref_require_instance())
    else:
        xy[XYANG_TYPE] = Value("leaf")
    if len(leaf.must_statements) > 0:
        var arr = _must_array_from_arc_list(leaf.must_statements)
        xy[XYANG_MUST] = Value(arr^)
    if leaf.has_when():
        ref w = leaf.when.value()
        xy[XYANG_WHEN] = Value(_when_object(w))
    if leaf.mandatory:
        xy[XYANG_MANDATORY] = Value(True)
    return xy^


def _open_json_instance_type_array() raises -> Array:
    ## RFC 7950 anydata/anyxml: unconstrained JSON instance (Python `_ANY_JSON_INSTANCE_SCHEMA`).
    var t = Array()
    t.append(Value("array"))
    t.append(Value("boolean"))
    t.append(Value("integer"))
    t.append(Value("null"))
    t.append(Value("number"))
    t.append(Value("object"))
    t.append(Value("string"))
    return t^


def _anydata_xyang(read a: YangAnydata) raises -> Object:
    var xy = Object()
    xy[XYANG_TYPE] = Value("anydata")
    if len(a.must_statements) > 0:
        var arr = _must_array_from_arc_list(a.must_statements)
        xy[XYANG_MUST] = Value(arr^)
    if a.has_when():
        ref w = a.when.value()
        xy[XYANG_WHEN] = Value(_when_object(w))
    if a.mandatory:
        xy[XYANG_MANDATORY] = Value(True)
    return xy^


def _anyxml_xyang(read x: YangAnyxml) raises -> Object:
    var xy = Object()
    xy[XYANG_TYPE] = Value("anyxml")
    if len(x.must_statements) > 0:
        var arr = _must_array_from_arc_list(x.must_statements)
        xy[XYANG_MUST] = Value(arr^)
    if x.has_when():
        ref w = x.when.value()
        xy[XYANG_WHEN] = Value(_when_object(w))
    if x.mandatory:
        xy[XYANG_MANDATORY] = Value(True)
    return xy^


def _anydata_property(read a: YangAnydata) raises -> Object:
    var out = Object()
    out[JSON_SCHEMA_TYPE] = Value(_open_json_instance_type_array())
    out[JSON_SCHEMA_DESCRIPTION] = Value(a.description)
    out[JSON_SCHEMA_X_YANG] = Value(_anydata_xyang(a))
    return out^


def _anyxml_property(read x: YangAnyxml) raises -> Object:
    var out = Object()
    out[JSON_SCHEMA_TYPE] = Value(_open_json_instance_type_array())
    out[JSON_SCHEMA_DESCRIPTION] = Value(x.description)
    out[JSON_SCHEMA_X_YANG] = Value(_anyxml_xyang(x))
    return out^


def _leaf_list_xyang(read ll: YangLeafList) raises -> Object:
    var xy = Object()
    xy[XYANG_TYPE] = Value(YANG_STMT_LEAF_LIST)
    if len(ll.must_statements) > 0:
        var arr = _must_array_from_arc_list(ll.must_statements)
        xy[XYANG_MUST] = Value(arr^)
    if ll.has_when():
        ref w = ll.when.value()
        xy[XYANG_WHEN] = Value(_when_object(w))
    if len(ll.ordered_by) > 0:
        xy[XYANG_ORDERED_BY] = Value(ll.ordered_by)
    return xy^


def _type_schema(read t: YangType) raises -> Object:
    var tn = t.name
    if tn == YANG_TYPE_LEAFREF:
        var o = Object()
        o[JSON_SCHEMA_TYPE] = Value("string")
        var lr_xy = Object()
        lr_xy[XYANG_TYPE] = Value(YANG_TYPE_LEAFREF)
        lr_xy[XYANG_PATH] = Value(t.leafref_path())
        lr_xy[XYANG_REQUIRE_INSTANCE] = Value(t.leafref_require_instance())
        o[JSON_SCHEMA_X_YANG] = Value(lr_xy^)
        return o^
    if tn == "boolean":
        var b = Object()
        b[JSON_SCHEMA_TYPE] = Value("boolean")
        return b^
    if tn == "empty":
        var e = Object()
        e[JSON_SCHEMA_TYPE] = Value("object")
        e[JSON_SCHEMA_MAX_PROPERTIES] = Value(0)
        return e^
    if tn == "int8" or tn == "int16" or tn == "int32" or tn == "int64" or tn.startswith(
        "uint"
    ):
        var o = Object()
        o[JSON_SCHEMA_TYPE] = Value("integer")
        if t.has_range():
            o[JSON_SCHEMA_MINIMUM] = Value(Int64(t.range_min()))
            o[JSON_SCHEMA_MAXIMUM] = Value(Int64(t.range_max()))
        elif tn == "uint8":
            o[JSON_SCHEMA_MINIMUM] = Value(Int64(0))
            o[JSON_SCHEMA_MAXIMUM] = Value(Int64(255))
        return o^
    if tn == "enumeration":
        var o = Object()
        o[JSON_SCHEMA_TYPE] = Value("string")
        if t.enum_values_len() > 0:
            var e = Array()
            for i in range(t.enum_values_len()):
                e.append(Value(t.enum_value_at(i)))
            o[JSON_SCHEMA_ENUM] = Value(e^)
        return o^
    if tn == YANG_STMT_UNION:
        var o = Object()
        var branches = Array()
        for i in range(t.union_members_len()):
            branches.append(Value(_type_schema(t.union_member_arc(i)[])))
        o[JSON_SCHEMA_ONE_OF] = Value(branches^)
        return o^
    if tn == "decimal64":
        var o = Object()
        o[JSON_SCHEMA_TYPE] = Value("number")
        if t.fraction_digits() > 0:
            var step = Float64(1.0)
            for _i in range(t.fraction_digits()):
                step = step * Float64(0.1)
            o[JSON_SCHEMA_MULTIPLE_OF] = Value(step)
        if t.has_decimal64_range():
            o[JSON_SCHEMA_MINIMUM] = Value(t.decimal64_range_min())
            o[JSON_SCHEMA_MAXIMUM] = Value(t.decimal64_range_max())
        var xy = Object()
        xy[XYANG_TYPE] = Value("decimal64")
        if t.fraction_digits() > 0:
            xy[XYANG_FRACTION_DIGITS] = Value(Int64(t.fraction_digits()))
        o[JSON_SCHEMA_X_YANG] = Value(xy^)
        return o^
    if tn == "bits":
        var o = Object()
        o[JSON_SCHEMA_TYPE] = Value("string")
        var xy = Object()
        xy[XYANG_TYPE] = Value("bits")
        if t.bits_names_len() > 0:
            var ba = Array()
            for i in range(t.bits_names_len()):
                ba.append(Value(t.bits_name_at(i)))
            xy[XYANG_BITS] = Value(ba^)
        o[JSON_SCHEMA_X_YANG] = Value(xy^)
        return o^
    if tn == "identityref":
        var o = Object()
        o[JSON_SCHEMA_TYPE] = Value("string")
        var xy = Object()
        xy[XYANG_TYPE] = Value("identityref")
        if len(t.identityref_base()) > 0:
            xy[XYANG_BASE] = Value(t.identityref_base())
        o[JSON_SCHEMA_X_YANG] = Value(xy^)
        return o^
    var s = Object()
    s[JSON_SCHEMA_TYPE] = Value("string")
    return s^


def _default_json_value(default_text: String, type_name: String) raises -> Optional[Value]:
    if len(default_text) == 0:
        return Optional[Value]()
    if type_name == "boolean":
        if default_text == "true":
            return Optional(Value(True))
        if default_text == "false":
            return Optional(Value(False))
        return Optional[Value]()
    if (
        type_name == "int8"
        or type_name == "int16"
        or type_name == "int32"
        or type_name == "int64"
        or type_name.startswith("uint")
    ):
        try:
            return Optional(Value(Int64(atol(default_text))))
        except:
            return Optional[Value]()
    if type_name == "decimal64":
        try:
            return Optional(Value(Float64(atof(default_text))))
        except:
            return Optional[Value]()
    return Optional(Value(default_text))


def _default_json_value_for_type(
    default_text: String,
    read type_stmt: YangType,
) raises -> Optional[Value]:
    if type_stmt.name == YANG_STMT_UNION:
        for i in range(type_stmt.union_members_len()):
            var dv = _default_json_value(default_text, type_stmt.union_member_arc(i)[].name)
            if dv:
                return dv^
        return Optional(Value(default_text))
    return _default_json_value(default_text, type_stmt.name)


def _leaf_property(read leaf: YangLeaf) raises -> Object:
    var out: Object
    if leaf.type.name == YANG_TYPE_LEAFREF:
        out = Object()
        out[JSON_SCHEMA_TYPE] = Value("string")
    else:
        out = _type_schema(leaf.type)
    out[JSON_SCHEMA_DESCRIPTION] = Value("")
    out[JSON_SCHEMA_X_YANG] = Value(_leaf_xyang(leaf))
    if leaf.has_default:
        var dv = _default_json_value_for_type(leaf.default_value, leaf.type)
        if dv:
            out[JSON_SCHEMA_DEFAULT] = dv.value().copy()
    return out^


def _leaf_list_items_schema(read ll: YangLeafList) raises -> Object:
    var type_name = ll.type.name
    if type_name == YANG_TYPE_LEAFREF:
        var items = Object()
        items[JSON_SCHEMA_TYPE] = Value("string")
        var lr_xy = Object()
        lr_xy[XYANG_TYPE] = Value(YANG_TYPE_LEAFREF)
        lr_xy[XYANG_PATH] = Value(ll.type.leafref_path())
        lr_xy[XYANG_REQUIRE_INSTANCE] = Value(ll.type.leafref_require_instance())
        items[JSON_SCHEMA_X_YANG] = Value(lr_xy^)
        return items^
    return _type_schema(ll.type)


def _leaf_list_property(read ll: YangLeafList) raises -> Object:
    var out = Object()
    out[JSON_SCHEMA_TYPE] = Value("array")
    out[JSON_SCHEMA_ITEMS] = Value(_leaf_list_items_schema(ll))
    out[JSON_SCHEMA_DESCRIPTION] = Value("")
    out[JSON_SCHEMA_X_YANG] = Value(_leaf_list_xyang(ll))
    if ll.min_elements >= 0:
        out[JSON_SCHEMA_MIN_ITEMS] = Value(ll.min_elements)
    if ll.max_elements >= 0:
        out[JSON_SCHEMA_MAX_ITEMS] = Value(ll.max_elements)
    if len(ll.default_values) > 0:
        var darr = Array()
        for i in range(len(ll.default_values)):
            var dv = _default_json_value_for_type(ll.default_values[i], ll.type)
            if dv:
                darr.append(dv.value().copy())
        if len(darr) > 0:
            out[JSON_SCHEMA_DEFAULT] = Value(darr^)
    return out^


def _stub_leaf_property() raises -> Object:
    var xy = Object()
    xy[XYANG_TYPE] = Value("leaf")
    var o = Object()
    o[JSON_SCHEMA_TYPE] = Value("string")
    o[JSON_SCHEMA_X_YANG] = Value(xy^)
    return o^


def _find_named_property(
    name: String,
    read leaves: List[Arc[YangLeaf]],
    read leaf_lists: List[Arc[YangLeafList]],
    read anydatas: List[Arc[YangAnydata]],
    read anyxmls: List[Arc[YangAnyxml]],
    read containers: List[Arc[YangContainer]],
    read lists: List[Arc[YangList]],
) raises -> Object:
    for i in range(len(leaves)):
        if leaves[i][].name == name:
            return _leaf_property(leaves[i][])
    for i in range(len(leaf_lists)):
        if leaf_lists[i][].name == name:
            return _leaf_list_property(leaf_lists[i][])
    for i in range(len(anydatas)):
        if anydatas[i][].name == name:
            return _anydata_property(anydatas[i][])
    for i in range(len(anyxmls)):
        if anyxmls[i][].name == name:
            return _anyxml_property(anyxmls[i][])
    for i in range(len(containers)):
        if containers[i][].name == name:
            return _container_property(containers[i][])
    for i in range(len(lists)):
        if lists[i][].name == name:
            return _list_property(lists[i][])
    return _stub_leaf_property()


def _choice_property(
    read choice: YangChoice,
    read leaves: List[Arc[YangLeaf]],
    read leaf_lists: List[Arc[YangLeafList]],
    read anydatas: List[Arc[YangAnydata]],
    read anyxmls: List[Arc[YangAnyxml]],
    read containers: List[Arc[YangContainer]],
    read lists: List[Arc[YangList]],
) raises -> Object:
    var out = Object()
    out[JSON_SCHEMA_TYPE] = Value("object")
    out[JSON_SCHEMA_DESCRIPTION] = Value("")

    var xy = Object()
    xy[XYANG_TYPE] = Value("choice")
    xy[XYANG_MANDATORY] = Value(choice.mandatory)
    if len(choice.default_case) > 0:
        xy[XYANG_DEFAULT] = Value(choice.default_case)
    if choice.has_when():
        ref w = choice.when.value()
        xy[XYANG_WHEN] = Value(_when_object(w))
    out[JSON_SCHEMA_X_YANG] = Value(xy^)

    var branches = Array()
    var n_cases = len(choice.cases)
    if not choice.mandatory and n_cases > 1:
        var empty = Object()
        empty[JSON_SCHEMA_TYPE] = Value("object")
        empty[JSON_SCHEMA_MAX_PROPERTIES] = Value(0)
        branches.append(Value(empty^))

    for i in range(n_cases):
        ref case_node = choice.cases[i][]
        var props = Object()
        var req = Array()
        for j in range(len(case_node.node_names)):
            var nm = case_node.node_names[j]
            props[nm] = Value(
                _find_named_property(nm, leaves, leaf_lists, anydatas, anyxmls, containers, lists)
            )
            req.append(Value(nm))
        var branch = Object()
        branch[JSON_SCHEMA_TYPE] = Value("object")
        branch[JSON_SCHEMA_DESCRIPTION] = Value("")
        branch[JSON_SCHEMA_PROPERTIES] = Value(props^)
        branch[JSON_SCHEMA_ADDITIONAL_PROPERTIES] = Value(False)
        branch[JSON_SCHEMA_REQUIRED] = Value(req^)
        var case_xy = Object()
        case_xy[JSON_SCHEMA_NAME] = Value(case_node.name)
        if case_node.has_when():
            ref cw = case_node.when.value()
            case_xy[XYANG_WHEN] = Value(_when_object(cw))
        branch[JSON_SCHEMA_X_YANG] = Value(case_xy^)
        branches.append(Value(branch^))

    out[JSON_SCHEMA_ONE_OF] = Value(branches^)
    return out^


def _container_property(read c: YangContainer) raises -> Object:
    var props = Object()
    var req = Array()

    for i in range(len(c.leaves)):
        ref lf = c.leaves[i][]
        props[lf.name] = Value(_leaf_property(lf))
        if lf.mandatory:
            req.append(Value(lf.name))
    for i in range(len(c.leaf_lists)):
        ref ll = c.leaf_lists[i][]
        props[ll.name] = Value(_leaf_list_property(ll))
    for i in range(len(c.anydatas)):
        ref ad = c.anydatas[i][]
        props[ad.name] = Value(_anydata_property(ad))
        if ad.mandatory:
            req.append(Value(ad.name))
    for i in range(len(c.anyxmls)):
        ref ax = c.anyxmls[i][]
        props[ax.name] = Value(_anyxml_property(ax))
        if ax.mandatory:
            req.append(Value(ax.name))
    for i in range(len(c.containers)):
        ref ch = c.containers[i][]
        props[ch.name] = Value(_container_property(ch))
    for i in range(len(c.lists)):
        ref lst = c.lists[i][]
        props[lst.name] = Value(_list_property(lst))
    for i in range(len(c.choices)):
        ref ch = c.choices[i][]
        props[ch.name] = Value(
            _choice_property(
                ch,
                c.leaves,
                c.leaf_lists,
                c.anydatas,
                c.anyxmls,
                c.containers,
                c.lists,
            )
        )

    var xy = Object()
    xy[XYANG_TYPE] = Value("container")
    var out = Object()
    out[JSON_SCHEMA_TYPE] = Value("object")
    out[JSON_SCHEMA_DESCRIPTION] = Value(c.description)
    out[JSON_SCHEMA_X_YANG] = Value(xy^)
    if len(props) > 0:
        out[JSON_SCHEMA_PROPERTIES] = Value(props^)
    out[JSON_SCHEMA_ADDITIONAL_PROPERTIES] = Value(False)
    if len(req) > 0:
        out[JSON_SCHEMA_REQUIRED] = Value(req^)
    return out^


def _list_items_schema(read lst: YangList) raises -> Object:
    var props = Object()
    var req = Array()
    for i in range(len(lst.leaves)):
        ref lf = lst.leaves[i][]
        props[lf.name] = Value(_leaf_property(lf))
        if lf.mandatory:
            req.append(Value(lf.name))
    for i in range(len(lst.leaf_lists)):
        ref ll = lst.leaf_lists[i][]
        props[ll.name] = Value(_leaf_list_property(ll))
    for i in range(len(lst.anydatas)):
        ref ad = lst.anydatas[i][]
        props[ad.name] = Value(_anydata_property(ad))
        if ad.mandatory:
            req.append(Value(ad.name))
    for i in range(len(lst.anyxmls)):
        ref ax = lst.anyxmls[i][]
        props[ax.name] = Value(_anyxml_property(ax))
        if ax.mandatory:
            req.append(Value(ax.name))
    for i in range(len(lst.containers)):
        ref ch = lst.containers[i][]
        props[ch.name] = Value(_container_property(ch))
    for i in range(len(lst.lists)):
        ref inner = lst.lists[i][]
        props[inner.name] = Value(_list_property(inner))
    for i in range(len(lst.choices)):
        ref ch = lst.choices[i][]
        props[ch.name] = Value(
            _choice_property(
                ch,
                lst.leaves,
                lst.leaf_lists,
                lst.anydatas,
                lst.anyxmls,
                lst.containers,
                lst.lists,
            )
        )

    var items = Object()
    items[JSON_SCHEMA_TYPE] = Value("object")
    if len(props) > 0:
        items[JSON_SCHEMA_PROPERTIES] = Value(props^)
    items[JSON_SCHEMA_ADDITIONAL_PROPERTIES] = Value(False)
    if len(req) > 0:
        items[JSON_SCHEMA_REQUIRED] = Value(req^)
    return items^


def _list_property(read lst: YangList) raises -> Object:
    var xy = Object()
    xy[XYANG_TYPE] = Value("list")
    xy[XYANG_KEY] = Value(lst.key)
    if len(lst.ordered_by) > 0:
        xy[XYANG_ORDERED_BY] = Value(lst.ordered_by)
    if len(lst.unique_specs) > 0:
        var uarr = Array()
        for i in range(len(lst.unique_specs)):
            ref spec = lst.unique_specs[i]
            var inner = Array()
            for j in range(len(spec)):
                inner.append(Value(spec[j]))
            uarr.append(Value(inner^))
        xy[XYANG_UNIQUE] = Value(uarr^)
    var out = Object()
    out[JSON_SCHEMA_TYPE] = Value("array")
    out[JSON_SCHEMA_ITEMS] = Value(_list_items_schema(lst))
    out[JSON_SCHEMA_DESCRIPTION] = Value(lst.description)
    out[JSON_SCHEMA_X_YANG] = Value(xy^)
    if lst.min_elements >= 0:
        out[JSON_SCHEMA_MIN_ITEMS] = Value(lst.min_elements)
    if lst.max_elements >= 0:
        out[JSON_SCHEMA_MAX_ITEMS] = Value(lst.max_elements)
    return out^


def generate_json_schema(read module: YangModule) raises -> Value:
    var root_xy = Object()
    root_xy[XYANG_MODULE] = Value(module.name)
    root_xy[XYANG_YANG_VERSION] = Value("1.1")
    root_xy[XYANG_NAMESPACE] = Value(module.namespace)
    root_xy[XYANG_PREFIX] = Value(module.prefix)
    root_xy[XYANG_ORGANIZATION] = Value(module.organization)
    root_xy[XYANG_CONTACT] = Value(module.contact)

    var props = Object()
    for i in range(len(module.top_level_containers)):
        ref c = module.top_level_containers[i][]
        props[c.name] = Value(_container_property(c))

    var root = Object()
    root[JSON_SCHEMA_SCHEMA] = Value(JSON_SCHEMA_DRAFT_2020_12)
    var mod_id = module.namespace
    if len(mod_id) == 0:
        mod_id = "urn:" + module.name
    root[JSON_SCHEMA_ID] = Value(mod_id)
    root[JSON_SCHEMA_DESCRIPTION] = Value(module.description)
    root[JSON_SCHEMA_X_YANG] = Value(root_xy^)
    root[JSON_SCHEMA_TYPE] = Value("object")
    root[JSON_SCHEMA_PROPERTIES] = Value(props^)
    root[JSON_SCHEMA_ADDITIONAL_PROPERTIES] = Value(False)
    return Value(root^)


def schema_to_yang_json(read module: YangModule, indent: Int = 2) raises -> String:
    var root = generate_json_schema(module)
    return write_pretty(root, indent) + "\n"
