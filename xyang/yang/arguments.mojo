## YANG statement argument types and `YangArgument::parse_and_store` for construct
## validation (table-driven specs in `spec.mojo`).
##
## Includes RFC 7950 §9.4 (`length`, `pattern`, `modifier`) argument checks.

from std.collections import List
from std.collections.string import StringSlice
from std.memory import ArcPointer
from std.utils import Variant

from xyang.yang.identifiers import (
    is_identifier,
    is_qname,
    is_revision_date,
)
from xyang.yang.path import YangPath
from xyang.yang.path import parse_yang_path
from xyang.yang.xpath.api import parse_xpath_expression
from xyang.yang.xpath.pratt_parser import XPathExpr

comptime Arc = ArcPointer


trait YangArgumentHost:
    def argument_text(read self) -> String:
        ...

    def argument_keyword(read self) -> String:
        ...

    def argument_line(read self) -> UInt:
        ...

    def update_argument[T: Movable](mut self, var inner: T):
        ...


comptime YangConstruct = Some[YangArgumentHost]


trait YangArgument:
    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        ...


def _argument_error(read node: YangConstruct, message: String) -> Error:
    return Error(
        _line_prefix(node.argument_line())
        + "`"
        + node.argument_keyword()
        + "` "
        + message
    )


struct NoArgument(Movable, YangArgument):
    def __init__(out self):
        pass

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        return


@fieldwise_init
struct StringArgument(Movable, YangArgument):
    ## Canonical string payload (e.g. description text, `yang-version` literal).
    var content: String

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        node.update_argument(StringArgument(argument.copy()))


## `yang-version` statement; stores a `StringArgument` payload (1 or 1.1).
struct YangVersionArgument(Movable, YangArgument):
    def __init__(out self):
        pass

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument != "1" and argument != "1.1":
            raise Error(
                (
                    (
                        "line " + String(node.argument_line()) + ": "
                    ) if node.argument_line()
                    > 0 else ""
                )
                + "`"
                + node.argument_keyword()
                + "` expected YANG version 1 or 1.1"
            )
        node.update_argument(StringArgument(argument.copy()))


@fieldwise_init
struct IdentifierArgument(Movable, YangArgument):
    var name: String

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if not is_identifier(argument):
            raise _argument_error(node, "expected identifier argument")
        node.update_argument(IdentifierArgument(argument.copy()))


@fieldwise_init
struct QNameArgument(Movable, YangArgument):
    ## Full `prefix:local` spelling plus parsed parts.
    var qualified_name: String
    var prefix: String
    var local_name: String

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if not is_qname(argument):
            raise _argument_error(
                node, "expected identifier or prefixed identifier"
            )
        var parts = argument.split(":")
        if len(parts) == 2:
            var prefix = String(parts[0])
            var local_name = String(parts[1])
            node.update_argument(
                QNameArgument(argument.copy(), prefix^, local_name^)
            )
        else:
            node.update_argument(IdentifierArgument(argument.copy()))


@fieldwise_init
struct PathArgument(Movable, YangArgument):
    var path: YangPath

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        var parsed = parse_yang_path(argument, node.argument_line())
        node.update_argument(PathArgument(parsed^))


@fieldwise_init
struct XPathExpressionArgument(Movable, YangArgument):
    var root: Arc[XPathExpr]

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument.byte_length() == 0:
            raise _argument_error(node, "expected non-empty expression")
        var line = node.argument_line()
        var root = parse_xpath_expression(argument, line)
        node.update_argument(XPathExpressionArgument(root^))


@fieldwise_init
struct RevisionDateArgument(Movable, YangArgument):
    var date: String

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if not is_revision_date(argument):
            raise _argument_error(node, "expected revision date YYYY-MM-DD")
        node.update_argument(RevisionDateArgument(argument.copy()))


@fieldwise_init
struct RangeArgument(Movable, YangArgument):
    var segments: List[RangeBounds]

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        var segs = try_parse_range_segments(argument, node.argument_line())
        if len(segs) < 1:
            raise _argument_error(node, "expected valid `range` expression")
        node.update_argument(RangeArgument(segs^))


@fieldwise_init
struct LengthArgument(Movable, YangArgument):
    var segments: List[LengthSegment]

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        var segs = try_parse_length_segments(argument, node.argument_line())
        node.update_argument(LengthArgument(segs^))


@fieldwise_init
struct PatternArgument(Movable, YangArgument):
    var regex: String

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument.byte_length() == 0:
            raise _argument_error(
                node, "expected non-empty XSD regular expression"
            )
        node.update_argument(PatternArgument(argument.copy()))


@fieldwise_init
struct ModifierArgument(Movable, YangArgument):
    ## True when the argument is `invert-match` (RFC 7950 §9.4.6).
    var invert_match: Bool

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument != "invert-match":
            raise _argument_error(node, "expected argument `invert-match`")
        node.update_argument(ModifierArgument(True))


@fieldwise_init
struct FractionDigitsArgument(Movable, YangArgument):
    var digits: Int

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument.byte_length() == 0:
            raise _argument_error(node, "expected digit string")
        var n = atol(argument)
        if n < 1 or n > 18:
            raise _argument_error(
                node, "must be between 1 and 18 (RFC 7950 §9.3)"
            )
        node.update_argument(FractionDigitsArgument(Int(n)))


@fieldwise_init
struct BoolArgument(Movable, YangArgument):
    var truth: Bool

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument != "true" and argument != "false":
            raise _argument_error(node, "expected boolean argument")
        var truth = argument == "true"
        node.update_argument(BoolArgument(truth))


@fieldwise_init
struct MaxElementsArgument(Movable, YangArgument):
    ## Non-negative count, or `-1` when the argument is `unbounded`.
    var count: Int

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument.byte_length() == 0:
            raise _argument_error(
                node, "expected non-negative integer or unbounded"
            )
        if argument == "unbounded":
            node.update_argument(MaxElementsArgument(-1))
            return
        var n = atol(argument)
        if n < 0:
            raise _argument_error(node, "`max-elements` must be non-negative")
        node.update_argument(MaxElementsArgument(Int(n)))


@fieldwise_init
struct StatusArgument(Movable, YangArgument):
    var state: String

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if (
            argument != "current"
            and argument != "deprecated"
            and argument != "obsolete"
        ):
            raise _argument_error(
                node,
                (
                    "expected `current`, `deprecated`, or `obsolete` (RFC 7950"
                    " §7.21.2)"
                ),
            )
        node.update_argument(StatusArgument(argument.copy()))


@fieldwise_init
struct OrderedByArgument(Movable, YangArgument):
    var ordering: String

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument != "system" and argument != "user":
            raise _argument_error(
                node,
                "expected `system` or `user` (RFC 7950 §7.7.7)",
            )
        node.update_argument(OrderedByArgument(argument.copy()))


@fieldwise_init
struct IntegerArgument[T: DType](Movable, YangArgument):
    ## Parsed integer argument, checked against `Scalar[Self.T].MIN`..`MAX`
    ## (e.g. `DType.int32` for RFC 7950 §9.6.4.2 `enum` values).
    var value: Scalar[Self.T]

    @staticmethod
    def parse_and_store(mut node: YangConstruct) raises -> None:
        var n = Int64(atol(node.argument_text()))
        comptime lo = Int64(Scalar[Self.T].MIN)
        comptime hi = Int64(Scalar[Self.T].MAX)
        if n < lo or n > hi:
            raise _argument_error(
                node, "integer value out of range for this statement"
            )
        node.update_argument(IntegerArgument[Self.T](Scalar[Self.T](Int(n))))


comptime Int32Argument = IntegerArgument[DType.int32]
comptime UInt32Argument = IntegerArgument[DType.uint32]

## `value` under `enum` (RFC 7950 §9.6.4.2).
comptime EnumArgument = Int32Argument

## `position` under `bit` (RFC 7950 §9.7.4.2); `Scalar[DType.uint32]` range.
comptime PositionArgument = UInt32Argument

## `min-elements` (RFC 7950 §7.7.5); same unsigned range as `position`.
comptime MinElementsArgument = UInt32Argument


comptime YangArgumentPayload = Variant[
    NoArgument,
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
    BoolArgument,
    MaxElementsArgument,
    StatusArgument,
    OrderedByArgument,
    Int32Argument,  # EnumArgument
    UInt32Argument,  # PositionArgument and MinElementsArgument
]


struct YangArgumentValue(Movable):
    var text: String
    var payload: YangArgumentPayload

    def __init__(out self, var text: String = ""):
        self.text = text^
        self.payload = YangArgumentPayload(NoArgument())

    def __init__[T: Movable](out self, var text: String, var inner: T):
        self.text = text^
        self.payload = YangArgumentPayload(inner^)

    def isa[T: AnyType](read self) -> Bool:
        return self.payload.isa[T]()

    def get[T: AnyType](ref self) -> ref[self.payload] T:
        return self.payload[T]

    def update_payload[T: Movable](mut self, var inner: T):
        ## Replace the typed argument while preserving lexer/source `text`.
        self.payload = YangArgumentPayload(inner^)


@fieldwise_init
struct RangeBounds(Copyable, ImplicitlyCopyable, Movable):
    ## Inclusive numeric bounds (`min` / `max` map to extreme `Float64` values).
    var lo: Float64
    var hi: Float64


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


def _line_prefix(line: UInt) -> String:
    if line > 0:
        return "line " + String(line) + ": "
    return ""


def _length_lower_bound(read tok: StringSlice, line: UInt) raises -> Int64:
    if tok == "min":
        return 0
    if tok == "max":
        raise Error(
            _line_prefix(line) + "`length` `max` cannot be a lower bound"
        )
    if tok.byte_length() == 0:
        raise Error(_line_prefix(line) + "`length` empty lower bound")
    var n = Int64(atol(tok))
    if n < 0:
        raise Error(
            _line_prefix(line) + "`length` lower bound must be non-negative"
        )
    return n


def _length_upper_bound(read tok: StringSlice, line: UInt) raises -> Int64:
    if tok == "max":
        return _LENGTH_MAX
    if tok == "min":
        raise Error(
            _line_prefix(line) + "`length` `min` cannot be an upper bound"
        )
    if tok.byte_length() == 0:
        raise Error(_line_prefix(line) + "`length` empty upper bound")
    var n = Int64(atol(tok))
    if n < 0:
        raise Error(
            _line_prefix(line) + "`length` upper bound must be non-negative"
        )
    return n


def try_parse_length_segments(
    read argument: String, line: UInt
) raises -> List[LengthSegment]:
    ## Parse RFC 7950 `length-arg` (§9.4.4, ABNF `length-arg` in §14).
    var out = List[LengthSegment]()
    if argument.byte_length() == 0:
        raise Error(_line_prefix(line) + "`length` expected non-empty argument")
    var raw_parts = argument.split("|")
    for i in range(len(raw_parts)):
        var part = raw_parts[i]
        if part.byte_length() == 0:
            raise Error(_line_prefix(line) + "`length` empty `|` segment")
        var dots = part.split("..")
        var lo_b: Int64
        var hi_b: Int64
        if len(dots) == 1:
            var t = dots[0]
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
            lo_b = _length_lower_bound(dots[0], line)
            hi_b = _length_upper_bound(dots[1], line)
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


def _range_lower_bound_f64(read tok: StringSlice, line: UInt) raises -> Float64:
    if tok == "min":
        return Float64.MAX_FINITE
    if tok == "max":
        raise Error(
            _line_prefix(line) + "`range` `max` cannot be a lower bound"
        )
    if tok.byte_length() == 0:
        raise Error(_line_prefix(line) + "`range` empty lower bound")
    return Float64(tok)


def _range_upper_bound_f64(read tok: StringSlice, line: UInt) raises -> Float64:
    if tok == "max":
        return Float64.MAX_FINITE
    if tok == "min":
        raise Error(
            _line_prefix(line) + "`range` `min` cannot be an upper bound"
        )
    if tok.byte_length() == 0:
        raise Error(_line_prefix(line) + "`range` empty upper bound")
    return Float64(tok)


def _parse_one_range_segment(
    read seg: StringSlice, line: UInt
) raises -> RangeBounds:
    ## One `lower..upper` piece (RFC 7950 §9.2.4); bounds may be decimal.
    var parts = seg.split("..")
    if len(parts) != 2:
        raise Error(
            _line_prefix(line)
            + "`range` segment `"
            + String(seg)
            + "` must contain exactly one `..`"
        )
    var lo = _range_lower_bound_f64(parts[0], line)
    var hi = _range_upper_bound_f64(parts[1], line)
    if lo > hi:
        raise Error(
            _line_prefix(line) + "`range` lower bound exceeds upper bound"
        )
    return RangeBounds(lo, hi)


def try_parse_range_segments(
    read argument: String, line: UInt = 0
) raises -> List[RangeBounds]:
    ## Parse `range-arg`: `|` alternatives, each `lower..upper` (§9.2.4).
    var out = List[RangeBounds]()
    if argument.byte_length() == 0:
        return out^
    var raw_parts = argument.split("|")
    for i in range(len(raw_parts)):
        var piece = raw_parts[i]
        if piece.byte_length() == 0:
            raise Error(_line_prefix(line) + "`range` empty `|` segment")
        out.append(_parse_one_range_segment(piece, line))
    for i in range(1, len(out)):
        if out[i - 1].lo > out[i].lo:
            raise Error(
                _line_prefix(line)
                + "`range` alternatives must be in ascending order (RFC 7950"
                " §9.2.4)"
            )
        if out[i - 1].hi >= out[i].lo:
            raise Error(
                _line_prefix(line)
                + "`range` alternatives must be disjoint (RFC 7950 §9.2.4)"
            )
    return out^


def try_parse_range_bounds(
    read argument: String,
    line: UInt = 0,
) raises -> Optional[RangeBounds]:
    ## First alternative only; prefer `try_parse_range_segments` for unions.
    var segs = try_parse_range_segments(argument, line)
    if len(segs) < 1:
        return Optional[RangeBounds]()
    return Optional[RangeBounds](segs[0].copy())
