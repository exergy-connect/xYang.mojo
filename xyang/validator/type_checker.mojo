## Type checker for YANG document validation.
## Checks a data value (EmberJson Value) against a YangType; returns list of error message strings.

from emberjson import Value
from xyang.ast import YangType, YangLeaf

def _check_string_type(val: Value) -> List[String]:
    """Return error messages if val is not a valid string type."""
    var errs = List[String]()
    if val.is_string():
        return errs.copy()
    if val.is_null():
        return errs.copy()  # absent is handled by structural (mandatory)
    errs.append("Expected string, got non-string value")
    return errs.copy()

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
    return errs.copy()

def _check_boolean_type(val: Value) -> List[String]:
    if val.is_bool():
        return List[String]()
    if val.is_null():
        return List[String]()
    var errs = List[String]()
    errs.append("Expected boolean, got non-boolean value")
    return errs.copy()

def _check_array_type(val: Value) -> List[String]:
    if val.is_array():
        return List[String]()
    if val.is_null():
        return List[String]()
    var errs = List[String]()
    errs.append("Expected array, got non-array value")
    return errs.copy()

def _check_object_type(val: Value) -> List[String]:
    if val.is_object():
        return List[String]()
    if val.is_null():
        return List[String]()
    var errs = List[String]()
    errs.append("Expected object, got non-object value")
    return errs.copy()

def check_leaf_value(val: Value, type_stmt: YangType, path: String) -> List[String]:
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
    # Numeric
    if name == "integer" or name == "int8" or name == "int16" or name == "int32" or name == "int64":
        return _check_integer_type(val)
    if name == "uint8" or name == "uint16" or name == "uint32" or name == "uint64":
        return _check_integer_type(val)
    # Other
    if name == "boolean":
        return _check_boolean_type(val)
    if name == "object":
        return _check_object_type(val)
    if name == "array":
        return _check_array_type(val)
    # Unknown / typedef names: treat as string for now
    return _check_string_type(val)
