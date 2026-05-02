## Argument validators for table-driven YANG construct validation.
##
## Includes RFC 7950 §9.4 (`length`, `pattern`, `modifier`) argument checks.

from std.collections import List
from std.utils import Variant


struct NoArgument(Copyable, ImplicitlyCopyable, Movable):
    def __init__(out self):
        pass


@fieldwise_init
struct RawArgument(Movable):
    var text: String


@fieldwise_init
struct StringArgument(Movable):
    var text: String


@fieldwise_init
struct IdentifierArgument(Movable):
    var text: String


@fieldwise_init
struct QNameArgument(Movable):
    var text: String
    var prefix: Optional[String]
    var local_name: String


@fieldwise_init
struct PathArgument(Movable):
    var text: String


@fieldwise_init
struct XPathExpressionArgument(Movable):
    var text: String


@fieldwise_init
struct RevisionDateArgument(Movable):
    var text: String


@fieldwise_init
struct RangeArgument(Movable):
    var text: String


@fieldwise_init
struct LengthArgument(Movable):
    var text: String


@fieldwise_init
struct PatternArgument(Movable):
    var text: String


@fieldwise_init
struct ModifierArgument(Movable):
    var text: String


@fieldwise_init
struct FractionDigitsArgument(Copyable, ImplicitlyCopyable, Movable):
    var value: Int


@fieldwise_init
struct TypeNameArgument(Movable):
    var text: String


@fieldwise_init
struct BoolArgument(Copyable, ImplicitlyCopyable, Movable):
    var value: Bool


comptime YangArgument = Variant[
    NoArgument,
    RawArgument,
    StringArgument,
    IdentifierArgument,
    QNameArgument,
    PathArgument,
    XPathExpressionArgument,
    RevisionDateArgument,
    RangeArgument,
    LengthArgument,
    PatternArgument,
    ModifierArgument,
    FractionDigitsArgument,
    TypeNameArgument,
    BoolArgument,
]


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

