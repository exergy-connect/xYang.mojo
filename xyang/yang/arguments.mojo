## Argument validators for table-driven YANG construct validation.

from xyang.yang.identifiers import (
    is_identifier,
    is_qname,
    is_revision_date,
    is_supported_type_name,
)


comptime ArgumentValidator = def(
    name: String, argument: String, line: Int
) raises thin -> None


@fieldwise_init
struct RangeBounds(Copyable, ImplicitlyCopyable, Movable):
    var lo: Int64
    var hi: Int64


def try_parse_range_bounds(read argument: String) raises -> Optional[RangeBounds]:
    var parts = argument.split("..")
    if len(parts) != 2:
        return Optional[RangeBounds]()
    var lo = Int64(atol(String(parts[0]).strip()))
    var hi = Int64(atol(String(parts[1]).strip()))
    return Optional[RangeBounds](RangeBounds(lo, hi))


def validate_yang_any(name: String, argument: String, line: Int) raises -> None:
    return


def validate_yang_string(
    name: String, argument: String, line: Int
) raises -> None:
    return


def validate_yang_identifier(
    name: String, argument: String, line: Int
) raises -> None:
    if not is_identifier(argument):
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected identifier argument"
        )


def validate_yang_qname(
    name: String, argument: String, line: Int
) raises -> None:
    if not is_qname(argument):
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected identifier or prefixed identifier"
        )


def validate_yang_version(
    name: String, argument: String, line: Int
) raises -> None:
    if argument != "1" and argument != "1.1":
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected YANG version 1 or 1.1"
        )


def validate_yang_revision_date(
    name: String, argument: String, line: Int
) raises -> None:
    if not is_revision_date(argument):
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected revision date YYYY-MM-DD"
        )


def validate_yang_range(
    name: String, argument: String, line: Int
) raises -> None:
    var parsed = try_parse_range_bounds(argument)
    if not parsed:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected basic range expression"
        )


def validate_yang_path(
    name: String, argument: String, line: Int
) raises -> None:
    if argument.byte_length() == 0:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected non-empty path"
        )


def validate_yang_type_name(
    name: String, argument: String, line: Int
) raises -> None:
    if not is_supported_type_name(argument):
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected basic YANG type name"
        )


def validate_yang_expression(
    name: String, argument: String, line: Int
) raises -> None:
    if argument.byte_length() == 0:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected non-empty expression"
        )


def validate_yang_bool(
    name: String, argument: String, line: Int
) raises -> None:
    if argument != "true" and argument != "false":
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` expected boolean argument"
        )
