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
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, root_arc, ex, 0, 0)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[Float64]())
    assert_equal(result[Float64], 42.0)


def test_eval_string() raises:
    var ex = "'hello'"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, root_arc, ex, 0, 0)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[String]())
    assert_equal(result[String], "hello")


def test_eval_binary_plus() raises:
    var ex = "1 + 2"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, root_arc, ex, 0, 0)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[Float64]())
    assert_equal(result[Float64], 3.0)


def test_eval_true() raises:
    var ex = "true()"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, root_arc, ex, 0, 0)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[Bool]())
    assert_true(result[Bool])


def test_eval_absolute_path_no_double_slash() raises:
    # Root path is document root "/"; first segment must be "/a", not "//a".
    var ex = "/a/b"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, root_arc, ex, 0, 0)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[List[Arc[XPathNode]]]())
    ref nodes = result[List[Arc[XPathNode]]]
    assert_equal(len(nodes), 1)
    assert_equal(nodes[0][].path, "/a/b")


def test_eval_position_in_step_predicate() raises:
    var ex = "/a[position() = 1]"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, root_arc, ex, 0, 0)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[List[Arc[XPathNode]]]())
    assert_equal(len(result[List[Arc[XPathNode]]]), 1)
    assert_equal(result[List[Arc[XPathNode]]][0][].path, "/a")


def test_eval_last_in_step_predicate() raises:
    var ex = "/a[position() = last()]"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, root_arc, ex, 0, 0)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[List[Arc[XPathNode]]]())
    assert_equal(len(result[List[Arc[XPathNode]]]), 1)


def test_eval_slash_slash_composition() raises:
    # `//` has no true descendant axis in this path model; it behaves like `/` for YANG use.
    var ex = "a//b"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, root_arc, ex, 0, 0)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[List[Arc[XPathNode]]]())
    assert_equal(result[List[Arc[XPathNode]]][0][].path, "/a/b")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
