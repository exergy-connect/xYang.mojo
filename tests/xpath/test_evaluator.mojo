## Test XPath evaluator (eval_accept + XPathEvaluator).

from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, TestSuite
from xyang.xpath.pratt_parser import parse_xpath, Expr
from xyang.xpath.evaluator import (
    XPathNode,
    EvalContext,
    EvalResult,
    XPathEvaluator,
    eval_accept,
)

comptime Arc = ArcPointer


def _free_expr(ptr: Expr.ExprPointer):
    ptr[].free_tree()
    ptr.destroy_pointee()
    ptr.free()


def test_eval_number() raises:
    var ex = "42"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, ex, "")
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[Float64]())
    assert_equal(result[Float64], 42.0)


def test_eval_string() raises:
    var ex = "'hello'"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, ex, "")
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[String]())
    assert_equal(result[String], "hello")


def test_eval_binary_plus() raises:
    var ex = "1 + 2"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, ex, "")
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[Float64]())
    assert_equal(result[Float64], 3.0)


def test_eval_true() raises:
    var ex = "true()"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, ex, "")
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[Bool]())
    assert_true(result[Bool])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
