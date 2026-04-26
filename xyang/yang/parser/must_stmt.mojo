from xyang.ast import YangMust
from xyang.xpath import parse_xpath
import xyang.yang.parser.yang_token as yang_token
from xyang.yang.parser.parser_contract import ParserContract


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

    var xpath_ast = parse_xpath(expression)
    return YangMust(
        expression = expression,
        error_message = error_message,
        description = description,
        xpath_ast = xpath_ast,
    )
