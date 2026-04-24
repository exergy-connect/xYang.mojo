from std.memory import ArcPointer
from xyang.ast import (
    YangType,
    YangTypePlain,
    YangMust,
    YangWhen,
)
from xyang.xpath import parse_xpath, Expr
from xyang.yang.parser.yang_token import (
    YANG_STMT_DESCRIPTION,
    YANG_STMT_ERROR_MESSAGE,
    YANG_STMT_MUST,
    YANG_STMT_WHEN,
    YANG_STMT_TYPE,
    YANG_STMT_RANGE,
    YANG_STMT_FRACTION_DIGITS,
    YANG_STMT_PATH,
    YANG_STMT_REQUIRE_INSTANCE,
    YANG_STMT_ENUM,
    YANG_STMT_UNION,
    YANG_STMT_BIT,
    YANG_STMT_BASE,
    YANG_TYPE_ENUMERATION,
    YANG_TYPE_LEAFREF,
)
from xyang.yang.parser.state_support import _yang_constraints_for_parsed_type
from xyang.yang.parser.parser_contract import ParserContract

comptime Arc = ArcPointer


def parse_type_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangType:
    parser._expect(YANG_STMT_TYPE)
    var type_name = parser._consume_name()
    var has_range = False
    var range_min = Int64(0)
    var range_max = Int64(0)
    var enum_values = List[String]()
    var union_types = List[Arc[YangType]]()
    var has_leafref_path = False
    var leafref_path = ""
    var leafref_require_instance = True
    var leafref_xpath_ast = Expr.ExprPointer()
    var leafref_path_parsed = False
    var fraction_digits = 0
    var has_dec_range = False
    var dec_lo = Float64(0.0)
    var dec_hi = Float64(0.0)
    var bits_names = List[String]()
    var identityref_base = ""

    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_RANGE:
                parser._consume()
                var range_expr = parser._consume_argument_value()
                var parts = range_expr.split("..")
                if len(parts) == 2 and type_name == "decimal64":
                    try:
                        var a = parts[0].strip()
                        var b = parts[1].strip()
                        dec_lo = atof(a)
                        dec_hi = atof(b)
                        has_dec_range = True
                    except:
                        has_dec_range = False
                elif len(parts) == 2:
                    try:
                        range_min = Int64(atol(parts[0].strip()))
                        range_max = Int64(atol(parts[1].strip()))
                        has_range = True
                    except:
                        has_range = False
                parser._skip_if(";")
            elif stmt == YANG_STMT_PATH:
                parser._consume()
                leafref_path = parser._consume_argument_value()
                has_leafref_path = True
                try:
                    leafref_xpath_ast = parse_xpath(leafref_path)
                    leafref_path_parsed = True
                except:
                    leafref_xpath_ast = Expr.ExprPointer()
                    leafref_path_parsed = False
                parser._skip_if(";")
            elif stmt == YANG_STMT_REQUIRE_INSTANCE:
                parser._consume()
                leafref_require_instance = parser._parse_boolean_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_ENUM:
                parser._consume()
                enum_values.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_TYPE and type_name == YANG_STMT_UNION:
                var union_type = parser._parse_type_statement()
                union_types.append(Arc[YangType](union_type^))
            elif stmt == YANG_STMT_FRACTION_DIGITS and type_name == "decimal64":
                parser._consume()
                try:
                    var fd = atol(parser._consume_name().strip())
                    if fd >= 1 and fd <= 18:
                        fraction_digits = Int(fd)
                except:
                    pass
                parser._skip_if(";")
            elif stmt == YANG_STMT_BIT and type_name == "bits":
                parser._consume()
                bits_names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_BASE and type_name == "identityref":
                parser._consume()
                identityref_base = parser._consume_argument_value()
                parser._skip_if(";")
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

    if type_name == YANG_TYPE_ENUMERATION and len(enum_values) == 0:
        parser._error(
            "enumeration type requires at least one '" + YANG_STMT_ENUM + "' statement",
        )
        return YangType(
            name = type_name,
            constraints = _yang_constraints_for_parsed_type(
                type_name,
                has_range,
                range_min,
                range_max,
                enum_values^,
                has_leafref_path,
                leafref_path,
                leafref_require_instance,
                leafref_xpath_ast,
                leafref_path_parsed,
                fraction_digits,
                has_dec_range,
                dec_lo,
                dec_hi,
                bits_names^,
                identityref_base,
            ),
            union_members = union_types^,
        )

    if type_name == YANG_STMT_UNION:
        return YangType(
            name = type_name,
            constraints = YangTypePlain(_pad=0),
            union_members = union_types^,
        )

    return YangType(
        name = type_name,
        constraints = _yang_constraints_for_parsed_type(
            type_name,
            has_range,
            range_min,
            range_max,
            enum_values^,
            has_leafref_path,
            leafref_path,
            leafref_require_instance,
            leafref_xpath_ast,
            leafref_path_parsed,
            fraction_digits,
            has_dec_range,
            dec_lo,
            dec_hi,
            bits_names^,
            identityref_base,
        ),
        union_members = List[Arc[YangType]](),
    )


def parse_must_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangMust:
    parser._expect(YANG_STMT_MUST)
    var expression = parser._consume_argument_value()
    var error_message = ""
    var description = ""

    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_ERROR_MESSAGE:
                parser._consume()
                error_message = parser._consume_argument_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(";")
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

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
    parser._expect(YANG_STMT_WHEN)
    var expression = parser._consume_argument_value()
    var description = ""

    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(";")
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

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
