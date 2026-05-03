## YANG statement argument types and `YangArgument::validate` for construct
## validation (table-driven specs in `spec.mojo`).
##
## Includes RFC 7950 §9.4 (`length`, `pattern`, `modifier`) argument checks.

from std.collections import List
from std.utils import Variant

from xyang.yang.identifiers import (
    is_identifier,
    is_qname,
    is_revision_date,
    is_supported_type_name,
)
from xyang.yang.path import YangPath
from xyang.yang.path import parse_yang_path


trait YangArgumentHost:
    def argument_text(read self) -> String:
        ...

    def argument_keyword(read self) -> String:
        ...

    def argument_line(read self) -> UInt:
        ...

    def set_argument(mut self, var argument: YangArgumentValue):
        ...


comptime YangConstruct = Some[YangArgumentHost]


trait YangArgument:
    def get_text(read self) -> String:
        ...

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
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
    var text: String

    def __init__(out self):
        self.text = ""

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        return


@fieldwise_init
struct RawArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        return


@fieldwise_init
struct StringArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        node.set_argument(YangArgumentValue(StringArgument(argument^)))


## `yang-version` statement; stores a `StringArgument` payload (1 or 1.1).
@fieldwise_init
struct YangVersionArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
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
        node.set_argument(YangArgumentValue(StringArgument(argument^)))


@fieldwise_init
struct IdentifierArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if not is_identifier(argument):
            raise _argument_error(node, "expected identifier argument")
        node.set_argument(YangArgumentValue(IdentifierArgument(argument^)))


@fieldwise_init
struct QNameArgument(Movable, YangArgument):
    var text: String
    var prefix: String
    var local_name: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if not is_qname(argument):
            raise _argument_error(
                node, "expected identifier or prefixed identifier"
            )
        var parts = argument.split(":")
        if len(parts) == 2:
            node.set_argument(
                YangArgumentValue(
                    QNameArgument(argument^, String(parts[0]), String(parts[1]))
                )
            )
        else:
            node.set_argument(YangArgumentValue(IdentifierArgument(argument^)))


@fieldwise_init
struct PathArgument(Movable, YangArgument):
    var text: String
    var path: YangPath

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        var parsed = parse_yang_path(argument, node.argument_line())
        node.set_argument(YangArgumentValue(PathArgument(argument^, parsed^)))


@fieldwise_init
struct XPathExpressionArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument.byte_length() == 0:
            raise _argument_error(node, "expected non-empty expression")
        node.set_argument(YangArgumentValue(XPathExpressionArgument(argument^)))


@fieldwise_init
struct RevisionDateArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if not is_revision_date(argument):
            raise _argument_error(node, "expected revision date YYYY-MM-DD")
        node.set_argument(YangArgumentValue(RevisionDateArgument(argument^)))


@fieldwise_init
struct RangeArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        var parsed = try_parse_range_bounds(argument)
        if not parsed:
            raise _argument_error(node, "expected basic range expression")
        node.set_argument(YangArgumentValue(RangeArgument(argument^)))


@fieldwise_init
struct LengthArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        _ = try_parse_length_segments(argument, node.argument_line())
        node.set_argument(YangArgumentValue(LengthArgument(argument^)))


@fieldwise_init
struct PatternArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if _strip_spaces(argument).byte_length() == 0:
            raise _argument_error(
                node, "expected non-empty XSD regular expression"
            )
        node.set_argument(YangArgumentValue(PatternArgument(argument^)))


@fieldwise_init
struct ModifierArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if _strip_spaces(argument) != "invert-match":
            raise _argument_error(node, "expected argument `invert-match`")
        node.set_argument(YangArgumentValue(ModifierArgument(argument^)))


@fieldwise_init
struct FractionDigitsArgument(Movable, YangArgument):
    var text: String
    var value: Int

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        var t = _strip_spaces(argument)
        if t.byte_length() == 0:
            raise _argument_error(node, "expected digit string")
        var n = atol(t)
        if n < 1 or n > 18:
            raise _argument_error(
                node, "must be between 1 and 18 (RFC 7950 §9.3)"
            )
        node.set_argument(
            YangArgumentValue(FractionDigitsArgument(argument^, Int(n)))
        )


@fieldwise_init
struct TypeNameArgument(Movable, YangArgument):
    var text: String

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if not is_supported_type_name(argument):
            raise _argument_error(node, "expected basic YANG type name")
        node.set_argument(YangArgumentValue(TypeNameArgument(argument^)))


@fieldwise_init
struct BoolArgument(Movable, YangArgument):
    var text: String
    var value: Bool

    def get_text(read self) -> String:
        return self.text.copy()

    @staticmethod
    def validate(mut node: YangConstruct) raises -> None:
        var argument = node.argument_text()
        if argument != "true" and argument != "false":
            raise _argument_error(node, "expected boolean argument")
        node.set_argument(
            YangArgumentValue(BoolArgument(argument^, argument == "true"))
        )


comptime YangArgumentPayload = Variant[
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


struct YangArgumentValue(Movable):
    var text: String
    var payload: YangArgumentPayload

    def __init__[T: YangArgument & Movable](out self, var argument: T):
        self.text = argument.get_text()
        self.payload = YangArgumentPayload(argument^)

    def isa[T: AnyType](read self) -> Bool:
        return self.payload.isa[T]()

    def get[T: AnyType](ref self) -> ref[self.payload] T:
        return self.payload[T]


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


def _line_prefix(line: UInt) -> String:
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


def _length_lower_bound(read tok: String, line: UInt) raises -> Int64:
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


def _length_upper_bound(read tok: String, line: UInt) raises -> Int64:
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
    read argument: String, line: UInt
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
