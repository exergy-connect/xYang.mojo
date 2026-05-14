## Public helpers for YANG statement validation (line-prefixed parse errors).

from std.memory import ArcPointer
from xyang.yang.xpath.pratt_parser import (
    XPathBinaryOp,
    XPathExpr,
    XPathPath,
    XPathStep,
    parse_xpath,
)
from xyang.yang.xpath.token import Token

comptime Arc = ArcPointer


def _xpath_line_prefix(line: UInt) -> String:
    if line > 0:
        return "line " + String(line) + ": "
    return ""


def parse_xpath_expression(
    read argument: String, line: UInt
) raises -> Arc[XPathExpr]:
    """Parse XPath; on failure, re-raise with optional YANG line prefix."""
    try:
        return parse_xpath(argument)
    except e:
        raise Error(_xpath_line_prefix(line) + String(e))


def _append_slash_path_steps(
    read expr: XPathExpr, mut steps: List[Arc[XPathExpr]]
) -> Bool:
    if expr.kind() == XPathExpr.BINARY and expr.value.type == Token.SLASH:
        ref bin = expr.payload[XPathBinaryOp]
        var left = _append_slash_path_steps(bin.left[], steps)
        var right = _append_slash_path_steps(bin.right[], steps)
        return left or right
    if expr.kind() == XPathExpr.PATH:
        ref p = expr.payload[XPathPath]
        for step in p.steps:
            steps.append(step.copy())
        return True
    if expr.kind() == XPathExpr.STEP:
        ref st = expr.payload[XPathStep]
        var predicates = List[Arc[XPathExpr]]()
        for pred in st.predicates:
            predicates.append(pred.copy())
        var tok = expr.value.copy()
        steps.append(XPathExpr.step(tok^, predicates^))
        return True
    if expr.kind() == XPathExpr.NAME:
        var predicates = List[Arc[XPathExpr]]()
        var tok = expr.value.copy()
        steps.append(XPathExpr.step(tok^, predicates^))
        return True
    return False


def xpath_slash_expr_to_path(read expr: XPathExpr) -> Optional[Arc[XPathExpr]]:
    """Normalize a slash-composed XPath AST subtree into a `PATH`, when possible."""
    var steps = List[Arc[XPathExpr]]()
    if not _append_slash_path_steps(expr, steps) or len(steps) == 0:
        return Optional[Arc[XPathExpr]]()
    return Optional[Arc[XPathExpr]](XPathExpr.path(steps^))
