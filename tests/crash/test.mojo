## Minimal repro: single evaluator test (eval string) for crash debugging.

from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, TestSuite
from xyang.xpath.token import Token
from xyang.xpath.pratt_parser import parse_xpath, Expr
from xyang.xpath.evaluator import XPathNode, EvalContext, XPathEvaluator

comptime Arc = ArcPointer

def test_eval_string():
    var ex = "'hello'"
    # var ptr = parse_xpath(ex)
    # var ptr = Expr.name(Token(type=Token.STRING, start=0, length=5, line=1))
    # STRING token: start=0, length=7 for "'hello'"
    var tok = Token(type=Token.STRING, start=0, length=7, line=1)
    var ptr = Expr.string(tok)
    var root = XPathNode("/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, ex, "")
    var ev = XPathEvaluator()

    #
    # THIS CRASHES
    #
    var result = ev.eval(ptr, ctx, root_arc)
    # _free_expr(ptr)
    assert_true(result.isa[String]())
    assert_equal(result[String], "hello")


def main():
    TestSuite.discover_tests[__functions_in_module()]().run()
