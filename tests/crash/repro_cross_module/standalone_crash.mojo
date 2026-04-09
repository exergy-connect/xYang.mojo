## Standalone SIGSEGV repro (exit 139). Only paths/types needed for `Expr.string` + load-bearing `visit_call`.
##
##   pixi run mojo -I tests/crash tests/crash/repro_cross_module/standalone_crash.mojo

from std.collections import List
from std.memory import ArcPointer, UnsafePointer, alloc
from std.utils import Variant

comptime Arc = ArcPointer


@fieldwise_init
struct Token(Copyable):
    comptime Type = UInt8
    comptime STRING: Self.Type = 3

    var type: Self.Type
    var start: Int
    var length: Int

    def text(self, source: String, strip_quotes: Bool = False) raises -> String:
        if strip_quotes and self.type == Self.STRING:
            return String(
                source[byte=self.start + 1 : self.start + self.length - 1]
            )
        return String(source[byte=self.start : self.start + self.length])


struct Expr(Movable):
    comptime ExprPointer = UnsafePointer[Self, MutExternalOrigin]
    comptime Kind = UInt8
    comptime STRING: Self.Kind = 1
    comptime CALL: Self.Kind = 2

    var kind: Self.Kind
    var value: Token
    var args: List[Arc[Self]]

    def __init__(out self, kind: Self.Kind, value: Token, var args: List[Arc[Self]]):
        self.kind = kind
        self.value = value.copy()
        self.args = args^

    @staticmethod
    def string(v: Token) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(Self(Self.STRING, v, List[Arc[Self]]()))
        return ptr


@fieldwise_init
struct XPathNode(Movable):
    var path: String


comptime EvalResult = Variant[Float64, String, Bool, List[Arc[XPathNode]]]


@fieldwise_init
struct EvalContext:
    var expression: String


trait ExprEvalVisitor:
    def visit_string(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult("")

    def visit_call(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(0.0)


def dispatch_expr[V: ExprEvalVisitor](
    visitor: V, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
) raises -> EvalResult:
    if node.kind == Expr.STRING:
        return visitor.visit_string(node, ctx, current)
    if node.kind == Expr.CALL:
        return visitor.visit_call(node, ctx, current)
    return EvalResult(0.0)


def eval_accept[V: ExprEvalVisitor](
    visitor: V, root: Expr.ExprPointer, ctx: EvalContext, current: Arc[XPathNode]
) raises -> EvalResult:
    return dispatch_expr(visitor, root[], ctx, current)


struct XPathEvaluator(ExprEvalVisitor):
    fn __init__(out self):
        pass

    def eval(
        self, expr: Expr.ExprPointer, current: Arc[XPathNode], expression: String
    ) raises -> EvalResult:
        var ctx = EvalContext(expression)
        return eval_accept(self, expr, ctx, current)

    def visit_string(
        self, ref node: Expr, ctx: EvalContext, read `_`: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(node.value.text(ctx.expression, strip_quotes=True))

    def visit_call(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var name = node.value.text(ctx.expression)
        if name == "string":
            if len(node.args) == 1:
                var a = dispatch_expr(self, node.args[0][], ctx, current)
                var fv = a
                if fv.isa[List[Arc[XPathNode]]]():
                    ref nodes = fv[List[Arc[XPathNode]]]
                    if len(nodes) > 0:
                        # Crash happens here
                        fv = EvalResult(nodes[0].copy())
        return EvalResult(0.0)


def main() raises:
    var root = ArcPointer[XPathNode](XPathNode("/"))
    var ex = "'hello'"
    var tok = Token(type=Token.STRING, start=0, length=7)
    var ptr = Expr.string(tok)
    var ev = XPathEvaluator()
    _ = ev.eval(ptr, root, ex)
