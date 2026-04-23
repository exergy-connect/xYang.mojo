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
from xyang.yang.tokens import YANG_TYPE_LEAFREF, YANG_STMT_LEAF_LIST

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
    if "when" not in xy.object() or not xy.object()["when"].is_string():
        return Optional[YangWhen]()
    var expr = xy.object()["when"].string()
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
            description = "",
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
    var type_name = _leaf_type_name_from_prop(prop)
    var must_list = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    var has_leafref_path = False
    var leafref_path = ""
    var leafref_require_instance = True
    var leafref_xpath_ast = Expr.ExprPointer()
    var leafref_path_parsed = False
    var has_default = False
    var default_value = ""
    if "x-yang" in prop.object() and prop.object()["x-yang"].is_object():
        ref xy = prop.object()["x-yang"]
        if "type" in xy.object() and xy.object()["type"].is_string():
            type_name = xy.object()["type"].string()
        if type_name == YANG_TYPE_LEAFREF:
            if "path" in xy.object() and xy.object()["path"].is_string():
                has_leafref_path = True
                leafref_path = xy.object()["path"].string()
                try:
                    leafref_xpath_ast = parse_xpath(leafref_path)
                    leafref_path_parsed = True
                except:
                    leafref_xpath_ast = Expr.ExprPointer()
                    leafref_path_parsed = False
            if "require-instance" in xy.object() and xy.object()["require-instance"].is_bool():
                leafref_require_instance = xy.object()["require-instance"].bool()
        must_list = _parse_yang_must_list(xy)
        when = _parse_yang_when(xy)
    if "default" in prop.object():
        default_value = _default_scalar_to_string(prop.object()["default"])
        has_default = len(default_value) > 0
    return YangLeaf(
        name = name,
        type = YangType(
            name = type_name,
            has_range = False,
            range_min = 0,
            range_max = 0,
            has_leafref_path = has_leafref_path,
            leafref_path = leafref_path,
            leafref_require_instance = leafref_require_instance,
            leafref_xpath_ast = leafref_xpath_ast,
            leafref_path_parsed = leafref_path_parsed,
        ),
        mandatory = mandatory,
        has_default = has_default,
        default_value = default_value,
        must_statements = must_list^,
        when = when^,
    )


def parse_yang_leaf_list(name: String, prop: Value) raises -> YangLeafList:
    var type_name = _leaf_type_name_from_prop(prop)
    var must_list = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    var has_leafref_path = False
    var leafref_path = ""
    var leafref_require_instance = True
    var leafref_xpath_ast = Expr.ExprPointer()
    var leafref_path_parsed = False
    var default_values = List[String]()
    if "x-yang" in prop.object() and prop.object()["x-yang"].is_object():
        ref xy = prop.object()["x-yang"]
        if "type" in xy.object() and xy.object()["type"].is_string():
            type_name = xy.object()["type"].string()
        if type_name == YANG_TYPE_LEAFREF:
            if "path" in xy.object() and xy.object()["path"].is_string():
                has_leafref_path = True
                leafref_path = xy.object()["path"].string()
                try:
                    leafref_xpath_ast = parse_xpath(leafref_path)
                    leafref_path_parsed = True
                except:
                    leafref_xpath_ast = Expr.ExprPointer()
                    leafref_path_parsed = False
            if "require-instance" in xy.object() and xy.object()["require-instance"].is_bool():
                leafref_require_instance = xy.object()["require-instance"].bool()
        must_list = _parse_yang_must_list(xy)
        when = _parse_yang_when(xy)
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
        type = YangType(
            name = type_name,
            has_range = False,
            range_min = 0,
            range_max = 0,
            has_leafref_path = has_leafref_path,
            leafref_path = leafref_path,
            leafref_require_instance = leafref_require_instance,
            leafref_xpath_ast = leafref_xpath_ast,
            leafref_path_parsed = leafref_path_parsed,
        ),
        default_values = default_values^,
        must_statements = must_list^,
        when = when^,
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
    if "x-yang" in prop.object() and "mandatory" in prop.object()["x-yang"].object():
        mandatory = prop.object()["x-yang"]["mandatory"].bool()
    if (
        "x-yang" in prop.object()
        and "default" in prop.object()["x-yang"].object()
        and prop.object()["x-yang"]["default"].is_string()
    ):
        default_case = prop.object()["x-yang"]["default"].string()

    var case_names = List[String]()
    var cases = List[Arc[YangChoiceCase]]()
    if "oneOf" in prop.object() and prop.object()["oneOf"].is_array():
        ref one_of = prop.object()["oneOf"].array()
        for i in range(len(one_of)):
            ref branch = one_of[i].object()
            var case_name = "case-" + String(i)
            var node_names = List[String]()
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
            cases.append(Arc[YangChoiceCase](YangChoiceCase(name=case_name, node_names=node_names^)))
    return YangChoice(
        name=name,
        mandatory=mandatory,
        default_case=default_case,
        case_names=case_names^,
        cases=cases^,
    )


def parse_yang_list(name: String, prop: Value) raises -> YangList:
    """Parse a list definition from a JSON Schema property (array with items)."""
    var desc = ""
    if "description" in prop.object():
        desc = prop.object()["description"].string()

    var key = ""
    if "x-yang" in prop.object() and "key" in prop.object()["x-yang"].object():
        key = prop.object()["x-yang"]["key"].string()

    var leaves = List[Arc[YangLeaf]]()
    var leaf_lists = List[Arc[YangLeafList]]()
    var containers = List[Arc[YangContainer]]()
    var lists = List[Arc[YangList]]()
    var choices = List[Arc[YangChoice]]()

    if "items" in prop.object() and prop.object()["items"].is_object():
        ref items_schema = prop.object()["items"].object()
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
