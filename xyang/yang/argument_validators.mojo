## Argument validator callbacks for table-driven YANG construct validation.

from xyang.yang.arguments import (
    _line_prefix,
    _strip_spaces,
    try_parse_length_segments,
    try_parse_range_bounds,
)
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.identifiers import (
    is_identifier,
    is_qname,
    is_revision_date,
    is_supported_type_name,
)


comptime ArgumentValidator = def(mut YangConstruct) raises thin -> None


def validate_yang_any(mut node: YangConstruct) raises -> None:
    return


def validate_yang_string(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    node.set_string_argument(argument^)
    return


def validate_yang_identifier(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if not is_identifier(argument):
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected identifier argument"
        )
    node.set_identifier_argument(argument^)


def validate_yang_qname(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if not is_qname(argument):
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected identifier or prefixed identifier"
        )
    node.set_qname_argument(argument^)


def validate_yang_version(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if argument != "1" and argument != "1.1":
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected YANG version 1 or 1.1"
        )
    node.set_string_argument(argument^)


def validate_yang_revision_date(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if not is_revision_date(argument):
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected revision date YYYY-MM-DD"
        )
    node.set_revision_date_argument(argument^)


def validate_yang_range(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    var parsed = try_parse_range_bounds(argument)
    if not parsed:
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected basic range expression"
        )
    node.set_range_argument(argument^)


def validate_yang_length(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    _ = try_parse_length_segments(argument, node.line)
    node.set_length_argument(argument^)


def validate_yang_pattern_arg(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if _strip_spaces(argument).byte_length() == 0:
        raise Error(
            _line_prefix(node.line)
            + "`"
            + node.keyword
            + "` expected non-empty XSD regular expression"
        )
    node.set_pattern_argument(argument^)


def validate_yang_modifier(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if _strip_spaces(argument) != "invert-match":
        raise Error(
            _line_prefix(node.line)
            + "`"
            + node.keyword
            + "` expected argument `invert-match`"
        )
    node.set_modifier_argument(argument^)


def validate_yang_fraction_digits(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    var t = _strip_spaces(argument)
    if t.byte_length() == 0:
        raise Error(
            _line_prefix(node.line)
            + "`"
            + node.keyword
            + "` expected digit string"
        )
    var n = atol(t)
    if n < 1 or n > 18:
        raise Error(
            _line_prefix(node.line)
            + "`"
            + node.keyword
            + "` must be between 1 and 18 (RFC 7950 §9.3)"
        )
    node.set_fraction_digits_argument(Int(n))


def validate_yang_path(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if argument.byte_length() == 0:
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected non-empty path"
        )
    node.set_path_argument(argument^)


def validate_yang_type_name(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if not is_supported_type_name(argument):
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected basic YANG type name"
        )
    node.set_type_name_argument(argument^)


def validate_yang_expression(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if argument.byte_length() == 0:
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected non-empty expression"
        )
    node.set_xpath_expression_argument(argument^)


def validate_yang_bool(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if argument != "true" and argument != "false":
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected boolean argument"
        )
    node.set_bool_argument(argument == "true")
