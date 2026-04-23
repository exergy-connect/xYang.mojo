## Comprehensive tests for xyang.xpath.pratt_parser.
## Uses parse_xpath(expression_string); frees tree after each test.

from std.testing import assert_equal, assert_true, TestSuite
from xyang.xpath.pratt_parser import (
    Expr,
    ExprContext,
    ExprStringifier,
    accept,
    parse_xpath,
)


# -----------------------------
# Helpers
# -----------------------------

def _free_expr(ptr: Expr.ExprPointer):
    """Release the expression tree rooted at ptr."""
    ptr[].free_tree()
    ptr.destroy_pointee()
    ptr.free()


def _val(ref node: Expr, source: String) raises -> String:
    """Return the lexeme for node.value from the given source expression."""
    return node.value.text(source)


# -----------------------------
# Atoms: number, string, name, dot, dotdot
# -----------------------------

def test_parse_number() raises:
    var ex = "42"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.NUMBER)
    assert_equal(_val(ptr[], ex), "42")
    assert_true(not ptr[].left)
    assert_true(not ptr[].right)
    assert_equal(len(ptr[].args), 0)
    assert_equal(len(ptr[].steps), 0)
    _free_expr(ptr)


def test_parse_string() raises:
    var ex = "'hello'"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.STRING)
    assert_equal(ptr[].value.text(ex, strip_quotes=True), "hello")
    _free_expr(ptr)


def test_parse_name() raises:
    var ex = "foo"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.NAME)
    assert_equal(_val(ptr[], ex), "foo")
    _free_expr(ptr)


def test_parse_dot() raises:
    var ex = "."
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.NAME)
    assert_equal(_val(ptr[], ex), ".")
    _free_expr(ptr)


def test_parse_dotdot() raises:
    var ex = ".."
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.NAME)
    assert_equal(_val(ptr[], ex), "..")
    _free_expr(ptr)


# -----------------------------
# Parenthesized expression
# -----------------------------

def test_parse_parens() raises:
    var ex = "(7)"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.NUMBER)
    assert_equal(_val(ptr[], ex), "7")
    _free_expr(ptr)


# -----------------------------
# Binary operators and precedence
# -----------------------------

def test_parse_binary_plus() raises:
    var ex = "1 + 2"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(_val(ptr[], ex), "+")
    assert_true(ptr[].left)
    assert_true(ptr[].right)
    assert_equal(ptr[].left[].kind, Expr.NUMBER)
    assert_equal(_val(ptr[].left[], ex), "1")
    assert_equal(ptr[].right[].kind, Expr.NUMBER)
    assert_equal(_val(ptr[].right[], ex), "2")
    _free_expr(ptr)


def test_parse_binary_and() raises:
    var ex = "a and b"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(_val(ptr[], ex), "and")
    assert_equal(_val(ptr[].left[], ex), "a")
    assert_equal(_val(ptr[].right[], ex), "b")
    _free_expr(ptr)


def test_parse_binary_or() raises:
    var ex = "x or y"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(_val(ptr[], ex), "or")
    _free_expr(ptr)


def test_parse_binary_equals() raises:
    var ex = "1 = 1"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(_val(ptr[], ex), "=")
    _free_expr(ptr)


def test_parse_binary_precedence_plus_times() raises:
    # 3 + 4 * 5  =>  binary(+, 3, binary(*, 4, 5))
    var ex = "3 + 4 * 5"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(_val(ptr[], ex), "+")
    assert_equal(_val(ptr[].left[], ex), "3")
    assert_equal(ptr[].right[].kind, Expr.BINARY)
    assert_equal(_val(ptr[].right[], ex), "*")
    assert_equal(_val(ptr[].right[].left[], ex), "4")
    assert_equal(_val(ptr[].right[].right[], ex), "5")
    _free_expr(ptr)


def test_parse_binary_precedence_parens() raises:
    # (1 + 2) * 3
    var ex = "(1 + 2) * 3"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(_val(ptr[], ex), "*")
    assert_equal(ptr[].left[].kind, Expr.BINARY)
    assert_equal(_val(ptr[].left[], ex), "+")
    assert_equal(_val(ptr[].right[], ex), "3")
    _free_expr(ptr)


# -----------------------------
# Function calls
# -----------------------------

def test_parse_call_no_args() raises:
    var ex = "f()"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.CALL)
    assert_equal(_val(ptr[], ex), "f")
    assert_equal(len(ptr[].args), 0)
    _free_expr(ptr)


def test_parse_call_one_arg() raises:
    var ex = "string(1)"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.CALL)
    assert_equal(_val(ptr[], ex), "string")
    assert_equal(len(ptr[].args), 1)
    assert_equal(ptr[].args[0][].kind, Expr.NUMBER)
    assert_equal(_val(ptr[].args[0][], ex), "1")
    _free_expr(ptr)


def test_parse_call_two_args() raises:
    var ex = "substring(x, 2)"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.CALL)
    assert_equal(_val(ptr[], ex), "substring")
    assert_equal(len(ptr[].args), 2)
    assert_equal(_val(ptr[].args[0][], ex), "x")
    assert_equal(_val(ptr[].args[1][], ex), "2")
    _free_expr(ptr)


# -----------------------------
# Location paths and steps
# -----------------------------

def test_parse_path_one_step() raises:
    var ex = "/a"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps), 1)
    assert_equal(ptr[].steps[0][].kind, Expr.STEP)
    assert_equal(_val(ptr[].steps[0][], ex), "a")
    assert_equal(len(ptr[].steps[0][].args), 0)
    _free_expr(ptr)


def test_parse_path_two_steps() raises:
    var ex = "/a/b"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps), 2)
    assert_equal(_val(ptr[].steps[0][], ex), "a")
    assert_equal(_val(ptr[].steps[1][], ex), "b")
    _free_expr(ptr)


def test_parse_path_three_steps() raises:
    var ex = "/foo/bar/baz"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps), 3)
    assert_equal(_val(ptr[].steps[0][], ex), "foo")
    assert_equal(_val(ptr[].steps[1][], ex), "bar")
    assert_equal(_val(ptr[].steps[2][], ex), "baz")
    _free_expr(ptr)


def test_parse_step_with_one_predicate() raises:
    # /a[1]
    var ex = "/a[1]"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps), 1)
    assert_equal(_val(ptr[].steps[0][], ex), "a")
    assert_equal(len(ptr[].steps[0][].args), 1)
    assert_equal(ptr[].steps[0][].args[0][].kind, Expr.NUMBER)
    assert_equal(_val(ptr[].steps[0][].args[0][], ex), "1")
    _free_expr(ptr)


def test_parse_step_with_predicate_expression() raises:
    # /a[. = "x"]
    var ex = "/a[. = \"x\"]"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps[0][].args), 1)
    ref pred = ptr[].steps[0][].args[0][]
    assert_equal(pred.kind, Expr.BINARY)
    assert_equal(_val(pred, ex), "=")
    assert_equal(_val(pred.left[], ex), ".")
    assert_equal(pred.right[].value.text(ex, strip_quotes=True), "x")
    _free_expr(ptr)


def test_parse_path_with_two_predicates() raises:
    # /a[1][2]
    var ex = "/a[1][2]"
    var ptr = parse_xpath(ex)
    assert_equal(len(ptr[].steps), 1)
    assert_equal(len(ptr[].steps[0][].args), 2)
    assert_equal(_val(ptr[].steps[0][].args[0][], ex), "1")
    assert_equal(_val(ptr[].steps[0][].args[1][], ex), "2")
    _free_expr(ptr)


# -----------------------------
# Path with function call in predicate (integration)
# -----------------------------

def test_parse_path_position_predicate() raises:
    # /a[position() = 1]
    var ex = "/a[position() = 1]"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps[0][].args), 1)
    ref pred = ptr[].steps[0][].args[0][]
    assert_equal(pred.kind, Expr.BINARY)
    assert_equal(_val(pred, ex), "=")
    assert_equal(pred.left[].kind, Expr.CALL)
    assert_equal(_val(pred.left[], ex), "position")
    assert_equal(_val(pred.right[], ex), "1")
    _free_expr(ptr)


# -----------------------------
# String input (incremental tokenizer: parser pulls next_token repeatedly)
# -----------------------------

def test_parse_xpath_string_number() raises:
    var ex = "42"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.NUMBER)
    assert_equal(_val(ptr[], ex), "42")
    _free_expr(ptr)


def test_parse_xpath_string_binary() raises:
    var ex = "1 + 2"
    var ptr = parse_xpath(ex)
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(_val(ptr[], ex), "+")
    assert_equal(_val(ptr[].left[], ex), "1")
    assert_equal(_val(ptr[].right[], ex), "2")
    _free_expr(ptr)


# -----------------------------
# Visitor (ExprStringifier + accept)
# -----------------------------

def test_visitor_stringifier_number() raises:
    var ptr = parse_xpath("42")
    var ctx = ExprContext("42")
    var s = ExprStringifier()
    assert_equal(accept(s, ptr, ctx), "42")
    _free_expr(ptr)


def test_visitor_stringifier_binary() raises:
    var ptr = parse_xpath("1 + 2")
    var ctx = ExprContext("1 + 2")
    var s = ExprStringifier()
    assert_equal(accept(s, ptr, ctx), "(1 + 2)")
    _free_expr(ptr)


def test_visitor_stringifier_path() raises:
    # Leading slash triggers location path (PATH kind); "a/b" alone would be binary "/"
    var ptr = parse_xpath("/a/b")
    var ctx = ExprContext("/a/b")
    var s = ExprStringifier()
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(accept(s, ptr, ctx), "a/b")
    _free_expr(ptr)


def test_visitor_stringifier_call() raises:
    var ptr = parse_xpath("f(1, 2)")
    var ctx = ExprContext("f(1, 2)")
    var s = ExprStringifier()
    assert_equal(accept(s, ptr, ctx), "f(1, 2)")
    _free_expr(ptr)


# -----------------------------
# Runner
# -----------------------------

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
