from std.collections import Dict
from std.memory import ArcPointer
from xyang.ast import (
    YangType,
    YangTypeBits,
    YangTypeDecimal64,
    YangTypeEnumeration,
    YangTypeIdentityref,
    YangTypeIntegerRange,
    YangTypeLeafref,
    YangTypedefStmt,
    YangTypeTypedef,
    YangTypeBasic,
    YangStringPatternSpec,
    YangTypeString,
    YangTypeUnion,
)
import xyang.yang.parser.yang_token as yang_token
from xyang.yang.parser.parser_contract import ParserContract
from xyang.yang.parser.clone_utils import clone_yang_type_impl

comptime Arc = ArcPointer


@fieldwise_init
struct _YangStringLengthBounds(Movable, Copyable):
    var min_len: Int
    var max_len: Int


def _string_length_bounds_from_yang_arg(read arg: String) -> _YangStringLengthBounds:
    ## YANG `length` argument: single value, or `min` / `max` / `N..M` (RFC 7950).
    var trimmed = arg.strip()
    if len(trimmed) == 0:
        return _YangStringLengthBounds(-1, -1)
    var parts = trimmed.split("..")
    if len(parts) == 1:
        try:
            var v = Int(atol(parts[0].strip()))
            return _YangStringLengthBounds(v, v)
        except:
            return _YangStringLengthBounds(-1, -1)
    if len(parts) == 2:
        var ls = String(parts[0].strip())
        var rs = String(parts[1].strip())
        var lmin: Int
        if ls == "min":
            lmin = -1
        else:
            try:
                lmin = Int(atol(ls))
            except:
                return _YangStringLengthBounds(-1, -1)
        var hmax: Int
        if rs == "max":
            hmax = -1
        else:
            try:
                hmax = Int(atol(rs))
            except:
                return _YangStringLengthBounds(-1, -1)
        return _YangStringLengthBounds(lmin, hmax)
    return _YangStringLengthBounds(-1, -1)


def new_builtin_type_parser_table[ParserT: ParserContract](
    out m: Dict[String, fn (mut ParserT, String) raises -> YangType]
):
    m = Dict[String, fn (mut ParserT, String) raises -> YangType]()
    m[yang_token.YANG_TYPE_DECIMAL64] = _parse_decimal64[ParserT]
    m[yang_token.YANG_TYPE_ENUMERATION] = _parse_enumeration[ParserT]
    m["integer"] = _parse_integer_range[ParserT]
    m["number"] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_INT8] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_INT16] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_INT32] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_INT64] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_UINT8] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_UINT16] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_UINT32] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_UINT64] = _parse_integer_range[ParserT]
    m[yang_token.YANG_TYPE_LEAFREF] = _parse_leafref[ParserT]
    m[yang_token.YANG_STMT_UNION] = _parse_union[ParserT]
    m[yang_token.YANG_TYPE_BITS] = _parse_bits[ParserT]
    m[yang_token.YANG_TYPE_IDENTITYREF] = _parse_identityref[ParserT]
    m[yang_token.YANG_TYPE_STRING] = _parse_string[ParserT]
    m[yang_token.YANG_TYPE_BOOLEAN] = _parse_boolean[ParserT]
    m[yang_token.YANG_TYPE_EMPTY] = _parse_empty[ParserT]


def _parse_boolean[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = n, constraints = YangTypeBasic(kind = YangTypeBasic.boolean)
    )


def _parse_empty[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = n, constraints = YangTypeBasic(kind = YangTypeBasic.empty)
    )


def _parse_decimal64[ParserT: ParserContract](
    mut p: ParserT, n: String
) raises -> YangType:
    var name = n
    var fd = 0
    var has_r = False
    var lo = Float64(0.0)
    var hi = Float64(0.0)
    if p._consume_if(yang_token.YangToken.LBRACE):
        while p._has_more() and p._peek() != yang_token.YangToken.RBRACE:
            var s = p._peek()
            if s == yang_token.YangToken.RANGE:
                p._consume()
                var r_ex = p._consume_argument_value()
                var parts = r_ex.split("..")
                if len(parts) == 2:
                    try:
                        lo = atof(parts[0].strip())
                        hi = atof(parts[1].strip())
                        has_r = True
                    except:
                        has_r = False
                else:
                    has_r = False
                p._skip_if(yang_token.YangToken.SEMICOLON)
            elif s == yang_token.YangToken.FRACTION_DIGITS:
                p._consume()
                try:
                    var d = atol(p._consume_name().strip())
                    if d >= 1 and d <= 18:
                        fd = Int(d)
                except:
                    pass
                p._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                p._skip_statement()
        p._expect(yang_token.YangToken.RBRACE)
    p._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = name, constraints = YangTypeDecimal64(fd, has_r, lo, hi)
    )


def _parse_enumeration[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    var values = List[String]()
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            if parser._peek() == yang_token.YangToken.ENUM:
                parser._consume()
                values.append(parser._consume_name())
                parser._skip_statement_tail()
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    if len(values) == 0:
        parser._error(
            "enumeration type requires at least one '"
            + yang_token.YANG_STMT_ENUM
            + "' statement",
        )
    return YangType(
        name = n, constraints = YangTypeEnumeration(values^)
    )


def _parse_integer_range[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    var has_r = False
    var lo = Int64(0)
    var hi = Int64(0)
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            if parser._peek() == yang_token.YangToken.RANGE:
                parser._consume()
                var r_ex = parser._consume_argument_value()
                var p = r_ex.split("..")
                if len(p) == 2:
                    try:
                        lo = Int64(atol(p[0].strip()))
                        hi = Int64(atol(p[1].strip()))
                        has_r = True
                    except:
                        has_r = False
                else:
                    has_r = False
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = n, constraints = YangTypeIntegerRange(has_r, lo, hi)
    )


def _parse_leafref[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    var path = ""
    var need_inst = True
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            var s = parser._peek()
            if s == yang_token.YangToken.PATH:
                parser._consume()
                path = parser._consume_argument_value()
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            elif s == yang_token.YangToken.REQUIRE_INSTANCE:
                parser._consume()
                need_inst = parser._parse_boolean_value()
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    if len(path) == 0:
        parser._error("leafref type requires a 'path' substatement")
    return YangType(
        name = n, constraints = YangTypeLeafref(path^, need_inst)
    )


def _parse_union[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    var members = List[Arc[YangType]]()
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            if parser._peek() == yang_token.YangToken.TYPE:
                var t = parser._parse_type_statement()
                members.append(Arc[YangType](t^))
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = n, constraints = YangTypeUnion(union_members = members^)
    )


def _parse_bits[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    var names = List[String]()
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            if parser._peek() == yang_token.YangToken.BIT:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(name = n, constraints = YangTypeBits(names^))


def _parse_identityref[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    var base = ""
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            if parser._peek() == yang_token.YangToken.BASE:
                parser._consume()
                base = parser._consume_argument_value()
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = n, constraints = YangTypeIdentityref(base^)
    )


def _parse_string[ParserT: ParserContract](
    mut parser: ParserT, n: String
) raises -> YangType:
    var patterns = List[YangStringPatternSpec]()
    var lo = -1
    var hi = -1
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            if parser._peek() == yang_token.YangToken.PATTERN:
                parser._consume()
                var pat_arg = parser._consume_argument_value()
                var inv = False
                if parser._consume_if(yang_token.YangToken.LBRACE):
                    while (
                        parser._has_more()
                        and parser._peek() != yang_token.YangToken.RBRACE
                    ):
                        if parser._peek() == yang_token.YangToken.MODIFIER:
                            parser._consume()
                            var mod_arg = parser._consume_name()
                            if mod_arg == "invert-match":
                                inv = True
                            parser._skip_if(yang_token.YangToken.SEMICOLON)
                        else:
                            parser._skip_statement()
                    parser._expect(yang_token.YangToken.RBRACE)
                    parser._skip_if(yang_token.YangToken.SEMICOLON)
                else:
                    parser._skip_if(yang_token.YangToken.SEMICOLON)
                patterns.append(
                    YangStringPatternSpec(pattern = pat_arg^, invert_match = inv)
                )
            elif parser._peek() == yang_token.YangToken.LENGTH:
                parser._consume()
                var l_ex = parser._consume_argument_value()
                var b = _string_length_bounds_from_yang_arg(l_ex)
                lo = b.min_len
                hi = b.max_len
                parser._skip_statement_tail()
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = n,
        constraints = YangTypeString(
            patterns = patterns^, length_min = lo, length_max = hi
        ),
    )


def parse_type_statement_impl[ParserT: ParserContract](
    mut parser: ParserT
) raises -> YangType:
    parser._expect(yang_token.YangToken.TYPE)
    ref type_name = parser._consume_name()
    var out = parser._parse_yang_type(type_name)
    ## Built-in type parsers already skip `;`; typedef references do not — consume it here
    ## so the leaf/list body does not see a lone `;` and mis-handle the next substatement.
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return out^


def parse_typedef_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises:
    parser._expect(yang_token.YangToken.TYPEDEF)
    var name = parser._consume_name()
    var typedef_description = ""
    var type_opt = Optional[YangType]()
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == yang_token.YangToken.TYPE:
                var t = parser._parse_type_statement()
                type_opt = Optional(t^)
            elif stmt == yang_token.YangToken.DESCRIPTION:
                parser._consume()
                typedef_description = parser._consume_argument_value()
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    if not type_opt:
        parser._error("typedef '" + name + "' requires a type statement")
    parser._store_typedef(name, type_opt.take(), typedef_description^)
