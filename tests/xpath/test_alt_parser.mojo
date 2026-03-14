## Tests for alternatives.xpath.parser (XPathParser with Variant AST).
## Uses XPathParser(expression).parse() or .parse_path(); AST from alternatives.xpath.ast.

from std.testing import assert_equal, assert_false, assert_true, TestSuite
from alternatives.xpath.parser import XPathParser
from alternatives.xpath.ast import (
    ASTNodeVariant,
    BinaryOpNode,
    free_tree,
    FunctionCallNode,
    LiteralNode,
    PathNode,
    PathSegment,
)


# -----------------------------
# Atoms: number, string (via parse())
# -----------------------------

def test_alt_parse_number():
    var parser = XPathParser("42")
    var node = parser.parse()
    assert_true(node.isa[LiteralNode]())
    assert_equal(node[LiteralNode].value.text(parser.expression), "42")


def test_alt_parse_string():
    var parser = XPathParser("'hello'")
    var node = parser.parse()
    assert_true(node.isa[LiteralNode]())
    assert_equal(node[LiteralNode].value.text(parser.expression, strip_quotes=True), "hello")
    free_tree(node)


def test_alt_parse_parens():
    var parser = XPathParser("(7)")
    var node = parser.parse()
    assert_true(node.isa[LiteralNode]())
    assert_equal(node[LiteralNode].value.text(parser.expression), "7")
    free_tree(node)


# -----------------------------
# Binary operators (parse())
# -----------------------------

def test_alt_parse_binary_plus():
    var parser = XPathParser("1 + 2")
    var node = parser.parse()
    assert_true(node.isa[BinaryOpNode]())
    ref bin_node = node[BinaryOpNode]
    assert_equal(bin_node.operator, "+")
    assert_true(bin_node.left[].isa[LiteralNode]())
    assert_equal(bin_node.left[][LiteralNode].value.text(parser.expression), "1")
    assert_true(bin_node.right[].isa[LiteralNode]())
    assert_equal(bin_node.right[][LiteralNode].value.text(parser.expression), "2")


def test_alt_parse_binary_and():
    var parser = XPathParser("a and b")
    var node = parser.parse()
    assert_true(node.isa[BinaryOpNode]())
    ref bin_node = node[BinaryOpNode]
    assert_equal(bin_node.operator, "and")
    assert_equal(bin_node.left[][LiteralNode].value.text(parser.expression), "a")
    assert_equal(bin_node.right[][LiteralNode].value.text(parser.expression), "b")


def test_alt_parse_binary_or():
    var parser = XPathParser("x or y")
    var node = parser.parse()
    assert_true(node.isa[BinaryOpNode]())
    assert_equal(node[BinaryOpNode].operator, "or")


def test_alt_parse_binary_equals():
    var parser = XPathParser("1 = 1")
    var node = parser.parse()
    assert_true(node.isa[BinaryOpNode]())
    assert_equal(node[BinaryOpNode].operator, "=")


def test_alt_parse_binary_precedence_plus_times():
    var parser = XPathParser("3 + 4 * 5")
    var node = parser.parse()
    assert_true(node.isa[BinaryOpNode]())
    ref top = node[BinaryOpNode]
    assert_equal(top.operator, "+")
    assert_equal(top.left[][LiteralNode].value.text(parser.expression), "3")
    assert_true(top.right[].isa[BinaryOpNode]())
    assert_equal(top.right[][BinaryOpNode].operator, "*")
    assert_equal(top.right[][BinaryOpNode].left[][LiteralNode].value.text(parser.expression), "4")
    assert_equal(top.right[][BinaryOpNode].right[][LiteralNode].value.text(parser.expression), "5")


# -----------------------------
# Function calls (parse())
# -----------------------------

def test_alt_parse_call_no_args():
    var parser = XPathParser("f()")
    var node = parser.parse()
    assert_true(node.isa[FunctionCallNode]())
    ref call = node[FunctionCallNode]
    assert_equal(call.name, "f")
    assert_equal(len(call.args), 0)


def test_alt_parse_call_one_arg():
    var parser = XPathParser("string(1)")
    var node = parser.parse()
    assert_true(node.isa[FunctionCallNode]())
    ref call = node[FunctionCallNode]
    assert_equal(call.name, "string")
    assert_equal(len(call.args), 1)
    assert_true(call.args[0][].isa[LiteralNode]())
    assert_equal(call.args[0][][LiteralNode].value.text(parser.expression), "1")


def test_alt_parse_call_two_args():
    var parser = XPathParser("substring(x, 2)")
    var node = parser.parse()
    assert_true(node.isa[FunctionCallNode]())
    ref call = node[FunctionCallNode]
    assert_equal(call.name, "substring")
    assert_equal(len(call.args), 2)
    assert_equal(call.args[0][][LiteralNode].value.text(parser.expression), "x")
    assert_equal(call.args[1][][LiteralNode].value.text(parser.expression), "2")


# -----------------------------
# Paths via parse_path()
# -----------------------------

def test_alt_parse_path_one_step():
    var parser = XPathParser("/a")
    var path = parser.parse_path()
    assert_true(path[].is_absolute)
    assert_equal(len(path[].segments), 1)
    assert_equal(path[].segments[0][].step.text(parser.expression), "a")


def test_alt_parse_path_two_steps():
    var parser = XPathParser("/a/b")
    var path = parser.parse_path()
    assert_true(path[].is_absolute)
    assert_equal(len(path[].segments), 2)
    assert_equal(path[].segments[0][].step.text(parser.expression), "a")
    assert_equal(path[].segments[1][].step.text(parser.expression), "b")


def test_alt_parse_path_three_steps():
    var parser = XPathParser("/foo/bar/baz")
    var path = parser.parse_path()
    assert_equal(len(path[].segments), 3)
    assert_equal(path[].segments[0][].step.text(parser.expression), "foo")
    assert_equal(path[].segments[1][].step.text(parser.expression), "bar")
    assert_equal(path[].segments[2][].step.text(parser.expression), "baz")


# -----------------------------
# Path as expression (parse() returns PathNode inside variant)
# -----------------------------

def test_alt_parse_name_as_path():
    var parser = XPathParser("foo")
    var node = parser.parse()
    assert_true(node.isa[PathNode]())
    ref path = node[PathNode]
    assert_false(path.is_absolute)
    assert_equal(len(path.segments), 1)
    assert_equal(path.segments[0][].step.text(parser.expression), "foo")


def test_alt_parse_dot_as_path():
    var parser = XPathParser(".")
    var node = parser.parse()
    assert_true(node.isa[PathNode]())
    assert_equal(node[PathNode].segments[0][].step.text(parser.expression), ".")


def test_alt_parse_dotdot_as_path():
    var parser = XPathParser("..")
    var node = parser.parse()
    assert_true(node.isa[PathNode]())
    assert_equal(node[PathNode].segments[0][].step.text(parser.expression), "..")


# -----------------------------
# Runner
# -----------------------------

def main():
    TestSuite.discover_tests[__functions_in_module()]().run()
