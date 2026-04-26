from std.memory import ArcPointer
from xyang.ast import (
    YangType,
    YangTypeBits,
    YangTypeDecimal64,
    YangTypeEnumeration,
    YangTypeIdentityref,
    YangTypeIntegerRange,
    YangTypeLeafref,
    YangTypePlain,
    YangTypeString,
    YangTypeUnion,
    YangMust,
    YangWhen,
)
from xyang.xpath import parse_xpath, Expr
import xyang.yang.parser.yang_token as yang_token
from xyang.yang.parser.parser_contract import ParserContract
from xyang.yang.parser.clone_utils import clone_yang_type_impl

comptime Arc = ArcPointer


def _type_name_uses_integer_range_substmts(name: String) -> Bool:
    if name == "integer" or name == "number":
        return True
    return (
        name == yang_token.YANG_TYPE_INT8
        or name == yang_token.YANG_TYPE_INT16
        or name == yang_token.YANG_TYPE_INT32
        or name == yang_token.YANG_TYPE_INT64
        or name == yang_token.YANG_TYPE_UINT8
        or name == yang_token.YANG_TYPE_UINT16
        or name == yang_token.YANG_TYPE_UINT32
        or name == yang_token.YANG_TYPE_UINT64
    )


## Skip optional `{ ... }` and trailing `;` for the current `type` statement.
def _type_skip_rest_of_statement[ParserT: ParserContract](
    mut parser: ParserT
) raises:
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)


def _parse_decimal64[ParserT: ParserContract](
    mut parser: ParserT, var name: String
) raises -> YangType:
    var fd = 0
    var has_r = False
    var lo = Float64(0.0)
    var hi = Float64(0.0)
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            var s = parser._peek()
            if s == yang_token.YangToken.RANGE:
                parser._consume()
                var r_ex = parser._consume_argument_value()
                var p = r_ex.split("..")
                if len(p) == 2:
                    try:
                        lo = atof(p[0].strip())
                        hi = atof(p[1].strip())
                        has_r = True
                    except:
                        has_r = False
                else:
                    has_r = False
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            elif s == yang_token.YangToken.FRACTION_DIGITS:
                parser._consume()
                try:
                    var n = atol(parser._consume_name().strip())
                    if n >= 1 and n <= 18:
                        fd = Int(n)
                except:
                    pass
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = name, constraints = YangTypeDecimal64(fd, has_r, lo, hi)
    )


def _parse_enumeration[ParserT: ParserContract](
    mut parser: ParserT, var name: String
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
        name = name, constraints = YangTypeEnumeration(values^)
    )


def _parse_integer_range[ParserT: ParserContract](
    mut parser: ParserT, var name: String
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
        name = name, constraints = YangTypeIntegerRange(has_r, lo, hi)
    )


def _parse_leafref[ParserT: ParserContract](
    mut parser: ParserT, var name: String
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
        name = name, constraints = YangTypeLeafref(path^, need_inst)
    )


def _parse_union[ParserT: ParserContract](
    mut parser: ParserT, var name: String
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
        name = name, constraints = YangTypeUnion(union_members = members^)
    )


def _parse_bits[ParserT: ParserContract](
    mut parser: ParserT, var name: String
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
    return YangType(name = name, constraints = YangTypeBits(names^))


def _parse_identityref[ParserT: ParserContract](
    mut parser: ParserT, var name: String
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
        name = name, constraints = YangTypeIdentityref(base^)
    )


def _parse_string[ParserT: ParserContract](
    mut parser: ParserT, var name: String
) raises -> YangType:
    var pat = ""
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            if parser._peek() == yang_token.YangToken.PATTERN:
                parser._consume()
                pat = parser._consume_argument_value()
                parser._skip_statement_tail()
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    return YangType(
        name = name, constraints = YangTypeString(pat^)
    )


def parse_type_statement_impl[ParserT: ParserContract](
    mut parser: ParserT
) raises -> YangType:
    parser._expect(yang_token.YangToken.TYPE)
    var type_name = parser._consume_name()
    # Early: user-defined `typedef` — must still consume the rest of the stmt.
    var typedef_opt = parser._resolve_typedef_type(type_name)
    if typedef_opt:
        _type_skip_rest_of_statement(parser)
        return clone_yang_type_impl(typedef_opt.value()[])

    if type_name == yang_token.YANG_TYPE_DECIMAL64:
        return _parse_decimal64(parser, type_name^)
    if type_name == yang_token.YANG_TYPE_ENUMERATION:
        return _parse_enumeration(parser, type_name^)
    if _type_name_uses_integer_range_substmts(type_name):
        return _parse_integer_range(parser, type_name^)
    if type_name == yang_token.YANG_TYPE_LEAFREF:
        return _parse_leafref(parser, type_name^)
    if type_name == yang_token.YANG_STMT_UNION:
        return _parse_union(parser, type_name^)
    if type_name == yang_token.YANG_TYPE_BITS:
        return _parse_bits(parser, type_name^)
    if type_name == yang_token.YANG_TYPE_IDENTITYREF:
        return _parse_identityref(parser, type_name^)
    if type_name == yang_token.YANG_TYPE_STRING:
        return _parse_string(parser, type_name^)
    # Fallback: boolean, empty, unknown keyword, etc.
    _type_skip_rest_of_statement(parser)
    return YangType(
        name = type_name,
        constraints = YangTypePlain(_pad=0),
    )


def parse_typedef_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises:
    parser._expect(yang_token.YangToken.TYPEDEF)
    var name = parser._consume_name()
    var has_type = False
    var typedef_description = ""
    var type_stmt = YangType(
        name = "string",
        constraints = YangTypeString(pattern = ""),
    )
    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == yang_token.YangToken.TYPE:
                type_stmt = parser._parse_type_statement()
                has_type = True
            elif stmt == yang_token.YangToken.DESCRIPTION:
                parser._consume()
                typedef_description = parser._consume_argument_value()
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)
    if not has_type:
        parser._error("typedef '" + name + "' requires a type statement")
    parser._store_typedef(name, type_stmt, typedef_description^)


def parse_must_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangMust:
    parser._expect(yang_token.YangToken.MUST)
    var expression = parser._consume_argument_value()
    var error_message = ""
    var description = ""

    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == yang_token.YangToken.ERROR_MESSAGE:
                parser._consume()
                error_message = parser._consume_argument_value()
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            elif stmt == yang_token.YangToken.DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)

    var xpath_ast = Expr.ExprPointer()
    try:
        xpath_ast = parse_xpath(expression)
        return YangMust(
            expression = expression,
            error_message = error_message,
            description = description,
            xpath_ast = xpath_ast,
            parsed = True,
        )
    except:
        return YangMust(
            expression = expression,
            error_message = error_message,
            description = description,
            xpath_ast = xpath_ast,
            parsed = False,
        )


def parse_when_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangWhen:
    parser._expect(yang_token.YangToken.WHEN)
    var expression = parser._consume_argument_value()
    var description = ""

    if parser._consume_if(yang_token.YangToken.LBRACE):
        while parser._has_more() and parser._peek() != yang_token.YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == yang_token.YangToken.DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(yang_token.YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(yang_token.YangToken.RBRACE)
    parser._skip_if(yang_token.YangToken.SEMICOLON)

    var xpath_ast = Expr.ExprPointer()
    try:
        xpath_ast = parse_xpath(expression)
        return YangWhen(
            expression = expression,
            description = description,
            xpath_ast = xpath_ast,
            parsed = True,
        )
    except:
        return YangWhen(
            expression = expression,
            description = description,
            xpath_ast = xpath_ast,
            parsed = False,
        )
