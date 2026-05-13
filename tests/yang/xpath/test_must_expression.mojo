## Standalone checks for YANG `must` XPath arguments and `current()` evaluation.
##
## Instance validation in `xyang.validator.tree` only partially handles `must`;
## this file exercises the XPath surface `must` shares with `when`: parse-time
## `XPathExpressionArgument` and runtime `XPathEvaluator` (anchor = `current()`).

from std.memory import ArcPointer
from std.testing import assert_equal, assert_false, assert_true, TestSuite

from xyang.yang.arguments import XPathExpressionArgument
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.xpath.evaluator import (
    XPathEvaluator,
    XPathNode,
    eval_result_to_bool,
)
from xyang.yang.xpath.pratt_parser import parse_xpath

comptime Arc = ArcPointer


def test_must_statement_parses_boolean_current() raises:
    var node = YangConstruct("must", line=3)
    node.set_raw_argument(String("boolean(current())"))
    XPathExpressionArgument.parse_and_store(node)
    assert_equal(node.argument_text(), String("boolean(current())"))
    assert_true(node.argument.isa[XPathExpressionArgument]())


def test_must_statement_parses_current_parent_string_compare() raises:
    # Typical leaf/list pattern: relate the context node to an ancestor path.
    var node = YangConstruct("must", line=1)
    node.set_raw_argument(String("string(current()/..) = '/devices/device'"))
    XPathExpressionArgument.parse_and_store(node)
    assert_true(node.argument.isa[XPathExpressionArgument]())


def test_eval_current_equals_dot_when_same_context() raises:
    var ex = "string(.) = string(current())"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var here = XPathNode("/top/name", "/top/name")
    var here_arc = Arc[XPathNode](here^)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, here_arc, root_arc, ex, here_arc)
    assert_true(eval_result_to_bool(result))


def test_eval_current_differs_from_dot_on_sibling_context() raises:
    # current() follows the must anchor; . follows the XPath context node.
    var ex = "string(.) != string(current())"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var anchor = XPathNode("/top/a", "/top/a")
    var anchor_arc = Arc[XPathNode](anchor^)
    var ctx = XPathNode("/top/b", "/top/b")
    var ctx_arc = Arc[XPathNode](ctx^)
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, anchor_arc, root_arc, ex, ctx_arc)
    assert_true(eval_result_to_bool(result))


def test_eval_string_current_parent_path() raises:
    var ex = "string(current()/..) = '/devices'"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var anchor = XPathNode("/devices/name", "/devices/name")
    var anchor_arc = Arc[XPathNode](anchor^)
    var ctx_arc = anchor_arc.copy()
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, anchor_arc, root_arc, ex, ctx_arc)
    assert_true(eval_result_to_bool(result))


def test_eval_string_current_parent_path_negative() raises:
    var ex = "string(current()/..) = '/wrong'"
    var ptr = parse_xpath(ex)
    var root = XPathNode("/", "/")
    var root_arc = Arc[XPathNode](root^)
    var anchor = XPathNode("/devices/name", "/devices/name")
    var anchor_arc = Arc[XPathNode](anchor^)
    var ctx_arc = anchor_arc.copy()
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, anchor_arc, root_arc, ex, ctx_arc)
    assert_false(eval_result_to_bool(result))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
