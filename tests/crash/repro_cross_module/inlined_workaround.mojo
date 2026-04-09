## Same evaluation as `main.mojo`, but `eval_accept` / `XPathEvaluator` are
## defined in this file. Imports `Expr` + `Token` from `evaluator`.
##
##   pixi run mojo -I tests/crash tests/crash/repro_cross_module/inlined_workaround.mojo
##
## Expected: prints OK — demonstrates that inlining the visitor avoids the crash.

from std.collections import List
from std.memory import ArcPointer
from std.utils import Variant

from repro_cross_module.evaluator import Expr, Token

comptime Arc = ArcPointer


@fieldwise_init
struct XPathNode(Movable):
    var path: String


comptime EvalResult = Variant[Float64, String, Bool, List[Arc[XPathNode]]]


@fieldwise_init
struct EvalContext:
    var root: Arc[XPathNode]
    var expression: String
    var current_leaf_value: String


trait ExprEvalVisitor:
    def visit_number(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(0.0)

    def visit_string(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult("")

    def visit_name(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult("")

    def visit_binary(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(0.0)

    def visit_call(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(0.0)

    def visit_path(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(List[Arc[XPathNode]]())

    def visit_step(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(List[Arc[XPathNode]]())


def eval_accept[V: ExprEvalVisitor](
    visitor: V, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
) raises -> EvalResult:
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
) raises -> EvalResult:
    return eval_accept(visitor, root[], ctx, current)


struct XPathEvaluator(ExprEvalVisitor):
    fn __init__(out self):
        pass

    def eval(
        self, expr: Expr.ExprPointer, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return eval_accept(self, expr, ctx, current)

    def visit_string(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(node.value.text(ctx.expression, strip_quotes=True))


def main() raises:
    var ex = "'hello'"
    var tok = Token(type=Token.STRING, start=0, length=7, line=1)
    var ptr = Expr.string(tok)
    var root = XPathNode("/")
    var root_arc = Arc[XPathNode](root^)
    var ctx = EvalContext(root_arc, ex, "")
    var ev = XPathEvaluator()
    var result = ev.eval(ptr, ctx, root_arc)
    _ = result[String]
    print("OK")
