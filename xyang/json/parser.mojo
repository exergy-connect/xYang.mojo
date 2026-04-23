## JSON/YANG parser for Mojo xYang using EmberJson.

from emberjson import parse, Value
from std.memory import ArcPointer
from xyang.xpath import parse_xpath, Expr
from xyang.ast import (
    YangModule,
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangType,
    YangMust,
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


def parse_yang_leaf(name: String, prop: Value, mandatory: Bool) raises -> YangLeaf:
    """Parse a leaf definition from a JSON Schema property."""
    var type_name = _leaf_type_name_from_prop(prop)
    var must_list = List[Arc[YangMust]]()
    if "x-yang" in prop.object() and prop.object()["x-yang"].is_object():
        ref xy = prop.object()["x-yang"]
        must_list = _parse_yang_must_list(xy)
    return YangLeaf(
        name = name,
        type = YangType(
            name = type_name,
            has_range = False,
            range_min = 0,
            range_max = 0,
        ),
        mandatory = mandatory,
        must = must_list^,
    )


def _parse_node_children(
    parent_prop: Value,
    mut leaves: List[Arc[YangLeaf]],
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
        elif kind == "leaf" or kind == "leafref" or kind == "leaf-list":
            var mandatory = _is_required(pair.key, parent_prop)
            var yl = parse_yang_leaf(pair.key, child, mandatory)
            leaves.append(Arc[YangLeaf](yl^))
        elif kind == "list":
            var yl = parse_yang_list(pair.key, child)
            lists.append(Arc[YangList](yl^))
        elif kind == "choice":
            var ych = parse_yang_choice(pair.key, child)
            choices.append(Arc[YangChoice](ych^))


def parse_yang_choice(name: String, prop: Value) raises -> YangChoice:
    """Parse a choice definition from a JSON Schema property (oneOf)."""
    var mandatory = False
    if "x-yang" in prop.object() and "mandatory" in prop.object()["x-yang"].object():
        mandatory = prop.object()["x-yang"]["mandatory"].bool()

    var case_names = List[String]()
    if "oneOf" in prop.object() and prop.object()["oneOf"].is_array():
        ref one_of = prop.object()["oneOf"].array()
        for i in range(len(one_of)):
            ref branch = one_of[i].object()
            if "required" in branch and branch["required"].is_array():
                ref req = branch["required"].array()
                if len(req) > 0 and req[0].is_string():
                    case_names.append(req[0].string())
            elif "properties" in branch:
                ref branch_props = branch["properties"].object()
                for ref p in branch_props.items():
                    case_names.append(p.key)
                    break
    return YangChoice(name=name, mandatory=mandatory, case_names=case_names^)


def parse_yang_list(name: String, prop: Value) raises -> YangList:
    """Parse a list definition from a JSON Schema property (array with items)."""
    var desc = ""
    if "description" in prop.object():
        desc = prop.object()["description"].string()

    var key = ""
    if "x-yang" in prop.object() and "key" in prop.object()["x-yang"].object():
        key = prop.object()["x-yang"]["key"].string()

    var leaves = List[Arc[YangLeaf]]()
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
                elif kind == "leaf" or kind == "leafref" or kind == "leaf-list":
                    var mandatory = False
                    if "required" in items_schema and items_schema["required"].is_array():
                        ref req = items_schema["required"].array()
                        for ri in range(len(req)):
                            if req[ri].is_string() and req[ri].string() == pair.key:
                                mandatory = True
                                break
                    var yl = parse_yang_leaf(pair.key, child, mandatory)
                    leaves.append(Arc[YangLeaf](yl^))
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
    var containers = List[Arc[YangContainer]]()
    var lists = List[Arc[YangList]]()
    var choices = List[Arc[YangChoice]]()
    _parse_node_children(prop, leaves, containers, lists, choices)
    return YangContainer(
        name = name,
        description = desc,
        leaves = leaves^,
        containers = containers^,
        lists = lists^,
        choices = choices^,
    )


def parse_json_schema(source: String) raises -> YangModule:
    ## Backward-compatible alias used by package exports.
    return parse_yang_module(source)
