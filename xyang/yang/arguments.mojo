## Argument validators for table-driven YANG construct validation.
##
## Includes RFC 7950 §9.4 (`length`, `pattern`, `modifier`) argument checks.

from std.collections import List

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


## One inclusive segment from a `length` argument (RFC 7950 §9.4.4).
@fieldwise_init
struct LengthSegment(Copyable, ImplicitlyCopyable, Movable):
    var lo: Int64
    var hi: Int64


## One `pattern` substatement plus optional `invert-match` (§9.4.5–9.4.6).
@fieldwise_init
struct YangPatternSpec(Copyable, ImplicitlyCopyable, Movable):
    var regex: String
    var invert: Bool


comptime _LENGTH_MAX: Int64 = 9223372036854775807


def _line_prefix(line: Int) -> String:
    if line > 0:
        return "line " + String(line) + ": "
    return ""


def _strip_spaces(read s: String) -> String:
    var parts = s.split(" ")
    var out = String()
    for i in range(len(parts)):
        var p = String(parts[i])
        if p.byte_length() > 0:
            out += p
    return out^


def _length_lower_bound(read tok: String, line: Int) raises -> Int64:
    var t = _strip_spaces(tok)
    if t == "min":
        return 0
    if t == "max":
        raise Error(
            _line_prefix(line) + "`length` `max` cannot be a lower bound"
        )
    if t.byte_length() == 0:
        raise Error(_line_prefix(line) + "`length` empty lower bound")
    var n = Int64(atol(t))
    if n < 0:
        raise Error(
            _line_prefix(line) + "`length` lower bound must be non-negative"
        )
    return n


def _length_upper_bound(read tok: String, line: Int) raises -> Int64:
    var t = _strip_spaces(tok)
    if t == "max":
        return _LENGTH_MAX
    if t == "min":
        raise Error(
            _line_prefix(line) + "`length` `min` cannot be an upper bound"
        )
    if t.byte_length() == 0:
        raise Error(_line_prefix(line) + "`length` empty upper bound")
    var n = Int64(atol(t))
    if n < 0:
        raise Error(
            _line_prefix(line) + "`length` upper bound must be non-negative"
        )
    return n


def try_parse_length_segments(
    read argument: String, line: Int
) raises -> List[LengthSegment]:
    ## Parse RFC 7950 `length-arg` (§9.4.4, ABNF `length-arg` in §14).
    var out = List[LengthSegment]()
    var norm = _strip_spaces(argument)
    if norm.byte_length() == 0:
        raise Error(_line_prefix(line) + "`length` expected non-empty argument")
    var raw_parts = norm.split("|")
    for i in range(len(raw_parts)):
        var part = _strip_spaces(String(raw_parts[i]))
        if part.byte_length() == 0:
            raise Error(_line_prefix(line) + "`length` empty `|` segment")
        var dots = part.split("..")
        var lo_b: Int64
        var hi_b: Int64
        if len(dots) == 1:
            var t = _strip_spaces(String(dots[0]))
            if t == "min" or t == "max":
                raise Error(
                    _line_prefix(line)
                    + "`length` `min` / `max` must appear inside a `..` range"
                )
            var n = Int64(atol(t))
            if n < 0:
                raise Error(
                    _line_prefix(line)
                    + "`length` explicit value must be non-negative"
                )
            lo_b = n
            hi_b = n
        elif len(dots) == 2:
            lo_b = _length_lower_bound(String(dots[0]), line)
            hi_b = _length_upper_bound(String(dots[1]), line)
            if lo_b > hi_b:
                raise Error(
                    _line_prefix(line)
                    + "`length` lower bound exceeds upper bound"
                )
        else:
            raise Error(
                _line_prefix(line) + "`length` expected at most one `..`"
            )
        out.append(LengthSegment(lo_b, hi_b))
    for i in range(1, len(out)):
        if out[i - 1].lo > out[i].lo:
            raise Error(
                _line_prefix(line)
                + "`length` segments must be in ascending order (RFC 7950"
                " §9.4.4)"
            )
        if out[i - 1].hi >= out[i].lo:
            raise Error(
                _line_prefix(line)
                + "`length` segments must be disjoint (RFC 7950 §9.4.4)"
            )
    return out^


def length_allows_scalar_count(
    read segments: List[LengthSegment], count: Int
) -> Bool:
    var c = Int64(count)
    for i in range(len(segments)):
        if c >= segments[i].lo and c <= segments[i].hi:
            return True
    return False


def try_parse_range_bounds(
    read argument: String,
) raises -> Optional[RangeBounds]:
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


def validate_yang_length(
    name: String, argument: String, line: Int
) raises -> None:
    _ = try_parse_length_segments(argument, line)


def validate_yang_pattern_arg(
    name: String, argument: String, line: Int
) raises -> None:
    if _strip_spaces(argument).byte_length() == 0:
        raise Error(
            _line_prefix(line)
            + "`"
            + name
            + "` expected non-empty XSD regular expression"
        )


def validate_yang_modifier(
    name: String, argument: String, line: Int
) raises -> None:
    if _strip_spaces(argument) != "invert-match":
        raise Error(
            _line_prefix(line)
            + "`"
            + name
            + "` expected argument `invert-match`"
        )


def validate_yang_fraction_digits(
    name: String, argument: String, line: Int
) raises -> None:
    var t = _strip_spaces(argument)
    if t.byte_length() == 0:
        raise Error(_line_prefix(line) + "`" + name + "` expected digit string")
    var n = atol(t)
    if n < 1 or n > 18:
        raise Error(
            _line_prefix(line)
            + "`"
            + name
            + "` must be between 1 and 18 (RFC 7950 §9.3)"
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
