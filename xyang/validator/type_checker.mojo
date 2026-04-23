## Type checker for YANG document validation.
## Checks a data value (EmberJson Value) against a YangType; returns list of error message strings.

from emberjson import Value
from xyang.ast import YangType
from xyang.yang.tokens import YANG_TYPE_LEAFREF
from std.memory import ArcPointer
from xyang.xpath import (
    XPathNode,
    EvalContext,
    XPathEvaluator,
)
from xyang.xpath.pratt_parser import Expr

comptime Arc = ArcPointer


@fieldwise_init
struct IntegerTypeBounds(Copyable, Movable):
    """Per-type min/max flags for fixed-width integers (int64/integer: not in table)."""
    var has_min: Bool
    var has_max: Bool
    var min_v: Int64
    var max_v: Int64


def make_integer_type_bounds_table() -> Dict[String, IntegerTypeBounds]:
    var d = Dict[String, IntegerTypeBounds]()
    d["uint8"] = IntegerTypeBounds(True, True, 0, 255)
    d["uint16"] = IntegerTypeBounds(True, True, 0, 65535)
    d["uint32"] = IntegerTypeBounds(True, True, 0, 4294967295)
    d["uint64"] = IntegerTypeBounds(True, False, 0, 0)
    d["int8"] = IntegerTypeBounds(True, True, -128, 127)
    d["int16"] = IntegerTypeBounds(True, True, -32768, 32767)
    d["int32"] = IntegerTypeBounds(True, True, -2147483648, 2147483647)
    return d^


def _check_string_type(val: Value) -> List[String]:
    """Return error messages if val is not a valid string type."""
    if val.is_string():
        return List[String]()
    if val.is_null():
        return List[String]()  # absent is handled by structural (mandatory)
    var errs = List[String]()
    errs.append("Expected string, got non-string value")
    return errs^

def _check_integer_type(val: Value) -> List[String]:
    if val.is_int() or val.is_uint():
        return List[String]()
    if val.is_null():
        return List[String]()
    var errs = List[String]()
    if val.is_string():
        errs.append("Expected integer, got string")
    else:
        errs.append("Expected integer, got non-numeric value")
    return errs^


def _check_integer_bounds(
    val: Value, type_stmt: YangType, read bounds: Dict[String, IntegerTypeBounds]
) -> List[String]:
    if val.is_null():
        return List[String]()
    if not val.is_int() and not val.is_uint():
        return List[String]()

    var errs = List[String]()
    var n = Int64(val.uint())
    if val.is_int():
        n = val.int()

    var has_min = False
    var has_max = False
    var min_v = Int64(0)
    var max_v = Int64(0)
    var name = type_stmt.name

    var bopt = bounds.get(name)
    if bopt:
        var b = bopt.value().copy()
        has_min = b.has_min
        has_max = b.has_max
        min_v = b.min_v
        max_v = b.max_v
    # int64 / plain "integer": no table entry — unconstrained until explicit Int64 bounds.

    if type_stmt.has_range:
        if not has_min or type_stmt.range_min > min_v:
            min_v = type_stmt.range_min
            has_min = True
        if not has_max or type_stmt.range_max < max_v:
            max_v = type_stmt.range_max
            has_max = True

    if has_min and n < min_v:
        errs.append(
            "Expected "
            + name
            + " >= "
            + String(min_v)
            + ", got "
            + String(n),
        )
    if has_max and n > max_v:
        errs.append(
            "Expected "
            + name
            + " <= "
            + String(max_v)
            + ", got "
            + String(n),
        )
    return errs^

def _check_boolean_type(val: Value) -> List[String]:
    if val.is_bool():
        return List[String]()
    if val.is_null():
        return List[String]()
    var errs = List[String]()
    errs.append("Expected boolean, got non-boolean value")
    return errs^

def _check_array_type(val: Value) -> List[String]:
    if val.is_array():
        return List[String]()
    if val.is_null():
        return List[String]()
    var errs = List[String]()
    errs.append("Expected array, got non-array value")
    return errs^

def _check_object_type(val: Value) -> List[String]:
    if val.is_object():
        return List[String]()
    if val.is_null():
        return List[String]()
    var errs = List[String]()
    errs.append("Expected object, got non-object value")
    return errs^


def _check_leafref_type(val: Value) -> List[String]:
    """Leafref may point to any scalar leaf type; reject non-scalars."""
    if val.is_string() or val.is_int() or val.is_uint() or val.is_float() or val.is_bool():
        return List[String]()
    if val.is_null():
        return List[String]()
    var errs = List[String]()
    errs.append("Expected scalar leafref value, got non-scalar value")
    return errs^


def _normalize_leafref_segment(seg: String) -> String:
    var trimmed = String(seg.strip())
    var parts = trimmed.split("[")
    if len(parts) == 0:
        return trimmed
    return String(String(parts[0]).strip())


def _leafref_step(read nodes: List[Value], segment: String) raises -> List[Value]:
    var out = List[Value]()
    var seg = _normalize_leafref_segment(segment)
    if len(seg) == 0:
        return out^
    for i in range(len(nodes)):
        ref node = nodes[i]
        if node.is_array():
            ref arr = node.array()
            for j in range(len(arr)):
                ref item = arr[j]
                if item.is_object():
                    ref o = item.object()
                    if seg in o:
                        out.append(o[seg].copy())
        elif node.is_object():
            ref o = node.object()
            if seg in o:
                out.append(o[seg].copy())
    return out^


def _resolve_values_for_xpath_path(path_expr: String, root: Value) raises -> List[Value]:
    var nodes = List[Value]()
    nodes.append(root.copy())
    var parts = path_expr.split("/")
    for i in range(len(parts)):
        var seg = _normalize_leafref_segment(String(String(parts[i]).strip()))
        if len(seg) == 0 or seg == ".":
            continue
        if seg == "..":
            return List[Value]()
        nodes = _leafref_step(nodes, seg)
    return nodes^


def _scalar_value_equal(ref a: Value, ref b: Value) -> Bool:
    if a.is_string() and b.is_string():
        return a.string() == b.string()
    if a.is_bool() and b.is_bool():
        return a.bool() == b.bool()
    if a.is_int():
        var av = a.int()
        if b.is_int():
            return av == b.int()
        if b.is_uint():
            if av < 0:
                return False
            return av == Int64(b.uint())
        if b.is_float():
            return Float64(av) == b.float()
        return False
    if a.is_uint():
        var av = a.uint()
        if b.is_uint():
            return av == b.uint()
        if b.is_int():
            var bv = b.int()
            if bv < 0:
                return False
            return Int64(av) == bv
        if b.is_float():
            return Float64(av) == b.float()
        return False
    if a.is_float():
        var av = a.float()
        if b.is_float():
            return av == b.float()
        if b.is_int():
            return av == Float64(b.int())
        if b.is_uint():
            return av == Float64(b.uint())
        return False
    return False


def _eval_leafref_target_paths(path_ast: Expr.ExprPointer, path_expr: String, current_path: String) raises -> List[String]:
    var paths = List[String]()
    var expr = String(path_expr.strip())
    if len(expr) == 0 or not path_ast:
        return paths^
    var root_node = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root_node^)
    var current_node = XPathNode(current_path, current_path)
    var current_arc = Arc[XPathNode](current_node^)
    var ctx = EvalContext(current_arc, root_arc, expr)
    var ev = XPathEvaluator()
    try:
        var result = ev.eval(path_ast, ctx, current_arc)
        if result.isa[List[Arc[XPathNode]]]():
            ref nodes = result[List[Arc[XPathNode]]]
            for i in range(len(nodes)):
                paths.append(nodes[i][].path)
    except:
        paths = List[String]()
    return paths^


def check_leafref_reference(
    val: Value,
    type_stmt: YangType,
    node_path: String,
    root_data: Value,
) raises -> List[String]:
    """Python-style leafref require-instance check in type checker."""
    if type_stmt.name != YANG_TYPE_LEAFREF or not type_stmt.leafref_require_instance:
        return List[String]()
    if not type_stmt.has_leafref_path or len(type_stmt.leafref_path) == 0:
        var errs = List[String]()
        errs.append("Leafref is missing required path metadata")
        return errs^
    if not type_stmt.leafref_path_parsed or not type_stmt.leafref_xpath_ast:
        var errs = List[String]()
        errs.append("Leafref path expression could not be parsed")
        return errs^
    var target_paths = _eval_leafref_target_paths(
        type_stmt.leafref_xpath_ast,
        type_stmt.leafref_path,
        node_path,
    )
    for i in range(len(target_paths)):
        var targets = _resolve_values_for_xpath_path(target_paths[i], root_data)
        for j in range(len(targets)):
            if _scalar_value_equal(targets[j], val):
                return List[String]()
    var errs = List[String]()
    errs.append(
        "Leafref value does not resolve to any target for path '" + type_stmt.leafref_path + "'"
    )
    return errs^

def check_leaf_value(
    val: Value,
    type_stmt: YangType,
    path: String,
    read integer_bounds: Dict[String, IntegerTypeBounds],
) -> List[String]:
    """
    Check a leaf value against a YANG type (by name).
    Returns list of error messages (empty = valid).
    """
    var name = type_stmt.name
    # String-like types
    if name == "string" or name == "entity-name" or name == "field-name" or name == "identifier":
        return _check_string_type(val)
    if name == "date" or name == "date-and-time" or name == "qualified-source" or name == "version-string":
        return _check_string_type(val)
    # Numeric (shared fixed-width bounds table)
    if (
        name == "integer"
        or name == "int8"
        or name == "int16"
        or name == "int32"
        or name == "int64"
        or name == "uint8"
        or name == "uint16"
        or name == "uint32"
        or name == "uint64"
    ):
        var errs = _check_integer_type(val)
        if len(errs) > 0:
            return errs^
        return _check_integer_bounds(val, type_stmt, integer_bounds)
    # Other
    if name == "boolean":
        return _check_boolean_type(val)
    if name == "object":
        return _check_object_type(val)
    if name == "array":
        return _check_array_type(val)
    if name == YANG_TYPE_LEAFREF:
        return _check_leafref_type(val)
    # Unknown / typedef names: treat as string for now
    return _check_string_type(val)
