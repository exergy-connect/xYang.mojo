## Standalone minimal repro: evaluator test (eval string) with no xyang imports.
## All required types and logic inlined for crash debugging.

from std.collections import List
from std.memory import ArcPointer, UnsafePointer, alloc
from std.testing import assert_equal, assert_true, TestSuite
from std.utils import Variant

comptime Arc = ArcPointer

# -----------------------------
# Token (from xyang.xpath.token)
# -----------------------------

@fieldwise_init
struct Token(Copyable):
    comptime Type = UInt8
    comptime IDENTIFIER: Self.Type    = 0
    comptime NUMBER: Self.Type        = 1
    comptime FLOAT_NUMBER: Self.Type  = 2
    comptime STRING: Self.Type        = 3
    comptime OPERATOR: Self.Type      = 4
    comptime PAREN_OPEN: Self.Type    = 5
    comptime PAREN_CLOSE: Self.Type   = 6
    comptime BRACKET_OPEN: Self.Type  = 7
    comptime BRACKET_CLOSE: Self.Type = 8
    comptime DOT: Self.Type           = 9
    comptime DOTDOT: Self.Type        = 10
    comptime SLASH: Self.Type         = 11
    comptime COMMA: Self.Type         = 12
    comptime EOF: Self.Type           = 13

    var type: Self.Type
    var start: Int
    var length: Int
    var line: Int

    def text(self, source: String, strip_quotes: Bool = False) -> String:
        if strip_quotes and self.type == Self.STRING:
            return String(source[self.start + 1:self.start + self.length - 1])
        return String(source[self.start:self.start + self.length])

# -----------------------------
# Expr (from xyang.xpath.pratt_parser, minimal)
# -----------------------------

struct Expr(Movable):
    comptime ExprPointer = UnsafePointer[Self, MutExternalOrigin]
    comptime Kind = UInt8
    comptime NUMBER: Self.Kind = 0
    comptime STRING: Self.Kind = 1
    comptime NAME: Self.Kind = 2
    comptime BINARY: Self.Kind = 3
    comptime CALL: Self.Kind = 4
    comptime PATH: Self.Kind = 5
    comptime STEP: Self.Kind = 6

    var kind: Self.Kind
    var value: Token
    var left: Self.ExprPointer
    var right: Self.ExprPointer
    var args: List[Arc[Expr]]
    var steps: List[Arc[Expr]]

    def __init__(
        out self,
        kind: Self.Kind,
        value: Token,
        left: Self.ExprPointer,
        right: Self.ExprPointer,
        var args: List[Arc[Expr]],
        var steps: List[Arc[Expr]],
    ):
        self.kind = kind
        self.value = value.copy()
        self.left = left
        self.right = right
        self.args = args^
        self.steps = steps^

    @staticmethod
    def string(v: Token) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(
            Self(
                Self.STRING, v,
                Self.ExprPointer(),
                Self.ExprPointer(),
                List[Arc[Expr]](),
                List[Arc[Expr]](),
            )
        )
        return ptr

    def free_tree(self):
        if self.left:
            self.left[].free_tree()
            self.left.destroy_pointee()
            self.left.free()
        if self.right:
            self.right[].free_tree()
            self.right.destroy_pointee()
            self.right.free()
        for i in range(len(self.args)):
            self.args[i][].free_tree()
        for i in range(len(self.steps)):
            self.steps[i][].free_tree()

# -----------------------------
# XPathNode, EvalContext, EvalResult (from xyang.xpath.evaluator)
# -----------------------------

@fieldwise_init
struct XPathNode(Movable):
    var path: String

comptime EvalResultVariant = Variant[Float64, String, Bool, List[Arc[XPathNode]]]
comptime EvalResult = EvalResultVariant

@fieldwise_init
struct EvalContext:
    var root: Arc[XPathNode]
    var expression: String
    var current_leaf_value: String

# -----------------------------
# Eval visitor trait and dispatch
# -----------------------------

trait ExprEvalVisitor:
    def visit_number(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) -> EvalResult:
        return EvalResult(0.0)
    def visit_string(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) -> EvalResult:
        return EvalResult("")
    def visit_name(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) -> EvalResult:
        return EvalResult("")
    def visit_binary(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) -> EvalResult:
        return EvalResult(0.0)
    def visit_call(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) -> EvalResult:
        return EvalResult(0.0)
    def visit_path(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) -> EvalResult:
        return EvalResult(List[Arc[XPathNode]]())
    def visit_step(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) -> EvalResult:
        return EvalResult(List[Arc[XPathNode]]())

def eval_accept[V: ExprEvalVisitor](
    visitor: V, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
) -> EvalResult:
    if node.kind == Expr.NUMBER:
        return visitor.visit_number(node, ctx, current)
    if node.kind == Expr.STRING:
        return visitor.visit_string(node, ctx, current)
    if node.kind == Expr.NAME:
        return visitor.visit_name(node, ctx, current)
    if node.kind == Expr.BINARY:
        return visitor.visit_binary(node, ctx, current)
    if node.kind == Expr.CALL:
        return visitor.visit_call(node, ctx, current)
    if node.kind == Expr.PATH:
        return visitor.visit_path(node, ctx, current)
    if node.kind == Expr.STEP:
        return visitor.visit_step(node, ctx, current)
    return EvalResult(0.0)

def eval_accept[V: ExprEvalVisitor](
    visitor: V, root: Expr.ExprPointer, ctx: EvalContext, current: Arc[XPathNode]
) -> EvalResult:
    return eval_accept(visitor, root[], ctx, current)

# -----------------------------
# XPathEvaluator (only visit_string implemented for this test)
# -----------------------------

struct XPathEvaluator(ExprEvalVisitor):
    fn __init__(out self):
        pass

    def eval(
        self, expr: Expr.ExprPointer, ctx: EvalContext, current: Arc[XPathNode]
    ) -> EvalResult:
        return eval_accept(self, expr, ctx, current)

    def visit_string(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) -> EvalResult:
        return EvalResult(node.value.text(ctx.expression, strip_quotes=True))

# -----------------------------
# Test
# -----------------------------

def _free_expr(ptr: Expr.ExprPointer):
    ptr[].free_tree()
    ptr.destroy_pointee()
    ptr.free()

def test_eval_string():
    var ex = "'hello'"
    # STRING token: start=0, length=7 for "'hello'"
    var tok = Token(type=Token.STRING, start=0, length=7, line=1)
    var ptr = Expr.string(tok)
    var root = XPathNode("/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, ex, "")
    var ev = XPathEvaluator()

    #
    # THIS NO LONGER CRASHES
    #
    var result = ev.eval(ptr, ctx, root_arc)
    _free_expr(ptr)
    assert_true(result.isa[String]())
    assert_equal(result[String], "hello")

def main():
    TestSuite.discover_tests[__functions_in_module()]().run()
