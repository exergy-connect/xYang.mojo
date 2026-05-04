## Comprehensive tests for xyang.xpath.pratt_parser.
## Uses parse_xpath(expression_string); frees tree after each test.

from std.testing import assert_equal, assert_true, TestSuite
import xyang.yang.xpath.pratt_parser as xp


# -----------------------------
# Helpers
# -----------------------------


def _val(ref node: xp.XPathExpr, source: String) -> String:
    """Return the lexeme for node.value from the given source expression."""
    return node.value.text(source.as_bytes())


# -----------------------------
# Atoms: number, string, name, dot, dotdot
# -----------------------------


def test_parse_number() raises:
    var ex = "42"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.NUMBER)
    assert_equal(_val(ptr[], ex), "42")
    assert_true(ptr[].payload.isa[xp.XPathAtom]())

def test_parse_string() raises:
    var ex = "'hello'"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.STRING)
    assert_equal(ptr[].value.text(ex.as_bytes(), strip_quotes=True), "hello")

def test_parse_name() raises:
    var ex = "foo"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.NAME)
    assert_equal(_val(ptr[], ex), "foo")

def test_parse_dot() raises:
    var ex = "."
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.NAME)
    assert_equal(_val(ptr[], ex), ".")

def test_parse_dotdot() raises:
    var ex = ".."
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.NAME)
    assert_equal(_val(ptr[], ex), "..")

# -----------------------------
# Parenthesized expression
# -----------------------------


def test_parse_parens() raises:
    var ex = "(7)"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.NUMBER)
    assert_equal(_val(ptr[], ex), "7")

def test_parse_parens_comma_list() raises:
    var ex = "../type = ('date','datetime')"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(ptr[], ex), "=")
    ref root_bin = ptr[].payload[xp.XPathBinaryOp]
    assert_equal(root_bin.right[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(root_bin.right[], ex), ",")
    ref comma = root_bin.right[].payload[xp.XPathBinaryOp]
    assert_equal(comma.left[].kind(), xp.XPathExpr.STRING)
    assert_equal(comma.right[].kind(), xp.XPathExpr.STRING)
    assert_equal(
        comma.left[].value.text(ex.as_bytes(), strip_quotes=True), "date"
    )
    assert_equal(
        comma.right[].value.text(ex.as_bytes(), strip_quotes=True),
        "datetime",
    )

# -----------------------------
# Binary operators and precedence
# -----------------------------


def test_parse_binary_plus() raises:
    var ex = "1 + 2"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(ptr[], ex), "+")
    ref b = ptr[].payload[xp.XPathBinaryOp]
    assert_equal(b.left[].kind(), xp.XPathExpr.NUMBER)
    assert_equal(_val(b.left[], ex), "1")
    assert_equal(b.right[].kind(), xp.XPathExpr.NUMBER)
    assert_equal(_val(b.right[], ex), "2")

def test_parse_binary_and() raises:
    var ex = "a and b"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(ptr[], ex), "and")
    ref b = ptr[].payload[xp.XPathBinaryOp]
    assert_equal(_val(b.left[], ex), "a")
    assert_equal(_val(b.right[], ex), "b")

def test_parse_binary_or() raises:
    var ex = "x or y"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(ptr[], ex), "or")

def test_parse_binary_equals() raises:
    var ex = "1 = 1"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(ptr[], ex), "=")

def test_parse_binary_precedence_plus_times() raises:
    # 3 + 4 * 5  =>  binary(+, 3, binary(*, 4, 5))
    var ex = "3 + 4 * 5"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(ptr[], ex), "+")
    ref outer = ptr[].payload[xp.XPathBinaryOp]
    assert_equal(_val(outer.left[], ex), "3")
    assert_equal(outer.right[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(outer.right[], ex), "*")
    ref inner = outer.right[].payload[xp.XPathBinaryOp]
    assert_equal(_val(inner.left[], ex), "4")
    assert_equal(_val(inner.right[], ex), "5")

def test_parse_binary_precedence_parens() raises:
    # (1 + 2) * 3
    var ex = "(1 + 2) * 3"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(ptr[], ex), "*")
    ref outer = ptr[].payload[xp.XPathBinaryOp]
    assert_equal(outer.left[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(outer.left[], ex), "+")
    assert_equal(_val(outer.right[], ex), "3")

# -----------------------------
# Function calls
# -----------------------------


def test_parse_call_no_args() raises:
    var ex = "f()"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.CALL)
    assert_equal(_val(ptr[], ex), "f")
    assert_equal(len(ptr[].payload[xp.XPathCall].args), 0)

def test_parse_call_one_arg() raises:
    var ex = "string(1)"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.CALL)
    assert_equal(_val(ptr[], ex), "string")
    ref c = ptr[].payload[xp.XPathCall]
    assert_equal(len(c.args), 1)
    assert_equal(c.args[0][].kind(), xp.XPathExpr.NUMBER)
    assert_equal(_val(c.args[0][], ex), "1")

def test_parse_call_two_args() raises:
    var ex = "substring(x, 2)"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.CALL)
    assert_equal(_val(ptr[], ex), "substring")
    ref c = ptr[].payload[xp.XPathCall]
    assert_equal(len(c.args), 2)
    assert_equal(_val(c.args[0][], ex), "x")
    assert_equal(_val(c.args[1][], ex), "2")

# -----------------------------
# Location paths and steps
# -----------------------------


def test_parse_path_one_step() raises:
    var ex = "/a"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    ref p = ptr[].payload[xp.XPathPath]
    assert_equal(len(p.steps), 1)
    assert_equal(p.steps[0][].kind(), xp.XPathExpr.STEP)
    assert_equal(_val(p.steps[0][], ex), "a")
    assert_equal(len(p.steps[0][].payload[xp.XPathStep].predicates), 0)

def test_parse_path_two_steps() raises:
    var ex = "/a/b"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    ref p = ptr[].payload[xp.XPathPath]
    assert_equal(len(p.steps), 2)
    assert_equal(_val(p.steps[0][], ex), "a")
    assert_equal(_val(p.steps[1][], ex), "b")

def test_parse_path_three_steps() raises:
    var ex = "/foo/bar/baz"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    ref p = ptr[].payload[xp.XPathPath]
    assert_equal(len(p.steps), 3)
    assert_equal(_val(p.steps[0][], ex), "foo")
    assert_equal(_val(p.steps[1][], ex), "bar")
    assert_equal(_val(p.steps[2][], ex), "baz")

def test_parse_refine_path_prefixed_relative() raises:
    var ex = "if:interfaces/if:interface"
    var ptr = xp.parse_refine_path(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    ref p = ptr[].payload[xp.XPathPath]
    assert_equal(len(p.steps), 2)
    assert_equal(_val(p.steps[0][], ex), "if:interfaces")
    assert_equal(_val(p.steps[1][], ex), "if:interface")

def test_parse_refine_path_prefixed_absolute() raises:
    var ex = "/if:interfaces/if:interface"
    var ptr = xp.parse_refine_path(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    ref p = ptr[].payload[xp.XPathPath]
    assert_equal(len(p.steps), 2)
    assert_equal(_val(p.steps[0][], ex), "if:interfaces")
    assert_equal(_val(p.steps[1][], ex), "if:interface")

def test_parse_step_with_one_predicate() raises:
    # /a[1]
    var ex = "/a[1]"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    ref p = ptr[].payload[xp.XPathPath]
    assert_equal(len(p.steps), 1)
    ref st = p.steps[0][].payload[xp.XPathStep]
    assert_equal(_val(p.steps[0][], ex), "a")
    assert_equal(len(st.predicates), 1)
    assert_equal(st.predicates[0][].kind(), xp.XPathExpr.NUMBER)
    assert_equal(_val(st.predicates[0][], ex), "1")

def test_parse_step_with_predicate_expression() raises:
    # /a[. = "x"]
    var ex = '/a[. = "x"]'
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    ref p = ptr[].payload[xp.XPathPath]
    ref st = p.steps[0][].payload[xp.XPathStep]
    assert_equal(len(st.predicates), 1)
    ref pred = st.predicates[0][]
    assert_equal(pred.kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(pred, ex), "=")
    ref pb = pred.payload[xp.XPathBinaryOp]
    assert_equal(_val(pb.left[], ex), ".")
    assert_equal(pb.right[].value.text(ex.as_bytes(), strip_quotes=True), "x")

def test_parse_path_with_two_predicates() raises:
    # /a[1][2]
    var ex = "/a[1][2]"
    var ptr = xp.parse_xpath(ex)
    ref p = ptr[].payload[xp.XPathPath]
    assert_equal(len(p.steps), 1)
    ref st = p.steps[0][].payload[xp.XPathStep]
    assert_equal(len(st.predicates), 2)
    assert_equal(_val(st.predicates[0][], ex), "1")
    assert_equal(_val(st.predicates[1][], ex), "2")

# -----------------------------
# Path with function call in predicate (integration)
# -----------------------------


def test_parse_path_position_predicate() raises:
    # /a[position() = 1]
    var ex = "/a[position() = 1]"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    ref p = ptr[].payload[xp.XPathPath]
    ref st = p.steps[0][].payload[xp.XPathStep]
    assert_equal(len(st.predicates), 1)
    ref pred = st.predicates[0][]
    assert_equal(pred.kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(pred, ex), "=")
    ref pb = pred.payload[xp.XPathBinaryOp]
    assert_equal(pb.left[].kind(), xp.XPathExpr.CALL)
    assert_equal(_val(pb.left[], ex), "position")
    assert_equal(_val(pb.right[], ex), "1")

# -----------------------------
# String input (incremental tokenizer: parser pulls next_token repeatedly)
# -----------------------------


def test_parse_xpath_string_number() raises:
    var ex = "42"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.NUMBER)
    assert_equal(_val(ptr[], ex), "42")

def test_parse_xpath_string_binary() raises:
    var ex = "1 + 2"
    var ptr = xp.parse_xpath(ex)
    assert_equal(ptr[].kind(), xp.XPathExpr.BINARY)
    assert_equal(_val(ptr[], ex), "+")
    ref b = ptr[].payload[xp.XPathBinaryOp]
    assert_equal(_val(b.left[], ex), "1")
    assert_equal(_val(b.right[], ex), "2")

# -----------------------------
# Visitor (XPathExprStringifier + accept)
# -----------------------------


def test_visitor_stringifier_number() raises:
    var text = String("42")
    var ctx = xp.XPathContext(text.as_bytes())
    var ptr = xp.parse_xpath("42")
    var s = xp.XPathExprStringifier()
    xp.accept(s, ptr, ctx)
    assert_equal(s.result, "42")


def test_visitor_stringifier_binary() raises:
    var text = String("1 + 2")
    var ctx = xp.XPathContext(text.as_bytes())
    var ptr = xp.parse_xpath("1 + 2")
    var s = xp.XPathExprStringifier()
    xp.accept(s, ptr, ctx)
    assert_equal(s.result, "(1 + 2)")


def test_visitor_stringifier_path() raises:
    # Leading slash triggers location path (PATH kind); "a/b" alone would be binary "/"
    var text = String("/a/b")
    var ctx = xp.XPathContext(text.as_bytes())
    var ptr = xp.parse_xpath("/a/b")
    var s = xp.XPathExprStringifier()
    assert_equal(ptr[].kind(), xp.XPathExpr.PATH)
    xp.accept(s, ptr, ctx)
    assert_equal(s.result, "a/b")


def test_visitor_stringifier_call() raises:
    var text = String("f(1, 2)")
    var ctx = xp.XPathContext(text.as_bytes())
    var ptr = xp.parse_xpath("f(1, 2)")
    var s = xp.XPathExprStringifier()
    xp.accept(s, ptr, ctx)
    assert_equal(s.result, "f(1, 2)")

# -----------------------------
# Runner
# -----------------------------


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
