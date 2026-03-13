## Comprehensive tests for xyang.xpath.pratt_parser.
## Uses parse_xpath(expression_string); frees tree after each test.

from std.testing import assert_equal, assert_true, TestSuite
from xyang.xpath.pratt_parser import parse_xpath, Expr


# -----------------------------
# Helpers
# -----------------------------

def _free_expr(ptr: Expr.ExprPointer):
    """Release the expression tree rooted at ptr."""
    ptr[].free_tree()
    ptr.destroy_pointee()
    ptr.free()


# -----------------------------
# Atoms: number, string, name, dot, dotdot
# -----------------------------

def test_parse_number():
    var ptr = parse_xpath("42")
    assert_equal(ptr[].kind, Expr.NUMBER)
    assert_equal(ptr[].value, "42")
    assert_true(not ptr[].left)
    assert_true(not ptr[].right)
    assert_equal(len(ptr[].args), 0)
    assert_equal(len(ptr[].steps), 0)
    _free_expr(ptr)


def test_parse_string():
    var ptr = parse_xpath("'hello'")
    assert_equal(ptr[].kind, Expr.STRING)
    assert_equal(ptr[].value, "hello")
    _free_expr(ptr)


def test_parse_name():
    var ptr = parse_xpath("foo")
    assert_equal(ptr[].kind, Expr.NAME)
    assert_equal(ptr[].value, "foo")
    _free_expr(ptr)


def test_parse_dot():
    var ptr = parse_xpath(".")
    assert_equal(ptr[].kind, Expr.NAME)
    assert_equal(ptr[].value, ".")
    _free_expr(ptr)


def test_parse_dotdot():
    var ptr = parse_xpath("..")
    assert_equal(ptr[].kind, Expr.NAME)
    assert_equal(ptr[].value, "..")
    _free_expr(ptr)


# -----------------------------
# Parenthesized expression
# -----------------------------

def test_parse_parens():
    var ptr = parse_xpath("(7)")
    assert_equal(ptr[].kind, Expr.NUMBER)
    assert_equal(ptr[].value, "7")
    _free_expr(ptr)


# -----------------------------
# Binary operators and precedence
# -----------------------------

def test_parse_binary_plus():
    var ptr = parse_xpath("1 + 2")
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(ptr[].value, "+")
    assert_true(ptr[].left)
    assert_true(ptr[].right)
    assert_equal(ptr[].left[].kind, Expr.NUMBER)
    assert_equal(ptr[].left[].value, "1")
    assert_equal(ptr[].right[].kind, Expr.NUMBER)
    assert_equal(ptr[].right[].value, "2")
    _free_expr(ptr)


def test_parse_binary_and():
    var ptr = parse_xpath("a and b")
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(ptr[].value, "and")
    assert_equal(ptr[].left[].value, "a")
    assert_equal(ptr[].right[].value, "b")
    _free_expr(ptr)


def test_parse_binary_or():
    var ptr = parse_xpath("x or y")
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(ptr[].value, "or")
    _free_expr(ptr)


def test_parse_binary_equals():
    var ptr = parse_xpath("1 = 1")
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(ptr[].value, "=")
    _free_expr(ptr)


def test_parse_binary_precedence_plus_times():
    # 3 + 4 * 5  =>  binary(+, 3, binary(*, 4, 5))
    var ptr = parse_xpath("3 + 4 * 5")
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(ptr[].value, "+")
    assert_equal(ptr[].left[].value, "3")
    assert_equal(ptr[].right[].kind, Expr.BINARY)
    assert_equal(ptr[].right[].value, "*")
    assert_equal(ptr[].right[].left[].value, "4")
    assert_equal(ptr[].right[].right[].value, "5")
    _free_expr(ptr)


def test_parse_binary_precedence_parens():
    # (1 + 2) * 3
    var ptr = parse_xpath("(1 + 2) * 3")
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(ptr[].value, "*")
    assert_equal(ptr[].left[].kind, Expr.BINARY)
    assert_equal(ptr[].left[].value, "+")
    assert_equal(ptr[].right[].value, "3")
    _free_expr(ptr)


# -----------------------------
# Function calls
# -----------------------------

def test_parse_call_no_args():
    var ptr = parse_xpath("f()")
    assert_equal(ptr[].kind, Expr.CALL)
    assert_equal(ptr[].value, "f")
    assert_equal(len(ptr[].args), 0)
    _free_expr(ptr)


def test_parse_call_one_arg():
    var ptr = parse_xpath("string(1)")
    assert_equal(ptr[].kind, Expr.CALL)
    assert_equal(ptr[].value, "string")
    assert_equal(len(ptr[].args), 1)
    assert_equal(ptr[].args[0][].kind, Expr.NUMBER)
    assert_equal(ptr[].args[0][].value, "1")
    _free_expr(ptr)


def test_parse_call_two_args():
    var ptr = parse_xpath("substring(x, 2)")
    assert_equal(ptr[].kind, Expr.CALL)
    assert_equal(ptr[].value, "substring")
    assert_equal(len(ptr[].args), 2)
    assert_equal(ptr[].args[0][].value, "x")
    assert_equal(ptr[].args[1][].value, "2")
    _free_expr(ptr)


# -----------------------------
# Location paths and steps
# -----------------------------

def test_parse_path_one_step():
    var ptr = parse_xpath("/a")
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps), 1)
    assert_equal(ptr[].steps[0][].kind, Expr.STEP)
    assert_equal(ptr[].steps[0][].value, "a")
    assert_equal(len(ptr[].steps[0][].args), 0)
    _free_expr(ptr)


def test_parse_path_two_steps():
    var ptr = parse_xpath("/a/b")
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps), 2)
    assert_equal(ptr[].steps[0][].value, "a")
    assert_equal(ptr[].steps[1][].value, "b")
    _free_expr(ptr)


def test_parse_path_three_steps():
    var ptr = parse_xpath("/foo/bar/baz")
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps), 3)
    assert_equal(ptr[].steps[0][].value, "foo")
    assert_equal(ptr[].steps[1][].value, "bar")
    assert_equal(ptr[].steps[2][].value, "baz")
    _free_expr(ptr)


def test_parse_step_with_one_predicate():
    # /a[1]
    var ptr = parse_xpath("/a[1]")
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps), 1)
    assert_equal(ptr[].steps[0][].value, "a")
    assert_equal(len(ptr[].steps[0][].args), 1)
    assert_equal(ptr[].steps[0][].args[0][].kind, Expr.NUMBER)
    assert_equal(ptr[].steps[0][].args[0][].value, "1")
    _free_expr(ptr)


def test_parse_step_with_predicate_expression():
    # /a[. = "x"]
    var ptr = parse_xpath('/a[. = "x"]')
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps[0][].args), 1)
    ref pred = ptr[].steps[0][].args[0][]
    assert_equal(pred.kind, Expr.BINARY)
    assert_equal(pred.value, "=")
    assert_equal(pred.left[].value, ".")
    assert_equal(pred.right[].value, "x")
    _free_expr(ptr)


def test_parse_path_with_two_predicates():
    # /a[1][2]
    var ptr = parse_xpath("/a[1][2]")
    assert_equal(len(ptr[].steps), 1)
    assert_equal(len(ptr[].steps[0][].args), 2)
    assert_equal(ptr[].steps[0][].args[0][].value, "1")
    assert_equal(ptr[].steps[0][].args[1][].value, "2")
    _free_expr(ptr)


# -----------------------------
# Path with function call in predicate (integration)
# -----------------------------

def test_parse_path_position_predicate():
    # /a[position() = 1]
    var ptr = parse_xpath("/a[position() = 1]")
    assert_equal(ptr[].kind, Expr.PATH)
    assert_equal(len(ptr[].steps[0][].args), 1)
    ref pred = ptr[].steps[0][].args[0][]
    assert_equal(pred.kind, Expr.BINARY)
    assert_equal(pred.value, "=")
    assert_equal(pred.left[].kind, Expr.CALL)
    assert_equal(pred.left[].value, "position")
    assert_equal(pred.right[].value, "1")
    _free_expr(ptr)


# -----------------------------
# String input (incremental tokenizer: parser pulls next_token repeatedly)
# -----------------------------

def test_parse_xpath_string_number():
    var ptr = parse_xpath("42")
    assert_equal(ptr[].kind, Expr.NUMBER)
    assert_equal(ptr[].value, "42")
    _free_expr(ptr)


def test_parse_xpath_string_binary():
    var ptr = parse_xpath("1 + 2")
    assert_equal(ptr[].kind, Expr.BINARY)
    assert_equal(ptr[].value, "+")
    assert_equal(ptr[].left[].value, "1")
    assert_equal(ptr[].right[].value, "2")
    _free_expr(ptr)


# -----------------------------
# Runner
# -----------------------------

def main():
    TestSuite.discover_tests[__functions_in_module()]().run()
