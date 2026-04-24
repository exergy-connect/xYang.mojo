## JSON/YANG parser for Mojo xYang using EmberJson.

from emberjson import parse, Value
from std.memory import ArcPointer
from xyang.xpath import parse_xpath, Expr
from xyang.ast import (
    YangModule,
    YangContainer,
    YangList,
    YangChoice,
    YangChoiceCase,
    YangLeaf,
    YangLeafList,
    YangType,
    YangMust,
    YangWhen,
)
from xyang.yang.tokens import (
    YANG_TYPE_LEAFREF,
    YANG_STMT_ENUM,
    YANG_STMT_LEAF_LIST,
    YANG_STMT_UNION,
)
from xyang.json.schema_keys import (
    JSON_SCHEMA_MIN_ITEMS,
    JSON_SCHEMA_MAX_ITEMS,
    XYANG_ORDERED_BY,
    XYANG_UNIQUE,
    XYANG_FRACTION_DIGITS,
    XYANG_BASE,
    XYANG_BITS,
)

comptime Arc = ArcPointer


def parse_yang_module(source: String) raises -> YangModule:
    # Parse a `.yang.json` meta-model into a minimal YangModule AST.
    # This is a placeholder stub that demonstrates wiring EmberJson into the
    # xYang.mojo AST. It does **not** yet implement the full xYang meta-model.
    var root: Value = parse(source)

    # The meta-model schema stores module metadata under the "x-yang" object
    # at the top level. Guard against schemas that don't include this block.
    var name = ""
    var ns = ""
    var prefix = ""

    if "x-yang" in root.object():
        ref xyang = root.object()["x-yang"]
        name = xyang.object()["module"].string()
        ns = xyang.object()["namespace"].string()
        prefix = xyang.object()["prefix"].string()

    # Discover top-level YANG containers from root["properties"].
    var containers = List[Arc[YangContainer]]()
    ref props_obj = root.object()["properties"].object()
    for ref pair in props_obj.items():
        ref prop = pair.value
        if not prop.is_object():
            continue
        var kind = ""
        if "x-yang" in prop.object():
            kind = prop.object()["x-yang"]["type"].string()
        if kind == "container":
            var yc = parse_yang_container(pair.key, prop)
            containers.append(Arc[YangContainer](yc^))

    return YangModule(
        name = name,
        namespace = ns,
        prefix = prefix,
        description = "",
        revisions = List[String](),
        organization = "",
        contact = "",
        top_level_containers = containers^,
    )


def _leaf_type_name_from_prop(prop: Value) raises -> String:
    """Derive a YANG/type name from a JSON Schema property (type or $ref)."""
    ref obj = prop.object()
    if "type" in obj and obj["type"].is_string():
        return obj["type"].string()
    if "$ref" in obj and obj["$ref"].is_string():
        var ref_val = obj["$ref"].string()
        # Use last segment of ref, e.g. "#/$defs/version-string" -> "version-string"
        var parts = ref_val.split("/")
        if len(parts) > 0:
            return String(parts[len(parts) - 1])
        return ref_val
    return "unknown"


def _empty_type(name: String) -> YangType:
    return YangType(
        name = name,
        has_range = False,
        range_min = 0,
        range_max = 0,
        enum_values = List[String](),
        union_types = List[Arc[YangType]](),
        has_leafref_path = False,
        leafref_path = "",
        leafref_require_instance = True,
        leafref_xpath_ast = Expr.ExprPointer(),
        leafref_path_parsed = False,
        fraction_digits = 0,
        has_decimal64_range = False,
        decimal64_range_min = Float64(0.0),
        decimal64_range_max = Float64(0.0),
        bits_names = List[String](),
        identityref_base = "",
    )


def _parse_type_from_schema_property(prop: Value) raises -> YangType:
    ref obj = prop.object()
    var t = _empty_type(_leaf_type_name_from_prop(prop))

    if "enum" in obj and obj["enum"].is_array():
        ref earr = obj["enum"].array()
        if len(earr) > 0:
            t.name = "enumeration"
            for i in range(len(earr)):
                if earr[i].is_string():
                    t.enum_values.append(earr[i].string())

    if "oneOf" in obj and obj["oneOf"].is_array():
        ref one_of = obj["oneOf"].array()
        var members = List[Arc[YangType]]()
        for i in range(len(one_of)):
            if not one_of[i].is_object():
                continue
            var member = _parse_type_from_schema_property(one_of[i])
            members.append(Arc[YangType](member^))
        if len(members) > 0:
            t.name = YANG_STMT_UNION
            t.union_types = members^

    if "x-yang" in obj and obj["x-yang"].is_object():
        ref xy = obj["x-yang"]
        if "type" in xy.object() and xy.object()["type"].is_string():
            var xyang_type = xy.object()["type"].string()
            if xyang_type == YANG_TYPE_LEAFREF:
                t.name = xyang_type
            elif xyang_type == YANG_STMT_UNION and len(t.union_types) > 0:
                t.name = xyang_type
            elif xyang_type == "enumeration" and len(t.enum_values) > 0:
                t.name = xyang_type
            elif (
                xyang_type == "decimal64"
                or xyang_type == "bits"
                or xyang_type == "identityref"
            ):
                t.name = xyang_type
        if t.name == YANG_TYPE_LEAFREF:
            if "path" in xy.object() and xy.object()["path"].is_string():
                t.has_leafref_path = True
                t.leafref_path = xy.object()["path"].string()
                try:
                    t.leafref_xpath_ast = parse_xpath(t.leafref_path)
                    t.leafref_path_parsed = True
                except:
                    t.leafref_xpath_ast = Expr.ExprPointer()
                    t.leafref_path_parsed = False
            if "require-instance" in xy.object() and xy.object()["require-instance"].is_bool():
                t.leafref_require_instance = xy.object()["require-instance"].bool()
        if t.name == "decimal64":
            if XYANG_FRACTION_DIGITS in xy.object() and xy.object()[XYANG_FRACTION_DIGITS].is_int():
                t.fraction_digits = Int(xy.object()[XYANG_FRACTION_DIGITS].int())
            if "minimum" in obj and "maximum" in obj:
                ref minv = obj["minimum"]
                ref maxv = obj["maximum"]
                if (minv.is_int() or minv.is_uint() or minv.is_float()) and (
                    maxv.is_int() or maxv.is_uint() or maxv.is_float()
                ):
                    t.has_decimal64_range = True
                    t.decimal64_range_min = minv.float()
                    t.decimal64_range_max = maxv.float()
        if t.name == "bits" and XYANG_BITS in xy.object() and xy.object()[XYANG_BITS].is_array():
            ref barr = xy.object()[XYANG_BITS].array()
            for i in range(len(barr)):
                if barr[i].is_string():
                    t.bits_names.append(barr[i].string())
        if t.name == "identityref" and XYANG_BASE in xy.object() and xy.object()[XYANG_BASE].is_string():
            t.identityref_base = xy.object()[XYANG_BASE].string()

    return t^


def _is_required(prop_key: String, container_prop: Value) raises -> Bool:
    """True if prop_key is in the container's required array."""
    ref obj = container_prop.object()
    if "required" not in obj or not obj["required"].is_array():
        return False
    ref arr = obj["required"].array()
    for i in range(len(arr)):
        if arr[i].is_string() and arr[i].string() == prop_key:
            return True
    return False


def _parse_yang_must_list(ref xy: Value) raises -> List[Arc[YangMust]]:
    """Extract a list of YangMust constraints from an x-yang object."""
    var must_list = List[Arc[YangMust]]()
    if "must" not in xy.object() or not xy.object()["must"].is_array():
        return must_list^

    ref marr = xy.object()["must"].array()
    for i in range(len(marr)):
        if not marr[i].is_object():
            continue
        ref mobj = marr[i].object()
        var expr = ""
        var errmsg = ""
        var desc = ""
        if "must" in mobj and mobj["must"].is_string():
            expr = mobj["must"].string()
        if "error-message" in mobj and mobj["error-message"].is_string():
            errmsg = mobj["error-message"].string()
        if "description" in mobj and mobj["description"].is_string():
            desc = mobj["description"].string()

        # Parse the must expression via the XPath parser when possible; store AST in YangMust (it owns and frees).
        # If parsing fails (e.g. unsupported syntax like ('a','b')), xpath_ast is empty and parsed=False.
        var ptr = Expr.ExprPointer()
        var parsed = False
        try:
            ptr = parse_xpath(expr)
            parsed = True
        except e:
            print("[x-yang must] parse_xpath failed for expression: ", expr, " error: ", String(e))
        must_list.append(Arc[YangMust](
            YangMust(
                expression = expr,
                error_message = errmsg,
                description = desc,
                xpath_ast = ptr,
                parsed = parsed,
            ),
        ))
    return must_list^


def _parse_yang_when(ref xy: Value) raises -> Optional[YangWhen]:
    if "when" not in xy.object():
        return Optional[YangWhen]()
    ref when_val = xy.object()["when"]
    var expr = ""
    var desc = ""
    if when_val.is_string():
        expr = when_val.string()
    elif when_val.is_object():
        ref wo = when_val.object()
        if "condition" in wo and wo["condition"].is_string():
            expr = wo["condition"].string()
        if "description" in wo and wo["description"].is_string():
            desc = wo["description"].string()
    if len(expr) == 0:
        return Optional[YangWhen]()
    var ptr = Expr.ExprPointer()
    var parsed = False
    try:
        ptr = parse_xpath(expr)
        parsed = True
    except e:
        print("[x-yang when] parse_xpath failed for expression: ", expr, " error: ", String(e))
    return Optional(
        YangWhen(
            expression = expr,
            description = desc,
            xpath_ast = ptr,
            parsed = parsed,
        ),
    )


def _default_scalar_to_string(v: Value) -> String:
    if v.is_string():
        return v.string()
    if v.is_bool():
        return "true" if v.bool() else "false"
    if v.is_int():
        return String(v.int())
    if v.is_uint():
        return String(v.uint())
    if v.is_float():
        return String(v.float())
    return ""


def parse_yang_leaf(name: String, prop: Value, mandatory: Bool) raises -> YangLeaf:
    """Parse a leaf definition from a JSON Schema property."""
    var type_stmt = _parse_type_from_schema_property(prop)
    var must_list = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    var has_default = False
    var default_value = ""
    var default_argument_was_quoted = False
    if "x-yang" in prop.object() and prop.object()["x-yang"].is_object():
        ref xy = prop.object()["x-yang"]
        must_list = _parse_yang_must_list(xy)
        when = _parse_yang_when(xy)
    if "default" in prop.object():
        ref dv = prop.object()["default"]
        if type_stmt.name == YANG_STMT_UNION and dv.is_string():
            default_argument_was_quoted = True
        default_value = _default_scalar_to_string(dv)
        has_default = len(default_value) > 0
    return YangLeaf(
        name = name,
        type = type_stmt^,
        mandatory = mandatory,
        has_default = has_default,
        default_value = default_value,
        default_argument_was_quoted = default_argument_was_quoted,
        must_statements = must_list^,
        when = when^,
    )


def parse_yang_leaf_list(name: String, prop: Value) raises -> YangLeafList:
    var type_stmt = _parse_type_from_schema_property(prop)
    var must_list = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    var default_values = List[String]()
    var min_e = -1
    var max_e = -1
    var ob = ""
    ref po = prop.object()
    if JSON_SCHEMA_MIN_ITEMS in po:
        min_e = Int(po[JSON_SCHEMA_MIN_ITEMS].int())
    if JSON_SCHEMA_MAX_ITEMS in po:
        max_e = Int(po[JSON_SCHEMA_MAX_ITEMS].int())
    if "x-yang" in po and po["x-yang"].is_object():
        ref xy = po["x-yang"]
        must_list = _parse_yang_must_list(xy)
        when = _parse_yang_when(xy)
        if XYANG_ORDERED_BY in xy.object() and xy[XYANG_ORDERED_BY].is_string():
            ob = xy[XYANG_ORDERED_BY].string()
    if "default" in prop.object():
        ref default_val = prop.object()["default"]
        if default_val.is_array():
            ref default_arr = default_val.array()
            for i in range(len(default_arr)):
                var text = _default_scalar_to_string(default_arr[i])
                if len(text) > 0:
                    default_values.append(text)
        else:
            var text = _default_scalar_to_string(default_val)
            if len(text) > 0:
                default_values.append(text)
    return YangLeafList(
        name = name,
        type = type_stmt^,
        default_values = default_values^,
        must_statements = must_list^,
        when = when^,
        min_elements = min_e,
        max_elements = max_e,
        ordered_by = ob,
    )


def _parse_node_children(
    parent_prop: Value,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) raises:
    """Parse properties of a container or list-items schema; appends into the given lists."""
    if "properties" not in parent_prop.object():
        return

    ref props_obj = parent_prop.object()["properties"].object()
    for ref pair in props_obj.items():
        ref child = pair.value
        var kind = ""
        if "x-yang" in child.object():
            kind = child.object()["x-yang"]["type"].string()

        if kind == "container":
            var yc = parse_yang_container(pair.key, child)
            containers.append(Arc[YangContainer](yc^))
        elif kind == "leaf" or kind == YANG_TYPE_LEAFREF:
            var mandatory = _is_required(pair.key, parent_prop)
            var yl = parse_yang_leaf(pair.key, child, mandatory)
            leaves.append(Arc[YangLeaf](yl^))
        elif kind == YANG_STMT_LEAF_LIST:
            var yll = parse_yang_leaf_list(pair.key, child)
            leaf_lists.append(Arc[YangLeafList](yll^))
        elif kind == "list":
            var yl = parse_yang_list(pair.key, child)
            lists.append(Arc[YangList](yl^))
        elif kind == "choice":
            var ych = parse_yang_choice(pair.key, child)
            choices.append(Arc[YangChoice](ych^))


def parse_yang_choice(name: String, prop: Value) raises -> YangChoice:
    """Parse a choice definition from a JSON Schema property (oneOf)."""
    var mandatory = False
    var default_case = ""
    var ch_when = Optional[YangWhen]()
    ref po = prop.object()
    if "x-yang" in po and po["x-yang"].is_object():
        ref xy = po["x-yang"]
        if "mandatory" in xy:
            mandatory = xy["mandatory"].bool()
        if "default" in xy and xy["default"].is_string():
            default_case = xy["default"].string()
        ch_when = _parse_yang_when(po["x-yang"])

    var case_names = List[String]()
    var cases = List[Arc[YangChoiceCase]]()
    if "oneOf" in po and po["oneOf"].is_array():
        ref one_of = po["oneOf"].array()
        for i in range(len(one_of)):
            ref branch = one_of[i].object()
            var case_name = "case-" + String(i)
            var node_names = List[String]()
            var case_when = Optional[YangWhen]()
            if "x-yang" in branch and branch["x-yang"].is_object():
                case_when = _parse_yang_when(branch["x-yang"])
            if "required" in branch and branch["required"].is_array():
                ref req = branch["required"].array()
                if len(req) > 0:
                    for j in range(len(req)):
                        if req[j].is_string():
                            var n = req[j].string()
                            node_names.append(n)
                            case_names.append(n)
                    if len(node_names) > 0:
                        case_name = node_names[0]
            elif "properties" in branch:
                ref branch_props = branch["properties"].object()
                for ref p in branch_props.items():
                    node_names.append(p.key)
                    case_names.append(p.key)
                if len(node_names) > 0:
                    case_name = node_names[0]
            cases.append(
                Arc[YangChoiceCase](
                    YangChoiceCase(name=case_name, node_names=node_names^, when=case_when^),
                ),
            )
    return YangChoice(
        name=name,
        mandatory=mandatory,
        default_case=default_case,
        case_names=case_names^,
        cases=cases^,
        when=ch_when^,
    )


def parse_yang_list(name: String, prop: Value) raises -> YangList:
    """Parse a list definition from a JSON Schema property (array with items)."""
    var desc = ""
    if "description" in prop.object():
        desc = prop.object()["description"].string()

    var key = ""
    var min_e = -1
    var max_e = -1
    var ob = ""
    var unique_specs = List[List[String]]()
    ref po = prop.object()
    if "x-yang" in po and po["x-yang"].is_object():
        ref xy = po["x-yang"]
        if "key" in xy:
            key = xy["key"].string()
        if XYANG_ORDERED_BY in xy and xy[XYANG_ORDERED_BY].is_string():
            ob = xy[XYANG_ORDERED_BY].string()
        if XYANG_UNIQUE in xy and xy[XYANG_UNIQUE].is_array():
            ref uarr = xy[XYANG_UNIQUE].array()
            for ui in range(len(uarr)):
                ref uv = uarr[ui]
                var spec = List[String]()
                if uv.is_array():
                    ref inner = uv.array()
                    for vi in range(len(inner)):
                        if inner[vi].is_string():
                            spec.append(inner[vi].string())
                elif uv.is_string():
                    var raw = uv.string().split()
                    for ri in range(len(raw)):
                        var seg = String(String(raw[ri]).strip())
                        if len(seg) > 0:
                            spec.append(seg^)
                if len(spec) > 0:
                    unique_specs.append(spec^)
    if JSON_SCHEMA_MIN_ITEMS in po:
        min_e = Int(po[JSON_SCHEMA_MIN_ITEMS].int())
    if JSON_SCHEMA_MAX_ITEMS in po:
        max_e = Int(po[JSON_SCHEMA_MAX_ITEMS].int())

    var leaves = List[Arc[YangLeaf]]()
    var leaf_lists = List[Arc[YangLeafList]]()
    var containers = List[Arc[YangContainer]]()
    var lists = List[Arc[YangList]]()
    var choices = List[Arc[YangChoice]]()

    if "items" in po and po["items"].is_object():
        ref items_schema = po["items"].object()
        if "properties" in items_schema:
            ref item_props = items_schema["properties"].object()
            for ref pair in item_props.items():
                ref child = pair.value
                var kind = ""
                if "x-yang" in child.object():
                    kind = child.object()["x-yang"]["type"].string()

                if kind == "container":
                    var yc = parse_yang_container(pair.key, child)
                    containers.append(Arc[YangContainer](yc^))
                elif kind == "leaf" or kind == YANG_TYPE_LEAFREF:
                    var mandatory = False
                    if "required" in items_schema and items_schema["required"].is_array():
                        ref req = items_schema["required"].array()
                        for ri in range(len(req)):
                            if req[ri].is_string() and req[ri].string() == pair.key:
                                mandatory = True
                                break
                    var yl = parse_yang_leaf(pair.key, child, mandatory)
                    leaves.append(Arc[YangLeaf](yl^))
                elif kind == YANG_STMT_LEAF_LIST:
                    var yll = parse_yang_leaf_list(pair.key, child)
                    leaf_lists.append(Arc[YangLeafList](yll^))
                elif kind == "list":
                    var yl = parse_yang_list(pair.key, child)
                    lists.append(Arc[YangList](yl^))
                elif kind == "choice":
                    var ych = parse_yang_choice(pair.key, child)
                    choices.append(Arc[YangChoice](ych^))

    return YangList(
        name = name,
        key = key,
        description = desc,
        leaves = leaves^,
        leaf_lists = leaf_lists^,
        containers = containers^,
        lists = lists^,
        choices = choices^,
        min_elements = min_e,
        max_elements = max_e,
        ordered_by = ob,
        unique_specs = unique_specs^,
    )


def parse_yang_container(name: String, prop: Value) raises -> YangContainer:
    """Parse a container definition from a JSON Schema property, including its properties."""
    var desc = ""
    if "description" in prop.object():
        desc = prop.object()["description"].string()

    var leaves = List[Arc[YangLeaf]]()
    var leaf_lists = List[Arc[YangLeafList]]()
    var containers = List[Arc[YangContainer]]()
    var lists = List[Arc[YangList]]()
    var choices = List[Arc[YangChoice]]()
    _parse_node_children(prop, leaves, leaf_lists, containers, lists, choices)
    return YangContainer(
        name = name,
        description = desc,
        leaves = leaves^,
        leaf_lists = leaf_lists^,
        containers = containers^,
        lists = lists^,
        choices = choices^,
    )


def parse_json_schema(source: String) raises -> YangModule:
    ## Backward-compatible alias used by package exports.
    return parse_yang_module(source)
