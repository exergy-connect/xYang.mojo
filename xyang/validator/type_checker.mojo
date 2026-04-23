## Type checker for YANG document validation.
## Checks a data value (EmberJson Value) against a YangType; returns list of error message strings.

from emberjson import Value
from xyang.ast import YangType


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
    if name == "leafref":
        return _check_leafref_type(val)
    # Unknown / typedef names: treat as string for now
    return _check_string_type(val)
