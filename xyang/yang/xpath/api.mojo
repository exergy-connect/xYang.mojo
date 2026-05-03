## Public helpers for YANG statement validation (line-prefixed parse errors).

from xyang.yang.xpath.pratt_parser import Expr, parse_xpath


def _xpath_line_prefix(line: UInt) -> String:
    if line > 0:
        return "line " + String(line) + ": "
    return ""


def parse_xpath_expression(
    read argument: String, line: UInt
) raises -> Expr.ExprPointer:
    """Parse XPath; on failure, re-raise with optional YANG line prefix."""
    try:
        return parse_xpath(argument)
    except e:
        raise Error(_xpath_line_prefix(line) + String(e))
