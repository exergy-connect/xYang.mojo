## JSON/YANG parser for Mojo xYang using EmberJson.

from emberjson import parse, Value
from std.collections import Dict
from std.memory import ArcPointer, UnsafePointer
from xyang.xpath import parse_xpath
import xyang.ast as ast
import xyang.yang.parser.yang_token as yang_token
import xyang.json.schema_keys as schema_keys

comptime Arc = ArcPointer


def parse_yang_module(source: String) raises -> ast.YangModule:
    # Parse a `.yang.json` meta-model into a minimal YangModule AST.
    # This is a placeholder stub that demonstrates wiring EmberJson into the
    # xYang.mojo AST. It does **not** yet implement the full xYang meta-model.
    var root: Value = parse(source)

    # The meta-model schema stores module metadata under the "x-yang" object
    # at the top level. Guard against schemas that don't include this block.
    var name = ""
    var ns = ""
    var prefix = ""

    if schema_keys.JSON_SCHEMA_X_YANG in root.object():
        ref xyang = root.object()[schema_keys.JSON_SCHEMA_X_YANG]
        name = xyang.object()[schema_keys.XYANG_MODULE].string()
        ns = xyang.object()[schema_keys.XYANG_NAMESPACE].string()
        prefix = xyang.object()[schema_keys.XYANG_PREFIX].string()

    # Discover top-level YANG containers from root["properties"].
    var containers = List[Arc[ast.YangContainer]]()
    ref props_obj = root.object()[schema_keys.JSON_SCHEMA_PROPERTIES].object()
    for ref pair in props_obj.items():
        ref prop = pair.value
        if not prop.is_object():
            continue
        var kind = ""
        if schema_keys.JSON_SCHEMA_X_YANG in prop.object():
            kind = prop.object()[schema_keys.JSON_SCHEMA_X_YANG][
                schema_keys.XYANG_TYPE
            ].string()
        if kind == yang_token.YANG_STMT_CONTAINER:
            var yc = parse_yang_container(pair.key, prop)
            containers.append(Arc[ast.YangContainer](yc^))

    return ast.YangModule(
        name = name,
        namespace = ns,
        prefix = prefix,
        description = "",
        yang_version = "1.1",
        belongs_to_module = "",
        revisions = List[String](),
        revision_statements = List[Arc[ast.YangRevisionStmt]](),
        organization = "",
        contact = "",
        typedefs = Dict[String, Arc[ast.YangTypedefStmt]](),
        identities = Dict[String, Arc[ast.YangIdentityStmt]](),
        groupings = Dict[String, Arc[ast.YangGrouping]](),
        features = List[Arc[ast.YangFeatureStmt]](),
        feature_if_features = Dict[String, List[String]](),
        import_prefixes = Dict[String, Arc[ast.YangModuleImport]](),
        extensions = Dict[String, Arc[ast.YangExtensionStmt]](),
        statements = List[ast.YangModuleStatement](),
        top_level_containers = containers^,
    )


def _leaf_type_name_from_prop(prop: Value) raises -> String:
    """Derive a YANG/type name from a JSON Schema property (type or $ref)."""
    ref obj = prop.object()
    if schema_keys.JSON_SCHEMA_TYPE in obj and obj[schema_keys.JSON_SCHEMA_TYPE].is_string():
        return obj[schema_keys.JSON_SCHEMA_TYPE].string()
    if (
        schema_keys.JSON_SCHEMA_REF in obj
        and obj[schema_keys.JSON_SCHEMA_REF].is_string()
    ):
        var ref_val = obj[schema_keys.JSON_SCHEMA_REF].string()
        # Use last segment of ref, e.g. "#/$defs/version-string" -> "version-string"
        var parts = ref_val.split("/")
        if len(parts) > 0:
            return String(parts[len(parts) - 1])
        return ref_val
    return yang_token.YANG_TYPE_UNKNOWN


def _empty_type(name: String) -> ast.YangType:
    return ast.YangType(
        name=name,
        constraints=ast.YangTypeTypedef(
            resolved=UnsafePointer[ast.YangTypedefStmt, MutExternalOrigin](),
        ),
    )


def _parse_type_from_schema_property(prop: Value) raises -> ast.YangType:
    ref obj = prop.object()
    var ty_name = _leaf_type_name_from_prop(prop)
    var enum_values = List[String]()
    var union_members = List[Arc[ast.YangType]]()
    var lr_path = ""
    var lr_require_inst = True
    var fraction_digits = 0
    var has_dec_range = False
    var dec_min = Float64(0.0)
    var dec_max = Float64(0.0)
    var bits_names = List[String]()
    var identityref_base = ""
    var string_pattern = ""

    if (
        schema_keys.JSON_SCHEMA_ENUM in obj
        and obj[schema_keys.JSON_SCHEMA_ENUM].is_array()
    ):
        ref earr = obj[schema_keys.JSON_SCHEMA_ENUM].array()
        if len(earr) > 0:
            ty_name = yang_token.YANG_TYPE_ENUMERATION
            for ref enum_val in earr:
                if enum_val.is_string():
                    enum_values.append(enum_val.string())

    if (
        schema_keys.JSON_SCHEMA_ONE_OF in obj
        and obj[schema_keys.JSON_SCHEMA_ONE_OF].is_array()
    ):
        ref one_of = obj[schema_keys.JSON_SCHEMA_ONE_OF].array()
        var members = List[Arc[ast.YangType]]()
        for ref one_of_item in one_of:
            if not one_of_item.is_object():
                continue
            var member = _parse_type_from_schema_property(one_of_item)
            members.append(Arc[ast.YangType](member^))
        if len(members) > 0:
            ty_name = yang_token.YANG_STMT_UNION
            union_members = members^

    if (
        schema_keys.JSON_SCHEMA_X_YANG in obj
        and obj[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        ref xy = obj[schema_keys.JSON_SCHEMA_X_YANG]
        if (
            schema_keys.XYANG_TYPE in xy.object()
            and xy.object()[schema_keys.XYANG_TYPE].is_string()
        ):
            var xyang_type = xy.object()[schema_keys.XYANG_TYPE].string()
            if xyang_type == yang_token.YANG_TYPE_LEAFREF:
                ty_name = xyang_type
            elif xyang_type == yang_token.YANG_STMT_UNION and len(union_members) > 0:
                ty_name = xyang_type
            elif xyang_type == yang_token.YANG_STMT_ENUM and len(union_members) > 0:
                ty_name = xyang_type
            elif (
                xyang_type == yang_token.YANG_TYPE_DECIMAL64
                or xyang_type == yang_token.YANG_TYPE_BITS
                or xyang_type == yang_token.YANG_TYPE_IDENTITYREF
            ):
                ty_name = xyang_type
        if ty_name == yang_token.YANG_TYPE_LEAFREF:
            if (
                schema_keys.XYANG_PATH in xy.object()
                and xy.object()[schema_keys.XYANG_PATH].is_string()
            ):
                lr_path = xy.object()[schema_keys.XYANG_PATH].string()
            if (
                schema_keys.XYANG_REQUIRE_INSTANCE in xy.object()
                and xy.object()[schema_keys.XYANG_REQUIRE_INSTANCE].is_bool()
            ):
                lr_require_inst = xy.object()[
                    schema_keys.XYANG_REQUIRE_INSTANCE
                ].bool()
        if ty_name == yang_token.YANG_TYPE_DECIMAL64:
            if (
                schema_keys.XYANG_FRACTION_DIGITS in xy.object()
                and xy.object()[schema_keys.XYANG_FRACTION_DIGITS].is_int()
            ):
                fraction_digits = Int(
                    xy.object()[schema_keys.XYANG_FRACTION_DIGITS].int(),
                )
            if (
                schema_keys.JSON_SCHEMA_MINIMUM in obj
                and schema_keys.JSON_SCHEMA_MAXIMUM in obj
            ):
                ref minv = obj[schema_keys.JSON_SCHEMA_MINIMUM]
                ref maxv = obj[schema_keys.JSON_SCHEMA_MAXIMUM]
                if (minv.is_int() or minv.is_uint() or minv.is_float()) and (
                    maxv.is_int() or maxv.is_uint() or maxv.is_float()
                ):
                    has_dec_range = True
                    dec_min = minv.float()
                    dec_max = maxv.float()
        if ty_name == yang_token.YANG_TYPE_BITS and schema_keys.XYANG_BITS in xy.object() and xy.object()[schema_keys.XYANG_BITS].is_array():
            ref barr = xy.object()[schema_keys.XYANG_BITS].array()
            for ref bit_name in barr:
                if bit_name.is_string():
                    bits_names.append(bit_name.string())
        if ty_name == yang_token.YANG_TYPE_IDENTITYREF and schema_keys.XYANG_BASE in xy.object() and xy.object()[schema_keys.XYANG_BASE].is_string():
            identityref_base = xy.object()[schema_keys.XYANG_BASE].string()

    if (
        ty_name == "string"
        and schema_keys.JSON_SCHEMA_PATTERN in obj
        and obj[schema_keys.JSON_SCHEMA_PATTERN].is_string()
    ):
        string_pattern = obj[schema_keys.JSON_SCHEMA_PATTERN].string()

    var cons = _json_schema_yang_constraints(
        ty_name,
        enum_values^,
        lr_path,
        lr_require_inst,
        fraction_digits,
        has_dec_range,
        dec_min,
        dec_max,
        bits_names^,
        identityref_base,
        string_pattern^,
    )
    if ty_name == yang_token.YANG_STMT_UNION:
        return ast.YangType(
            name=ty_name,
            constraints=ast.YangTypeUnion(union_members=union_members^),
        )
    return ast.YangType(name=ty_name, constraints=cons)


def _json_schema_yang_constraints(
    ty_name: String,
    var enum_values: List[String],
    var lr_path: String,
    lr_require_inst: Bool,
    fraction_digits: Int,
    has_dec_range: Bool,
    dec_min: Float64,
    dec_max: Float64,
    var bits_names: List[String],
    var identityref_base: String,
    var string_pattern: String,
) -> ast.YangType.Constraints:
    if ty_name == yang_token.YANG_TYPE_ENUMERATION:
        return ast.YangTypeEnumeration(enum_values^)
    if ty_name == yang_token.YANG_TYPE_LEAFREF:
        if len(lr_path) == 0:
            return ast.YangTypeTypedef(
                resolved=UnsafePointer[ast.YangTypedefStmt, MutExternalOrigin](),
            )
        return ast.YangTypeLeafref(
            lr_path^,
            lr_require_inst,
        )
    if ty_name == yang_token.YANG_TYPE_DECIMAL64:
        return ast.YangTypeDecimal64(
            fraction_digits,
            has_dec_range,
            dec_min,
            dec_max,
        )
    if ty_name == yang_token.YANG_TYPE_BITS:
        return ast.YangTypeBits(bits_names^)
    if ty_name == yang_token.YANG_TYPE_IDENTITYREF:
        return ast.YangTypeIdentityref(identityref_base^)
    if ty_name == "string":
        return ast.YangTypeString(string_pattern^)
    return ast.YangTypeTypedef(
        resolved=UnsafePointer[ast.YangTypedefStmt, MutExternalOrigin](),
    )


def _is_required(prop_key: String, container_prop: Value) raises -> Bool:
    """True if prop_key is in the container's required array."""
    ref obj = container_prop.object()
    if (
        schema_keys.JSON_SCHEMA_REQUIRED not in obj
        or not obj[schema_keys.JSON_SCHEMA_REQUIRED].is_array()
    ):
        return False
    ref arr = obj[schema_keys.JSON_SCHEMA_REQUIRED].array()
    for ref required_item in arr:
        if required_item.is_string() and required_item.string() == prop_key:
            return True
    return False


def _parse_yang_must_list(ref xy: Value) raises -> List[Arc[ast.YangMust]]:
    """Extract a list of YangMust constraints from an x-yang object."""
    var must_list = List[Arc[ast.YangMust]]()
    if (
        schema_keys.XYANG_MUST not in xy.object()
        or not xy.object()[schema_keys.XYANG_MUST].is_array()
    ):
        return must_list^

    ref marr = xy.object()[schema_keys.XYANG_MUST].array()
    for ref must_item in marr:
        if not must_item.is_object():
            continue
        ref mobj = must_item.object()
        var expr = ""
        var errmsg = ""
        var desc = ""
        if (
            schema_keys.XYANG_MUST_EXPR in mobj
            and mobj[schema_keys.XYANG_MUST_EXPR].is_string()
        ):
            expr = mobj[schema_keys.XYANG_MUST_EXPR].string()
        if (
            schema_keys.XYANG_ERROR_MESSAGE in mobj
            and mobj[schema_keys.XYANG_ERROR_MESSAGE].is_string()
        ):
            errmsg = mobj[schema_keys.XYANG_ERROR_MESSAGE].string()
        if (
            schema_keys.JSON_SCHEMA_DESCRIPTION in mobj
            and mobj[schema_keys.JSON_SCHEMA_DESCRIPTION].is_string()
        ):
            desc = mobj[schema_keys.JSON_SCHEMA_DESCRIPTION].string()

        # Parse the must expression; YangMust only exists when parse_xpath succeeds.
        var ptr = parse_xpath(expr)
        must_list.append(Arc[ast.YangMust](
            ast.YangMust(
                expression = expr,
                error_message = errmsg,
                description = desc,
                xpath_ast = ptr,
            ),
        ))
    return must_list^


def _parse_yang_when(ref xy: Value) raises -> Optional[ast.YangWhen]:
    if schema_keys.XYANG_WHEN not in xy.object():
        return Optional[ast.YangWhen]()
    ref when_val = xy.object()[schema_keys.XYANG_WHEN]
    var expr = ""
    var desc = ""
    if when_val.is_string():
        expr = when_val.string()
    elif when_val.is_object():
        ref wo = when_val.object()
        if (
            schema_keys.XYANG_WHEN_CONDITION in wo
            and wo[schema_keys.XYANG_WHEN_CONDITION].is_string()
        ):
            expr = wo[schema_keys.XYANG_WHEN_CONDITION].string()
        if (
            schema_keys.JSON_SCHEMA_DESCRIPTION in wo
            and wo[schema_keys.JSON_SCHEMA_DESCRIPTION].is_string()
        ):
            desc = wo[schema_keys.JSON_SCHEMA_DESCRIPTION].string()
    if len(expr) == 0:
        return Optional[ast.YangWhen]()
    var ptr = parse_xpath(expr)
    return Optional(
        ast.YangWhen(
            expression = expr,
            description = desc,
            xpath_ast = ptr,
        ),
    )


def _default_scalar_to_string(v: Value) -> String:
    if v.is_string():
        return v.string()
    if v.is_bool():
        return (
            yang_token.YANG_BOOL_TRUE
            if v.bool()
            else yang_token.YANG_BOOL_FALSE
        )
    if v.is_int():
        return String(v.int())
    if v.is_uint():
        return String(v.uint())
    if v.is_float():
        return String(v.float())
    return ""


def parse_yang_leaf(name: String, prop: Value, mandatory: Bool) raises -> ast.YangLeaf:
    """Parse a leaf definition from a JSON Schema property."""
    var type_stmt = _parse_type_from_schema_property(prop)
    var desc = ""
    if (
        schema_keys.JSON_SCHEMA_DESCRIPTION in prop.object()
        and prop.object()[schema_keys.JSON_SCHEMA_DESCRIPTION].is_string()
    ):
        desc = prop.object()[schema_keys.JSON_SCHEMA_DESCRIPTION].string()
    var must_list = List[Arc[ast.YangMust]]()
    var when = Optional[ast.YangWhen]()
    var has_default = False
    var default_value = ""
    if (
        schema_keys.JSON_SCHEMA_X_YANG in prop.object()
        and prop.object()[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        ref xy = prop.object()[schema_keys.JSON_SCHEMA_X_YANG]
        must_list = _parse_yang_must_list(xy)
        when = _parse_yang_when(xy)
    if schema_keys.JSON_SCHEMA_DEFAULT in prop.object():
        ref dv = prop.object()[schema_keys.JSON_SCHEMA_DEFAULT]
        default_value = _default_scalar_to_string(dv)
        has_default = len(default_value) > 0
    return ast.YangLeaf(
        name = name,
        description = desc,
        type = type_stmt^,
        mandatory = mandatory,
        has_default = has_default,
        default_value = default_value,
        must = ast.YangMustStatements(must_statements = must_list^),
        when = when^,
    )


def parse_yang_leaf_list(name: String, prop: Value) raises -> ast.YangLeafList:
    var type_stmt = _parse_type_from_schema_property(prop)
    var desc = ""
    if (
        schema_keys.JSON_SCHEMA_DESCRIPTION in prop.object()
        and prop.object()[schema_keys.JSON_SCHEMA_DESCRIPTION].is_string()
    ):
        desc = prop.object()[schema_keys.JSON_SCHEMA_DESCRIPTION].string()
    var must_list = List[Arc[ast.YangMust]]()
    var when = Optional[ast.YangWhen]()
    var default_values = List[String]()
    var min_e = -1
    var max_e = -1
    var ob = ""
    ref po = prop.object()
    if schema_keys.JSON_SCHEMA_MIN_ITEMS in po:
        min_e = Int(po[schema_keys.JSON_SCHEMA_MIN_ITEMS].int())
    if schema_keys.JSON_SCHEMA_MAX_ITEMS in po:
        max_e = Int(po[schema_keys.JSON_SCHEMA_MAX_ITEMS].int())
    if (
        schema_keys.JSON_SCHEMA_X_YANG in po
        and po[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        ref xy = po[schema_keys.JSON_SCHEMA_X_YANG]
        must_list = _parse_yang_must_list(xy)
        if (
            schema_keys.XYANG_ORDERED_BY in xy.object()
            and xy[schema_keys.XYANG_ORDERED_BY].is_string()
        ):
            ob = xy[schema_keys.XYANG_ORDERED_BY].string()
    if schema_keys.JSON_SCHEMA_DEFAULT in prop.object():
        ref default_val = prop.object()[schema_keys.JSON_SCHEMA_DEFAULT]
        if default_val.is_array():
            ref default_arr = default_val.array()
            for ref default_item in default_arr:
                var text = _default_scalar_to_string(default_item)
                if len(text) > 0:
                    default_values.append(text)
        else:
            var text = _default_scalar_to_string(default_val)
            if len(text) > 0:
                default_values.append(text)
    return ast.YangLeafList(
        name = name,
        description = desc,
        type = type_stmt^,
        default_values = default_values^,
        must = ast.YangMustStatements(must_statements = must_list^),
        when = when^,
        min_elements = min_e,
        max_elements = max_e,
        ordered_by = ob,
    )


def parse_yang_anydata(name: String, prop: Value, mandatory: Bool) raises -> ast.YangAnydata:
    var desc = ""
    if schema_keys.JSON_SCHEMA_DESCRIPTION in prop.object():
        desc = prop.object()[schema_keys.JSON_SCHEMA_DESCRIPTION].string()
    var must_list = List[Arc[ast.YangMust]]()
    var when = Optional[ast.YangWhen]()
    if (
        schema_keys.JSON_SCHEMA_X_YANG in prop.object()
        and prop.object()[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        ref xy = prop.object()[schema_keys.JSON_SCHEMA_X_YANG]
        must_list = _parse_yang_must_list(xy)
        when = _parse_yang_when(xy)
    return ast.YangAnydata(
        name = name,
        description = desc^,
        mandatory = mandatory,
        must = ast.YangMustStatements(must_statements = must_list^),
        when = when^,
    )


def parse_yang_anyxml(name: String, prop: Value, mandatory: Bool) raises -> ast.YangAnyxml:
    var desc = ""
    if schema_keys.JSON_SCHEMA_DESCRIPTION in prop.object():
        desc = prop.object()[schema_keys.JSON_SCHEMA_DESCRIPTION].string()
    var must_list = List[Arc[ast.YangMust]]()
    var when = Optional[ast.YangWhen]()
    if (
        schema_keys.JSON_SCHEMA_X_YANG in prop.object()
        and prop.object()[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        ref xy = prop.object()[schema_keys.JSON_SCHEMA_X_YANG]
        must_list = _parse_yang_must_list(xy)
        when = _parse_yang_when(xy)
    return ast.YangAnyxml(
        name = name,
        description = desc^,
        mandatory = mandatory,
        must = ast.YangMustStatements(must_statements = must_list^),
        when = when^,
    )


def _mandatory_from_schema(prop_key: String, child: Value, parent_prop: Value) raises -> Bool:
    if _is_required(prop_key, parent_prop):
        return True
    if (
        schema_keys.JSON_SCHEMA_X_YANG in child.object()
        and child.object()[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        ref xy = child.object()[schema_keys.JSON_SCHEMA_X_YANG]
        if schema_keys.XYANG_MANDATORY in xy.object() and xy.object()[schema_keys.XYANG_MANDATORY].is_bool():
            return xy.object()[schema_keys.XYANG_MANDATORY].bool()
    return False

def _parse_node_children(
    parent_prop: Value,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut anydatas: List[Arc[ast.YangAnydata]],
    mut anyxmls: List[Arc[ast.YangAnyxml]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) raises:
    """Parse properties of a container or list-items schema; appends into the given lists."""
    if schema_keys.JSON_SCHEMA_PROPERTIES not in parent_prop.object():
        return

    ref props_obj = parent_prop.object()[schema_keys.JSON_SCHEMA_PROPERTIES].object()
    for ref pair in props_obj.items():
        ref child = pair.value
        var kind = ""
        if schema_keys.JSON_SCHEMA_X_YANG in child.object():
            kind = child.object()[schema_keys.JSON_SCHEMA_X_YANG][
                schema_keys.XYANG_TYPE
            ].string()

        if kind == yang_token.YANG_STMT_CONTAINER:
            var yc = parse_yang_container(pair.key, child)
            containers.append(Arc[ast.YangContainer](yc^))
        elif kind == yang_token.YANG_STMT_ANYDATA:
            var m = _mandatory_from_schema(pair.key, child, parent_prop)
            var ya = parse_yang_anydata(pair.key, child, m)
            anydatas.append(Arc[ast.YangAnydata](ya^))
        elif kind == yang_token.YANG_STMT_ANYXML:
            var m = _mandatory_from_schema(pair.key, child, parent_prop)
            var yx = parse_yang_anyxml(pair.key, child, m)
            anyxmls.append(Arc[ast.YangAnyxml](yx^))
        elif kind == yang_token.YANG_STMT_LEAF or kind == yang_token.YANG_TYPE_LEAFREF:
            var mandatory = _mandatory_from_schema(pair.key, child, parent_prop)
            var yl = parse_yang_leaf(pair.key, child, mandatory)
            leaves.append(Arc[ast.YangLeaf](yl^))
        elif kind == yang_token.YANG_STMT_LEAF_LIST:
            var yll = parse_yang_leaf_list(pair.key, child)
            leaf_lists.append(Arc[ast.YangLeafList](yll^))
        elif kind == yang_token.YANG_STMT_LIST:
            var yl = parse_yang_list(pair.key, child)
            lists.append(Arc[ast.YangList](yl^))
        elif kind == yang_token.YANG_STMT_CHOICE:
            var ych = parse_yang_choice(pair.key, child)
            choices.append(Arc[ast.YangChoice](ych^))


def parse_yang_choice(name: String, prop: Value) raises -> ast.YangChoice:
    """Parse a choice definition from a JSON Schema property (oneOf)."""
    var mandatory = False
    var default_case = ""
    var choice_description = ""
    var ch_when = Optional[ast.YangWhen]()
    ref po = prop.object()
    if (
        schema_keys.JSON_SCHEMA_DESCRIPTION in po
        and po[schema_keys.JSON_SCHEMA_DESCRIPTION].is_string()
    ):
        choice_description = po[schema_keys.JSON_SCHEMA_DESCRIPTION].string()
    if (
        schema_keys.JSON_SCHEMA_X_YANG in po
        and po[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        ref xy = po[schema_keys.JSON_SCHEMA_X_YANG]
        if schema_keys.XYANG_MANDATORY in xy:
            mandatory = xy[schema_keys.XYANG_MANDATORY].bool()
        if (
            schema_keys.XYANG_DEFAULT in xy
            and xy[schema_keys.XYANG_DEFAULT].is_string()
        ):
            default_case = xy[schema_keys.XYANG_DEFAULT].string()
        ch_when = _parse_yang_when(po[schema_keys.JSON_SCHEMA_X_YANG])

    var case_names = List[String]()
    var cases = List[Arc[ast.YangChoiceCase]]()
    if (
        schema_keys.JSON_SCHEMA_ONE_OF in po
        and po[schema_keys.JSON_SCHEMA_ONE_OF].is_array()
    ):
        ref one_of = po[schema_keys.JSON_SCHEMA_ONE_OF].array()
        var case_idx = 0
        for ref one_of_branch in one_of:
            ref branch = one_of_branch.object()
            var case_name = "case-" + String(case_idx)
            var node_names = List[String]()
            var case_when = Optional[ast.YangWhen]()
            var case_description = ""
            if (
                schema_keys.JSON_SCHEMA_DESCRIPTION in branch
                and branch[schema_keys.JSON_SCHEMA_DESCRIPTION].is_string()
            ):
                case_description = branch[
                    schema_keys.JSON_SCHEMA_DESCRIPTION
                ].string()
            if (
                schema_keys.JSON_SCHEMA_X_YANG in branch
                and branch[schema_keys.JSON_SCHEMA_X_YANG].is_object()
            ):
                case_when = _parse_yang_when(
                    branch[schema_keys.JSON_SCHEMA_X_YANG],
                )
            if (
                schema_keys.JSON_SCHEMA_REQUIRED in branch
                and branch[schema_keys.JSON_SCHEMA_REQUIRED].is_array()
            ):
                ref req = branch[schema_keys.JSON_SCHEMA_REQUIRED].array()
                if len(req) > 0:
                    for ref req_item in req:
                        if req_item.is_string():
                            var n = req_item.string()
                            node_names.append(n)
                            case_names.append(n)
                    if len(node_names) > 0:
                        case_name = node_names[0]
            elif schema_keys.JSON_SCHEMA_PROPERTIES in branch:
                ref branch_props = branch[schema_keys.JSON_SCHEMA_PROPERTIES].object()
                for ref p in branch_props.items():
                    node_names.append(p.key)
                    case_names.append(p.key)
                if len(node_names) > 0:
                    case_name = node_names[0]
            cases.append(
                Arc[ast.YangChoiceCase](
                    ast.YangChoiceCase(
                        name=case_name,
                        description=case_description^,
                        node_names=node_names^,
                        when=case_when^,
                    ),
                ),
            )
            case_idx += 1
    return ast.YangChoice(
        name=name,
        description=choice_description^,
        mandatory=mandatory,
        default_case=default_case,
        case_names=case_names^,
        cases=cases^,
        when=ch_when^,
    )


def parse_yang_list(name: String, prop: Value) raises -> ast.YangList:
    """Parse a list definition from a JSON Schema property (array with items)."""
    var description = ""
    if schema_keys.JSON_SCHEMA_DESCRIPTION in prop.object():
        description = prop.object()[schema_keys.JSON_SCHEMA_DESCRIPTION].string()

    var key = ""
    var min_e = -1
    var max_e = -1
    var ob = ""
    var unique_specs = List[List[String]]()
    var must_list = List[Arc[ast.YangMust]]()
    ref po = prop.object()
    if (
        schema_keys.JSON_SCHEMA_X_YANG in po
        and po[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        ref xy = po[schema_keys.JSON_SCHEMA_X_YANG]
        must_list = _parse_yang_must_list(xy)
        if schema_keys.XYANG_KEY in xy:
            key = xy[schema_keys.XYANG_KEY].string()
        if (
            schema_keys.XYANG_ORDERED_BY in xy
            and xy[schema_keys.XYANG_ORDERED_BY].is_string()
        ):
            ob = xy[schema_keys.XYANG_ORDERED_BY].string()
        if schema_keys.XYANG_UNIQUE in xy and xy[schema_keys.XYANG_UNIQUE].is_array():
            ref uarr = xy[schema_keys.XYANG_UNIQUE].array()
            for ref uv in uarr:
                var spec = List[String]()
                if uv.is_array():
                    ref inner = uv.array()
                    for ref inner_item in inner:
                        if inner_item.is_string():
                            spec.append(inner_item.string())
                elif uv.is_string():
                    var raw = uv.string().split()
                    for ref raw_item in raw:
                        var seg = String(String(raw_item).strip())
                        if len(seg) > 0:
                            spec.append(seg^)
                if len(spec) > 0:
                    unique_specs.append(spec^)
    if schema_keys.JSON_SCHEMA_MIN_ITEMS in po:
        min_e = Int(po[schema_keys.JSON_SCHEMA_MIN_ITEMS].int())
    if schema_keys.JSON_SCHEMA_MAX_ITEMS in po:
        max_e = Int(po[schema_keys.JSON_SCHEMA_MAX_ITEMS].int())
    var leaves = List[Arc[ast.YangLeaf]]()
    var leaf_lists = List[Arc[ast.YangLeafList]]()
    var anydatas_real = List[Arc[ast.YangAnydata]]()
    var anyxmls = List[Arc[ast.YangAnyxml]]()
    var containers = List[Arc[ast.YangContainer]]()
    var lists = List[Arc[ast.YangList]]()
    var choices = List[Arc[ast.YangChoice]]()

    if (
        schema_keys.JSON_SCHEMA_ITEMS in po
        and po[schema_keys.JSON_SCHEMA_ITEMS].is_object()
    ):
        _parse_node_children(
            po[schema_keys.JSON_SCHEMA_ITEMS],
            leaves,
            leaf_lists,
            anydatas_real,
            anyxmls,
            containers,
            lists,
            choices,
        )
    return ast.YangList(
        name = name,
        key = key,
        description = description,
        must = ast.YangMustStatements(must_statements = must_list^),
        children = ast.pack_yang_list_child_buckets(
            ast.YangListChildBuckets(
                leaves = leaves^,
                leaf_lists = leaf_lists^,
                anydatas = anydatas_real^,
                anyxmls = anyxmls^,
                containers = containers^,
                lists = lists^,
                choices = choices^,
            ),
        ),
        min_elements = min_e,
        max_elements = max_e,
        ordered_by = ob,
        unique_specs = unique_specs^,
    )


def parse_yang_container(name: String, prop: Value) raises -> ast.YangContainer:
    """Parse a container definition from a JSON Schema property, including its properties."""
    var description = ""
    if schema_keys.JSON_SCHEMA_DESCRIPTION in prop.object():
        description = prop.object()[schema_keys.JSON_SCHEMA_DESCRIPTION].string()
    var must_list = List[Arc[ast.YangMust]]()
    if (
        schema_keys.JSON_SCHEMA_X_YANG in prop.object()
        and prop.object()[schema_keys.JSON_SCHEMA_X_YANG].is_object()
    ):
        must_list = _parse_yang_must_list(
            prop.object()[schema_keys.JSON_SCHEMA_X_YANG],
        )

    var leaves = List[Arc[ast.YangLeaf]]()
    var leaf_lists = List[Arc[ast.YangLeafList]]()
    var anydatas = List[Arc[ast.YangAnydata]]()
    var anyxmls = List[Arc[ast.YangAnyxml]]()
    var containers = List[Arc[ast.YangContainer]]()
    var lists = List[Arc[ast.YangList]]()
    var choices = List[Arc[ast.YangChoice]]()
    _parse_node_children(prop, leaves, leaf_lists, anydatas, anyxmls, containers, lists, choices)
    return ast.YangContainer(
        name = name,
        description = description,
        must = ast.YangMustStatements(must_statements = must_list^),
        leaves = leaves^,
        leaf_lists = leaf_lists^,
        anydatas = anydatas^,
        anyxmls = anyxmls^,
        containers = containers^,
        lists = lists^,
        choices = choices^,
    )


def parse_json_schema(source: String) raises -> ast.YangModule:
    ## Backward-compatible alias used by package exports.
    return parse_yang_module(source)

